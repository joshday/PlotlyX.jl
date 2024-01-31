module PlotlyX

using Random: randstring
using Downloads: download
using REPL

using Scratch, JSON3, EasyConfig, Cobweb, StructTypes
using Cobweb: h, Node

#-----------------------------------------------------------------------------# exports
export Plot, trace, Config

#-----------------------------------------------------------------------------# macros
macro scratch_path(path...); esc(:(joinpath(Scratch.get_scratch!(PlotlyX, "assets"), $(path...)))); end

macro download(url, dest=nothing)
    esc(quote
        let
            dest = $(isnothing(dest)) ? PlotlyX.@scratch_path(basename($url)) : $dest
            if !isfile(dest)
                @info string("PlotlyX Downloading: ", $url)
                PlotlyX.download($url, dest)
            end
            dest
        end
    end)
end

#-----------------------------------------------------------------------------# utils
get_semver(x) = VersionNumber(match(r"(\d+)\.(\d+)\.(\d+)", x).match)

function plotly_latest()
    file = download("https://api.github.com/repos/plotly/plotly.js/releases/latest")
    VersionNumber(JSON3.read(file).name)
end

plotly_template_urls = Dict(
    t => "https://raw.githubusercontent.com/plotly/plotly.py/master/packages/python/plotly/plotly/package_data/templates/$t.json" for t in
        (:ggplot2, :gridon, :plotly, :plotly_dark, :plotly_white, :presentation, :seaborn, :simple_white, :xgridoff, :ygridoff)
)

fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
fix_matrix(x) = x
fix_matrix(x::AbstractMatrix) = eachrow(x)

#-----------------------------------------------------------------------------# __init__
Base.@kwdef mutable struct Settings
    src::Cobweb.Node    = h.script(src=plotly_url, charset="utf-8")
    div::Cobweb.Node    = h.div(; style="height:100%;width:100%;")
    layout::Config      = Config()
    config::Config      = Config(responsive=true)
    reuse_preview::Bool = true
end

global settings::Settings
global plotly_version::VersionNumber
global plotly_url::String = ""
global plotly_path::String
global plotly_template_paths::Dict{Symbol, String}
global plotly_schema::JSON3.Object

function __init__()
    _plotly_path = @scratch_path("plotly.min.js")
    global plotly_version = isfile(_plotly_path) ? get_semver(readuntil(_plotly_path, "*/")) : plotly_latest()
    global plotly_url = "https://cdn.plot.ly/plotly-$(plotly_version).min.js"
    global plotly_path = @download(plotly_url, _plotly_path)
    global plotly_template_paths = Dict(k => @download(v) for (k,v) in plotly_template_urls)
    global plotly_schema = JSON3.read(read(@download("https://api.plot.ly/v2/plot-schema?format=json&sha1=%27%27", @scratch_path("plot-schema.json"))))
    global settings = Settings()
    nothing
end

function update!()
    Scratch.clear_scratchspaces!(PlotlyX)
    __init__()
end

#-----------------------------------------------------------------------------# Plot
mutable struct Plot
    data::Vector{Config}
    layout::Config
    config::Config
    id::String
    Plot(data::Vector{Config}, layout::Config = Config(), config::Config = Config(), id::String = randstring(10)) =
    new(data, Config(layout), Config(config), id)
end

Plot(data::Config, layout::Config = Config(), config::Config = Config()) = Plot([data], layout, config)
Plot(; layout=Config(), config=Config(), @nospecialize(kw...)) = Plot(Config(kw), Config(layout), Config(config))
(p::Plot)(; @nospecialize(kw...)) = p(Config(kw))
(p::Plot)(data::Config) = (push!(p.data, data); return p)

StructTypes.StructType(::Plot) = StructTypes.Struct()
Base.:(==)(a::Plot, b::Plot) = all(getfield(a,f) == getfield(b,f) for f in setdiff(fieldnames(Plot), [:id]))

#-----------------------------------------------------------------------------# display/show
function html_div(o::Plot)
    id = o.id
    data = JSON3.write(fix_matrix.(o.data); allow_inf=true)
    layout = JSON3.write(merge(settings.layout, o.layout); allow_inf=true)
    config = JSON3.write(merge(settings.config, o.config); allow_inf=true)
    h.div(class="plotlyxjl-parent-div",
        settings.src,
        settings.div(; id, class="plotlyxjl-plot-div"),
        h.script("Plotly.newPlot(\"$id\", $data, $layout, $config)")
    )
end

html_page(o::Plot) =
    h.html(
        h.head(
            h.meta(charset="utf-8"),
            h.meta(name="viewport", content="width=device-width, initial-scale=1"),
            h.meta(name="description", content="PlotlyX.jl"),
            h.title("PlotlyX.jl"),
            h.style("body { margin: 0px; } /* remove scrollbar in iframe */"),
        ),
        h.body(html_div(o))
    )

html_iframe(o::Plot; kw...) = IFrame(html_page(o); height="450px", width="700px", style="resize:both; display:block; border:none;", kw...)

Base.show(io::IO, ::MIME"juliavscode/html", o::Plot) = show(io, MIME"text/html"(), o)

# Using an <iframe> to display the plot is easier than figuring out what IJulia/Jupyter is doing
_use_iframe() = (isdefined(Main, :VSCodeServer) && stdout isa Main.VSCodeServer.IJuliaCore.IJuliaStdio) ||
                (isdefined(Main, :IJulia) && stdout isa Main.IJulia.IJuliaStdio)

Base.show(io::IO, M::MIME"text/html", o::Plot) = show(io, M, _use_iframe() ? html_iframe(o) : html_div(o))

Base.display(::REPL.REPLDisplay, o::Plot) = Cobweb.preview(html_page(o), reuse=settings.reuse_preview)


#-----------------------------------------------------------------------------# Presets
_template!(t) = (settings.layout.template = JSON3.read(read(plotly_template_paths[t])); nothing)

set_template_none!()         = haskey(settings.layout, :template) && delete!(settings.layout, :template)
set_template_ggplot2!()      = _template!(:ggplot2)
set_template_gridon!()       = _template!(:gridon)
set_template_plotly!()       = _template!(:plotly)
set_template_plotly_dark!()  = _template!(:plotly_dark)
set_template_plotly_white!() = _template!(:plotly_white)
set_template_presentation!() = _template!(:presentation)
set_template_seaborn!()      = _template!(:seaborn)
set_template_simple_white!() = _template!(:simple_white)
set_template_xgridoff!()     = _template!(:xgridoff)
set_template_ygridoff!()     = _template!(:ygridoff)

set_src_none!() = settings.src = h.div("src_none!", style="display:none;")
set_src_cdn!()  = settings.src = h.script(src=plotly_url, charset="utf-8")
set_src_local!() = settings.src = h.script(src=plotly_path, charset="utf-8")
set_src_standalone!() = settings.src = h.script(read(plotly_path, String), charset="utf-8")

#-----------------------------------------------------------------------------# Trace
struct Trace
    attributes::Config
end
(t::Trace)(; kw...) = Trace(merge(getfield(t, :attributes), Config(kw)))
Plot(traces::Trace...; kw...) = Plot([t.attributes for t in traces]; kw...)

trace(; kw...) = Trace(Config(kw))

Base.getproperty(::typeof(trace), type::Symbol) = trace(; type)
Base.propertynames(::typeof(trace)) = collect(keys(plotly_schema.schema.traces))

#-----------------------------------------------------------------------------# help
help(trace::Union{Symbol, AbstractString}) = plotly_schema.schema.traces[trace].attributes
help(trace::Union{Symbol, AbstractString}, attr::Union{Symbol, AbstractString}) = help(trace)[attr]

end # module
