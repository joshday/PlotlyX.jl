module PlotlyX

using Random: randstring
using Downloads: download
using REPL

using Scratch, JSON3, EasyConfig, Cobweb, StructTypes
using Cobweb: h, Node

#-----------------------------------------------------------------------------# exports
export Plot, Config

#-----------------------------------------------------------------------------# macros
macro scratch_path(path...); esc(:(joinpath(Scratch.get_scratch!("assets"), $(path...)))); end

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

_template_url(t) = "https://raw.githubusercontent.com/plotly/plotly.py/master/packages/" *
                  "python/plotly/plotly/package_data/templates/$t.json"

const TEMPLATE_NAMES = (:ggplot2, :gridon, :plotly, :plotly_dark, :plotly_white, :presentation,
                        :seaborn, :simple_white, :xgridoff, :ygridoff)

fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
fix_matrix(x) = x
fix_matrix(x::AbstractMatrix) = eachrow(x)

#-----------------------------------------------------------------------------# __init__
plotly_version::VersionNumber = v"0.0.0"
plotly_url::String = ""
plotly_path::String = ""
plotly_template_paths::Dict{Symbol, String} = Dict()
plotly_schema_path::String = ""

function __init__()
    global plotly_version = isfile(@scratch_path("plotly.min.js")) ?
        get_semver(readuntil(@scratch_path("plotly.min.js"), "*/")) :
        plotly_latest()
    global plotly_url = "https://cdn.plot.ly/plotly-$(plotly_version).min.js"
    global plotly_path = @download(plotly_url, @scratch_path("plotly.min.js"))
    global plotly_template_paths = Dict(t => @download(_template_url(t)) for t in TEMPLATE_NAMES)
    global plotly_schema_path = @download("https://api.plot.ly/v2/plot-schema?format=json&sha1=%27%27", @scratch_path("plot-schema.json"))
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
end
Plot(data::Config, layout::Config = Config(), config::Config = Config()) = Plot([data], layout, config, randstring(10))
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

#-----------------------------------------------------------------------------# Settings
Base.@kwdef mutable struct Settings
    src::Cobweb.Node    = h.script(src=plotly_url, charset="utf-8")
    div::Cobweb.Node    = h.div(; style="height:100%;width:100%;")
    layout::Config      = Config()
    config::Config      = Config(responsive=true)
    reuse_preview::Bool = true
end

settings = Settings()


#-----------------------------------------------------------------------------# Presets
_template!(t) = (settings.layout.template = JSON3.read(read(plotly_template_paths[t])); nothing)

template_none!()         = haskey(settings.layout, :template) && delete!(settings.layout, :template)
template_ggplot2!()      = _template!(:ggplot2)
template_gridon!()       = _template!(:gridon)
template_plotly!()       = _template!(:plotly)
template_plotly_dark!()  = _template!(:plotly_dark)
template_plotly_white!() = _template!(:plotly_white)
template_presentation!() = _template!(:presentation)
template_seaborn!()      = _template!(:seaborn)
template_simple_white!() = _template!(:simple_white)
template_xgridoff!()     = _template!(:xgridoff)
template_ygridoff!()     = _template!(:ygridoff)

src_none!() = settings.src = h.div("src_none!", style="display:none;")
src_cdn!()  = settings.src = h.script(src=plotly_url, charset="utf-8")
src_local!() = settings.src = h.script(src=plotly_path, charset="utf-8")
src_standalone!() = settings.src = h.script(read(plotly_path, String), charset="utf-8")

# For Jupyter (doesn't work yet)
src_require!() = settings.src = h.script(charset="utf-8", type="text/javascript", """
    require.config({ paths: { plotly: "$plotly_url" } });
    require(['plotly'], function(Plotly) { window.Plotly = Plotly; });
    """)


end # module
