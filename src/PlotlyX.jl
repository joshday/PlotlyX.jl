module PlotlyX

using Random: randstring
using Downloads: download

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
get_semver(x) = VersionNumber(match(r"v(\d+)\.(\d+)\.(\d+)", x).match[2:end])

function plotly_latest()
    file = download("https://api.github.com/repos/plotly/plotly.js/releases/latest")
    VersionNumber(JSON3.read(file).name)
end

template_url(t) = "https://raw.githubusercontent.com/plotly/plotly.py/master/packages/" *
                  "python/plotly/plotly/package_data/templates/$t.json"

const TEMPLATE_NAMES = (:ggplot2, :gridon, :plotly, :plotly_dark, :plotly_white, :presentation,
                        :seaborn, :simple_white, :xgridoff, :ygridoff)

fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
fix_matrix(x) = x
fix_matrix(x::AbstractMatrix) = eachrow(x)

#-----------------------------------------------------------------------------# Assets
Base.@kwdef struct Assets
    version::VersionNumber = let
        file = @scratch_path("plotly.min.js")
        isfile(file) ? get_semver(readuntil(file, "*/")) : plotly_latest()
    end
    url::String = "https://cdn.plot.ly/plotly-$(version).min.js"
    path::String = @download(url, @scratch_path("plotly.min.js"))
    template_paths::Dict{Symbol, String} = Dict(t => @download(template_url(t)) for t in TEMPLATE_NAMES)
    schema_path::String = @download("https://api.plot.ly/v2/plot-schema?format=json&sha1=%27%27", @scratch_path("plot-schema.json"))
end

plotly::Union{Nothing, Assets} = nothing

function update!()
    Scratch.clear_scratchspaces!(PlotlyX)
    global plotly = Assets()
    nothing
end

#-----------------------------------------------------------------------------# __init_)
function __init__()
    global plotly = Assets()
    # preset_auto!()
    pushdisplay(PlotlyXDisplay())
end

#-----------------------------------------------------------------------------# Plot
mutable struct Plot
    data::Vector{Config}
    layout::Config
    config::Config
end
Plot(data::Config, layout::Config = Config(), config::Config = Config()) = Plot([data], layout, config)
Plot(; layout=Config(), config=Config(), @nospecialize(kw...)) = Plot(Config(kw), Config(layout), Config(config))
(p::Plot)(; @nospecialize(kw...)) = p(Config(kw))
(p::Plot)(data::Config) = (push!(p.data, data); return p)

StructTypes.StructType(::Plot) = StructTypes.Struct()

Base.:(==)(a::Plot, b::Plot) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Plot))


#-----------------------------------------------------------------------------# Settings
# Defaults are for REPL and VSCode display
Base.@kwdef mutable struct Settings
    pre_div::Function   = () -> h.script(src=plotly.url, charset="utf-8")
    div::Function       = (id) -> h.div(; id, style="height:100vh;width:100vw;")
    post_div::Function  = () -> h.div("unused post_div", style="display:none;")
    layout::Config      = Config()
    config::Config      = Config(responsive=true)
    reuse_preview::Bool = true
end

settings::Settings = Settings()

#-----------------------------------------------------------------------------# display
struct PlotlyXDisplay <: AbstractDisplay end
Base.display(::PlotlyXDisplay, o::Plot) = Cobweb.preview(o; reuse=settings.reuse_preview)

function html_div(o::Plot; id=randstring(10))
    data = fix_matrix.(o.data)
    layout = merge(settings.layout, o.layout)
    config = merge(settings.config, o.config)
    h.div(
        settings.pre_div(), settings.div(id), settings.post_div(),
        h.script("""
            var data = $(JSON3.write(data; allow_inf=true));
            var layout = $(JSON3.write(layout; allow_inf=true));
            var config = $(JSON3.write(config; allow_inf=true));
            Plotly.newPlot("$id", data, layout, config)
        """)
    )
end

html_page(o::Plot; id=randstring(10)) =
    h.html(
        h.head(
            h.meta(charset="utf-8"),
            h.meta(name="viewport", content="width=device-width, initial-scale=1"),
            h.meta(name="description", content="PlotlyX.jl"),
            h.title("PlotlyX.jl"),
            h.style("body { margin: 0px; } /* remove scrollbar in iframe */"),
        ),
        h.body(html_div(o; id))
    )

function Base.show(io::IO, M::MIME"text/html", o::Plot; id=randstring(10))
    show(io, M, html_page(o; id))
end

Base.show(io::IO, ::MIME"juliavscode/html", o::Plot) = print(io, settings.generate_html())


# #-----------------------------------------------------------------------------# Presets
# preset_repl!() = (global settings = Settings())


# function preset_auto!(io::IO = stdout)
#     global settings = Settings()  # REPL, VSCodeServer.InlineDisplay
#     if :pluto in keys(io)
#         settings.div = h.div(id="{id}", style="height:100%;width:100%;")
#     elseif isdefined(Main, :VSCodeServer) && io isa VSCodeServer.IJuliaCore.IJuliaStdio
#         settings.parent = (pre_div, div, post-div) = IFrame(h.div(pre_div, div, post_div), width="100%", height="100%")))
#     end
#     nothing
# end



# function preset_container_fillwindow!()
#     settings.config.responsive = true
#     settings.print_div = (io, id) -> print(io, "    <div style=\"height:100vh;width:100vw;\" id=\"", id, "\"/>")
# end

# function print_iframe(io::IO, id::String)
#     buf = IOBuffer()
#     preset_container_fillwindow!()
#     print_html_page(buf,)
# end

# function preset_container_iframe!(height="400px", width="750px")
#     settings.config.responsive = true

# end



#
# #-----------------------------------------------------------------------------# Display
# struct PlotlyXDisplay <: AbstractDisplay end
# Base.display(::PlotlyXDisplay, o::Plot) = Cobweb.preview(o; reuse=settings.reuse_preview)

# fix_matrix(x::Config) = Config(k => fix_matrix(v) for (k,v) in pairs(x))
# fix_matrix(x) = x
# fix_matrix(x::AbstractMatrix) = eachrow(x)



# function print_html_page(io::IO, o::Plot; id=randstring(10))
#     print(io, """
#     <!doctype html>
#     <html>
#       <head>
#         <meta charset="utf-8">
#         <meta name="viewport" content="width=device-width, initial-scale=1">
#         <meta name="description" content="PlotlyX.jl">
#         <title>PlotlyX.jl</title>
#         <style>body { margin: 0px; } /* remove scrollbar in iframe */</style>
#       </head>
#       <body>
#     """)
#     print_html_div(io, o; id=id)
#     print(io, """
#       </body>
#     </html>
#     """)
# end

# srcdoc(o::Plot) = (buf = IOBuffer(); print_html_page(buf, o); escape(String(take!(buf))))

# function print_iframe(io::IO, o::Plot; height="400px", width="750px")
#     id = "plotlyx-iframe-$(randstring(10))"
#     print(io, "<iframe id=\"$id\" style=\"height:$height;width:$width;border:none;\" srcdoc=\"", srcdoc(o), "\"></iframe>")
# end


# function Base.show(io::IO, M::MIME"text/html", o::Plot)
#     print_iframe(io, o)
# end

# Base.show(io::IO, ::MIME"juliavscode/html", o::Plot) = print_html_page(io, o)

end # module
