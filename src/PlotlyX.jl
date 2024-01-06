module PlotlyX

using Random: randstring
using Downloads: download

using Scratch, JSON3, EasyConfig, Cobweb, StructTypes
using Cobweb: h

#-----------------------------------------------------------------------------# exports
export Plot, Config

#-----------------------------------------------------------------------------# __init__()
macro download(url, dest = nothing)
    esc(quote
        let
            dest = $(isnothing(dest)) ? scratchdir(basename($url)) : $dest
            isfile(dest) ? dest : (@info string("PlotlyX Downloading: ", $url); download($url, dest))
        end
    end)
end

get_semver(x) = VersionNumber(match(r"v(\d+)\.(\d+)\.(\d+)", x).match[2:end])

scratchdir(path...) = joinpath(Scratch.get_scratch!("assets"), path...)

function plotly_latest()
    file = download("https://api.github.com/repos/plotly/plotly.js/releases/latest")
    VersionNumber(JSON3.read(file).name)
end

template_url(t) = "https://raw.githubusercontent.com/plotly/plotly.py/master/packages/" *
                  "python/plotly/plotly/package_data/templates/$t.json"

const TEMPLATE_NAMES = [:ggplot2, :gridon, :plotly, :plotly_dark, :plotly_white, :presentation,
                        :seaborn, :simple_white, :xgridoff, :ygridoff]

Base.@kwdef struct Constants
    version::VersionNumber = let
        file = scratchdir("plotly.min.js")
        isfile(file) ? get_semver(readuntil(file, "*/")) : plotly_latest()
    end
    url::String          = "https://cdn.plot.ly/plotly-$(version).min.js"
    path::String         = @download(url, scratchdir("plotly.min.js"))
    template_paths::Dict{Symbol, String} = Dict(t => @download(template_url(t)) for t in TEMPLATE_NAMES)
    schema_url::String   = "https://api.plot.ly/v2/plot-schema?format=json&sha1=%27%27"
    schema_path::String  = @download(schema_url, scratchdir("plot-schema.json"))
end

plotly::Union{Nothing, Constants} = nothing

function update!()
    Scratch.clear_scratchspaces!(PlotlyX)
    global plotly = Constants()
    nothing
end

function __init__()
    global plotly = Constants()
    preset_auto!()
    pushdisplay(PlotlyXDisplay())
end

#-----------------------------------------------------------------------------# Settings
print_plotly_cdn(io::IO) = print(io, "<script src=\"", plotly.url, "\" charset=\"utf-8\"></script>")
print_plotly_local(io::IO) = print(io, "<script>", read(plotly.path, String), "</script>")
print_plotly_standalone(io::IO) = print(io, "<script>", read(plotly.path, String), "</script>")

Base.@kwdef mutable struct Settings
    print_load_script::Function = print_plotly_cdn
    print_div::Function         = (io, id) -> print(io, "<div id=\"", id, "\"></div>")
    layout::Config              = Config()
    config::Config              = Config()
    reuse_preview::Bool         = true
end

settings::Settings = Settings()

#-----------------------------------------------------------------------------# Presets
function preset_auto!()
    preset_div_responsive!()
end

function preset_div_responsive!()
    merge!(settings.config, Config(responsive=true, height="100%", width="100%"))
    settings.print_div = (io, id) -> print(io, """<div style="height:100%;"><div style="height:100%" id=$id></div></div>""")
end

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
struct _JSON
    x
end
Base.show(io::IO, j::_JSON) = (print(io, ','); JSON3.write(io, j.x; allow_inf=true))

function print_html_div(io::IO, o::Plot; id=randstring(10))
    settings.print_load_script(io)
    settings.print_div(io, id)
    print(io, "<script>Plotly.newPlot(", repr(id), _JSON(o.data), _JSON(o.layout), _JSON(o.config), ")</script>")
end

function print_html_page(io::IO, o::Plot; id=randstring(10))
    print(io, """
    <!doctype html>
    <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="description" content="PlotlyLight.jl">
            <title>PlotlyLight.jl</title>
            <style>body { margin: 0px; } /* remove scrollbar in iframe */</style>
        </head>
        <body>
    """)
    print_html_div(io, o; id=id)
    print(io, """
        </body>
    </html>
    """)
end

fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
fix_matrix(x) = x
fix_matrix(x::AbstractMatrix) = eachrow(x)

struct PlotlyXDisplay <: AbstractDisplay end
Base.display(::PlotlyXDisplay, o::Plot) = Cobweb.preview(o; reuse=settings.reuse_preview)


function Base.show(io::IO, M::MIME"text/html", o::Plot)
    print_html_div(io, o)
end

Base.show(io::IO, ::MIME"juliavscode/html", o::Plot) = show(io, MIME"text/html"(), o)

end # module
