module PlotlyX

using Random: randstring
using Downloads: download

using Scratch, JSON3, EasyConfig, Cobweb, StructTypes
using Cobweb: h

#-----------------------------------------------------------------------------# exports
export Plot

#-----------------------------------------------------------------------------# utils
macro download(url)
    esc(quote
        let
            file = joinpath(PlotlyX.scratchdir(), basename($url))
            if !isfile(file)
                @info string("Downloading ", basename($url))
                PlotlyX.download($url, file)
            end
            file
        end
    end)
end

get_semver(x) = VersionNumber(match(r"v(\d+)\.(\d+)\.(\d+)", x).match[2:end])

function plotly_latest_version()
    file = download("https://api.github.com/repos/plotly/plotly.js/releases/latest")
    VersionNumber(JSON3.read(file).name)
end

fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
fix_matrix(x) = x
fix_matrix(x::AbstractMatrix) = eachrow(x)

#-----------------------------------------------------------------------------# __init__
scratchdir() = Scratch.get_scratch!("assets")

template_url(t) = "https://raw.githubusercontent.com/plotly/plotly.py/master/packages/" *
                  "python/plotly/plotly/package_data/templates/$t.json"

Base.@kwdef struct Templates
    ggplot2::String      = @download template_url("ggplot2")
    gridon::String       = @download template_url("gridon")
    plotly::String       = @download template_url("plotly")
    plotly_dark::String  = @download template_url("plotly_dark")
    plotly_white::String = @download template_url("plotly_white")
    presentation::String = @download template_url("presentation")
    seaborn::String      = @download template_url("seaborn")
    simple_white::String = @download template_url("simple_white")
    xgridoff::String     = @download template_url("xgridoff")
    ygridoff::String     = @download template_url("ygridoff")
end

plotly_version::Union{Nothing, VersionNumber}   = nothing
plotly_url::Union{Nothing, String}              = nothing
plotly_path::Union{Nothing, String}             = nothing
plotly_templates::Union{Nothing, Templates}     = nothing
plotly_schema_path::Union{Nothing, String}      = nothing
const plotly_schema_url = "https://api.plot.ly/v2/plot-schema?format=json&sha1=%27%27"

function __init__()
    update!()
    auto_settings!()
    pushdisplay(PlotlyXDisplay())
end

function update!(debug::Bool = false)
    Scratch.clear_scratchspaces!(PlotlyX)
    global plotly_path = joinpath(scratchdir(), "plotly.min.js")
    global plotly_version = isfile(plotly_path) ? get_semver(readuntil(plotly_path, "*/")) : plotly_latest_version()
    global plotly_url = "https://cdn.plot.ly/plotly-$(plotly_version).min.js"
    isfile(plotly_path) || cp(@download(plotly_url), plotly_path)
    global plotly_templates = Templates()
    global plotly_schema_path = joinpath(scratchdir(), "plot-schema.json")
    isfile(plotly_schema_path) || download(plotly_schema_url, plotly_schema_path)
end


#-----------------------------------------------------------------------------# Settings
Base.@kwdef mutable struct Settings
    parent::Function            = () -> nothing
    load_plotlyjs::Function     = () -> nothing
    plot_div::Function          = id -> nothing
    layout::Config              = Config()
    config::Config              = Config()
    reuse_preview::Bool         = true
    verbose::Bool               = false
end

settings::Settings = Settings()

load_plotly_cdn!() = settings.load_plotlyjs = () -> h.script(src=plotly_url, charset="utf-8")
load_plotly_local!() = settings.load_plotlyjs = () -> h.script(read(plotly_path, String), charset="utf-8")
load_plotly_standalone!() = settings.load_plotlyjs = () -> h.script(read(plotly_path, String), charset="utf-8")
load_plotly_none!() = settings.load_plotlyjs = () -> HTML("")

function preset_responsive!()
    merge!(settings.config, Config(responsive=true, height="100%", width="100%"))
    settings.plot_div = id -> h.div(style="height:100%;", h.div(; id, style="height:100%;"))
end

function auto_settings!()
    load_plotly_cdn!()
    preset_responsive!()
    return nothing
end

# function auto!()
#     if isdefined(Main, :VSCodeServer) && stdout isa Main.VSCodeServer.IJuliaCore.IJuliaStdio
#         settings.iframe = Cobweb.IFrame(""; height="450px", width="700px", style="resize:both; display:block; border:none;")
#         merge!(settings.config, Config(responsive=true, height="100%", width="100%"))
#         settings.make_container = id -> h.div(style="height:100%;", h.div(; id, style="height:100%;"))
#     end
# end

# #-----------------------------------------------------------------------------# Preset
# baremodule Preset
#     baremodule Template
#         using Base, JSON3, EasyConfig
#         using ...PlotlyLight: settings, templates
#         set_template!(t) = (settings.layout.template = open(io -> JSON3.read(io, Config), templates[t]); nothing)
#         none!() = (settings.layout.template = nothing; nothing)
#         ggplot2!()      = set_template!(:ggplot2)
#         gridon!()       = set_template!(:gridon)
#         plotly!()       = set_template!(:plotly)
#         plotly_dark!()  = set_template!(:plotly_dark)
#         plotly_white!() = set_template!(:plotly_white)
#         presentation!() = set_template!(:presentation)
#         seaborn!()      = set_template!(:seaborn)
#         simple_white!() = set_template!(:simple_white)
#         xgridoff!()     = set_template!(:xgridoff)
#         ygridoff!()     = set_template!(:ygridoff)
#     end
#     baremodule Source
#         using ...PlotlyLight: settings, plotly_url, plotly_path
#         using Cobweb: h
#         using Base
#         cdn!()        = (settings.print_plotlyjs = print_source_cdn; nothing)
#         local!()      = (settings.load_plotlyjs = () -> h.script(src=plotly_path, charset="utf-8"); nothing)
#         standalone!() = (settings.load_plotlyjs = () -> h.script(read(plotly_path, String), charset="utf-8"); nothing)
#         none!()       = (settings.load_plotlyjs = () -> HTML(""); nothing)
#     end
#     baremodule PlotContainer
#         using ...PlotlyLight: settings
#         using EasyConfig: Config
#         using Cobweb: h, IFrame
#         using Base
#         function fillwindow!()
#             settings.make_container = id -> h.div(; style="height:100vh;width:100vw;", id)
#             nothing
#         end
#         function responsive!()
#             merge!(settings.config, Config(responsive=true, height="100%", width="100%"))
#             settings.make_container = id -> h.div(style="height:100%;", h.div(; id, style="height:100%;"))
#             nothing
#         end
#         function fixed!(; height="450px", width="700px")
#             merge!(settings.config, Config(responsive=false, height=height, width=width))
#             settings.make_container = id -> h.div(; id, style="height:$height;width:$width;")
#             nothing
#         end
#         function auto!(io::IO = stdout)
#             responsive!()
#             isdefined(Main, :VSCodeServer) && iframe!()
#             isdefined(Main, :IJulia) && io isa Main.IJulia.IJuliaStdio && iframe!()
#             nothing
#         end
#         function iframe!(set::Bool=true, height="450px", width="700px", style="resize:both; display:block; border:none;", kw...)
#             settings.iframe = set ? IFrame(""; height, width, style, kw...) : nothing
#             nothing
#         end
#     end
# end

#-----------------------------------------------------------------------------# Plot
"""
    Plot(data, layout=Config(), config=Config())
    Plot(layout=Config(), config=Config(); kw...)

Create a Plotly plot with the given `data` (`Config` or `Vector{Config}`), `layout`, and `config`.
Alternatively, you can create a plot with a single trace by providing the `data` as keyword arguments.

For more info, read the Plotly.js docs: [https://plotly.com/javascript/](https://plotly.com/javascript/).

### Examples

    p = Plot(Config(x=1:10, y=randn(10)))

    p = Plot(; x=1:10, y=randn(10))
"""
mutable struct Plot
    data::Vector{Config}
    layout::Config
    config::Config
    Plot(data::Vector{Config}, layout::Config=Config(), config::Config=Config()) = new(data, layout, config)
end
Plot(data::Config, layout::Config = Config(), config::Config = Config()) = Plot([data], layout, config)
Plot(; layout=Config(), config=Config(), @nospecialize(kw...)) = Plot(Config(kw), Config(layout), Config(config))
(p::Plot)(; @nospecialize(kw...)) = p(Config(kw))
(p::Plot)(data::Config) = (push!(p.data, data); return p)

StructTypes.StructType(::Plot) = StructTypes.Struct()

Base.:(==)(a::Plot, b::Plot) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Plot))

#-----------------------------------------------------------------------------# Display
function html_body(o::Plot; id = randstring(10))
    io = IOBuffer()
    show(io, MIME"text/html"(), settings.load_plotlyjs())
    show(io, MIME"text/html"(), settings.plot_div(id))
    print(io, "<script>Plotly.newPlot(", repr(id), ", ")
    JSON3.write(io, fix_matrix.(o.data); allow_inf=true)
    print(io, ',')
    JSON3.write(io, merge(settings.layout, o.layout); allow_inf=true)
    print(io, ',')
    JSON3.write(io, merge(settings.config, o.config); allow_inf=true)
    print(io, ")</script>")
    HTML(String(take!(io)))
end

function html_page(o::Plot)
    page = h.html(
        h.head(
            h.meta(charset="utf-8"),
            h.meta(name="viewport", content="width=device-width, initial-scale=1"),
            h.meta(name="description", content="PlotlyLight.jl with Plotly $plotly_version"),
            h.title("PlotlyLight.jl with Plotly $plotly_version"),
            h.style("body { margin: 0px; }")  # removes scrollbar when in iframe
        ),
        h.body(html_body(o))
    )
    return HTML(repr("text/html", page))
end

struct PlotlyXDisplay <: AbstractDisplay end
Base.display(::PlotlyXDisplay, o::Plot) = Cobweb.preview(html_page(o); reuse=settings.reuse_preview)


function Base.show(io::IO, M::MIME"text/html", o::Plot)
    out = isnothing(settings.iframe) ? html_page(o) : Cobweb.IFrame(html_page(o); settings.iframe.kw...)
    show(io, M, out)
end

Base.show(io::IO, ::MIME"juliavscode/html", o::Plot) = show(io, MIME"text/html"(), o)

end # module
