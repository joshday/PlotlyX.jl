module PlotlyX

using Artifacts, JSON3
using OrderedCollections: OrderedCollections, OrderedDict
using DefaultApplication
using Cobweb

export trace, layout, config, plot, help, prune!

#-----------------------------------------------------------------------------# PlotlyArtifacts
_path(x...) = joinpath(artifact"plotly_artifacts", x...)

Base.@kwdef struct PlotlyArtifacts
    version::VersionNumber  = VersionNumber(read(_path("version.txt"), String))
    url::String             = "https://cdn.plot.ly/plotly-$version.min.js"
    path::String            = _path("plotly.min.js")
    schema::JSON3.Object    = JSON3.read(read(_path("plot-schema.json")))
    templates::Dict{String,String} = Dict(t => _path("templates", t) for t in readdir(_path("templates")))
end
Base.show(io::IO, p::PlotlyArtifacts) = print(io, "PlotlyArtifacts: v$(p.version)")

function __init__()
    global plotly = PlotlyArtifacts()
    global settings = Settings()

    # Hack since extensions with REPL are wonky
    for M in Base.loaded_modules_order
        Symbol(M) == :REPL && @eval Base.display(::$M.REPLDisplay, o::Plot) = Cobweb.preview(html_page(o))
    end
end

function schema_ref(ref::Vector{Symbol})
    o = plotly.schema
    for k in ref
        o = o[k]
    end
    return o
end

#-----------------------------------------------------------------------------# json
include("json.jl")

#-----------------------------------------------------------------------------# Fields & Keys
struct Fields{T}; x::T; end
Base.propertynames(f::Fields) = fieldnames(getfield(f, :x))
Base.getproperty(f::Fields, x::Symbol) = getfield(getfield(f, :x), x)

struct Keys{T}; x::T; end
Base.propertynames(k::Keys) = keys(getfield(k, :x))
Base.getproperty(k::Keys, x::Symbol) = getindex(getfield(k, :x), x)

#-----------------------------------------------------------------------------# Object
struct Object <: AbstractDict{Symbol, Any}
    dict::OrderedDict{Symbol, Any}
    ref::Vector{Symbol}
end
Object(args::Pair...; ref=Symbol[]) = Object(OrderedDict{Symbol,Any}(args...), ref)
Object(ref=Symbol[]; kw...) = Object(OrderedDict{Symbol,Any}(kw...), ref)

(o::Object)(; kw...) = set_kw!(o, kw)

Base.iterate(o::Object, state...) = iterate(Fields(o).dict, state...)
Base.length(o::Object) = length(Fields(o).dict)

help(o::Object) = schema_ref(Fields(o).ref)

function set_kw!(o::Object, kw)
    for (k, v) in kw
        path = Symbol.(split(string(k), '_'))
        obj = o
        for k2 in path[1:end-1]
            obj = get!(obj, k2, Object([getfield(obj, :ref)..., k2]))
        end
        obj[path[end]] = v
    end
    return o
end

struct NotSet <: AbstractDict{Symbol, Any}
    help::JSON3.Object
end
Base.length(o::NotSet) = length(getfield(o, :help))
Base.iterate(o::NotSet, state...) = iterate(getfield(o, :help), state...)
Base.propertynames(o::NotSet) = keys(getfield(o, :help))
Base.getproperty(o::NotSet, x::Symbol) = NotSet(getfield(o, :help)[x])

Base.keys(o::Object) = keys(help(o))
function Base.getindex(o::Object, x::Symbol)
    f = Fields(o)
    haskey(f.dict, x) && return f.dict[x]
    haskey(o, x) && return (f.dict[x] = Object(vcat(f.ref, x)))
    throw(KeyError(x))
end
Base.setindex!(o::Object, v, x::Symbol) = setindex!(Fields(o).dict, v, x)
Base.delete!(o::Object, x::Symbol) = delete!(Fields(o).dict, x)

prune!(x) = x
function prune!(o::Object)
    for (k, v) in o
        v isa Object && isempty(v) ? delete!(o, k) : prune!(v)
    end
    return o
end

Base.propertynames(o::Object) = keys(o)
Base.getproperty(o::Object, x::Symbol) = o[x]
Base.setproperty!(o::Object, x::Symbol, v) = setindex!(o, v, x)


function trace(; kw...)
    type = Symbol(get(kw, :type, :scatter))
    set_kw!(Object([:traces, type, :attributes]; type=type), kw)
end
Base.getproperty(::typeof(trace), x::Symbol) = trace(; type=x)
Base.propertynames(::typeof(trace)) = keys(plotly.schema.traces)

layout(; kw...) = set_kw!(Object([:layout, :layoutAttributes]), kw)

config(; kw...) = set_kw!(Object([:config]), kw)

Base.copy(o::Object) = Object(copy(getfield(o, :dict)), getfield(o, :ref))

function Base.merge!(a::Object, b::Object)
    af, bf = Fields(a), Fields(b)
    af.ref == bf.ref || throw(ArgumentError("Cannot merge objects that represent different parts of the Plotly schema."))
    set_kw!(a, b)
end
Base.merge(a::Object, b::Object) = merge!(copy(a), b)

#-----------------------------------------------------------------------------# Plot
@kwdef struct Plot
    data::Vector{Object} = Object[]
    layout::Object = layout()
    config::Object = config()
end
Base.getindex(o::Plot, i::Integer) = o.data[i]
Base.lastindex(o::Plot) = lastindex(o.data)

#-----------------------------------------------------------------------------# Settings
@kwdef mutable struct Settings
    div::Cobweb.Node        = h.div(class="plotlyx-plot")
    src::Cobweb.Node        = h.script(src=plotly.url, charset="utf-8")
    layout::Object          = layout()
    config::Object          = config(responsive=true, displaylogo=false)
    page_css::Cobweb.Node   = h.style("html, body { padding: 0px; margin: 0px; }")
    src_inject              = ""
    iframe_style            = "display:block; border:none; min-height:350px; min-width:350px; width:100%; height:100%"
end
Base.copy(s::Settings) = Settings(s.div(), s.src(), copy(s.layout), copy(s.config), s.page_css, s.src_inject, s.iframe_style)

function Settings(s::Settings; kw...)
    s2 = Settings((getfield(s, f) for f in fieldnames(Settings))...)
    for (k, v) in kw
        setfield!(s2, k, v)
    end
    return s2
end

function with_settings(f; kw...)
    old = settings
    try
        global settings = Settings(settings; kw...)
        f(settings)
    finally
        global settings = old
    end
end

#-----------------------------------------------------------------------------# presets
template!(t) = (settings.layout.template = JSON3.read(read(plotly.templates["$t.json"])); nothing)


presets = (;
    template = (
        none!           = () -> (haskey(settings.layout, :template) && delete!(settings.layout, :template); nothing),
        ggplot2!        = () -> template!(:ggplot2),
        gridon!         = () -> template!(:gridon),
        plotly!         = () -> template!(:plotly),
        plotly_dark!    = () -> template!(:plotly_dark),
        plotly_white!   = () -> template!(:plotly_white),
        presentation!   = () -> template!(:presentation),
        seaborn!        = () -> template!(:seaborn),
        simple_white!   = () -> template!(:simple_white),
        xgridoff!       = () -> template!(:xgridoff),
        ygridoff!       = () -> template!(:ygridoff)
    ),
    source = (
        none!           = () -> (settings.src = h.div("No PlotlyJS Script", style="display:none")),
        cdn!            = () -> (settings.src = h.script(src=plotly.url, charset="utf-8")),
        local!          = () -> (settings.src = h.script(src=plotly.path, charset="utf-8")),
        standalone!     = () -> (settings.src = h.script(read(plotly.path, String), charset="utf-8"))
    ),
    display = (
        fullscreen!     = () -> (settings.div.style = "height:100vh; width:100vw"),
        mathjax!        = () -> (settings.src_inject = h.script(src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js")),
    )
)

#-----------------------------------------------------------------------------# NewPlotScript
# PlotlyX representation of: <script>Plotly.newPlot("$id", $data, $layout, $config)</script>
struct NewPlotScript
    plot::Plot
    settings::Settings
    id::String
end
function Base.show(io::IO, ::MIME"text/html", o::NewPlotScript)
    layout = merge(o.settings.layout, o.plot.layout)
    config = merge(o.settings.config, o.plot.config)
    print(io, "<script>Plotly.newPlot(\"", o.id, "\",")
    json(io, o.plot.data); print(io, ',')
    json(io, layout); print(io, ',')
    json(io, config)
    print(io, ")</script>")
end

#-----------------------------------------------------------------------------# display
rand_id() = "plotlyx-" * join(rand('a':'z', 10))

function html_div(o::Plot, id=rand_id())
    h.div(class="plotlyx-parent", settings.src, settings.div(; id), NewPlotScript(o, settings, id))
end

function html_page(o::Plot, id=rand_id())
    h.html(
        h.head(
            h.meta(charset="utf-8"),
            h.meta(name="viewport", content="width=device-width, initial-scale=1"),
            h.meta(name="description", content="PlotlyX Plot"),
            h.title("PlotlyX"),
            settings.page_css,
            settings.src_inject,
            settings.src
        ),
        h.body(html_div(o, id))
    )
end

function html_iframe(o::Plot, id=rand_id(), kw...)
    with_settings() do s
        s.div.style = "height:100vh; width:100vw"
        Cobweb.IFrame(html_page(o, id); style=s.iframe_style, kw...)
    end
end

function Base.show(io::IO, ::MIME"text/html", o::Plot)
    get(io, :jupyter, false) && return show(io, MIME("text/html"), html_iframe(o))
    show(io, MIME("text/html"), html_div(o))
end
Base.show(io::IO, ::MIME"juliavscode/html", o) = show(io, MIME("text/html"), o)


#-----------------------------------------------------------------------------# plot
function plot(; layout=layout(), config=config(), kw...)
    layout_kw = filter(x -> startswith(string(x.first), "layout_"), kw)
    config_kw = filter(x -> startswith(string(x.first), "config_"), kw)
    trace_kw = setdiff(kw, layout_kw, config_kw)
    layout_kw2 = ((Symbol(string(x.first)[8:end]), x.second) for x in layout_kw)
    config_kw2 = ((Symbol(string(x.first)[8:end]), x.second) for x in config_kw)
    t = trace(; trace_kw...)
    Plot([t], layout(; layout_kw2...), config(; config_kw2...))
end

plot(args...; kw...) = plot(; plot_args(args...)..., kw...)

const RealVec = AbstractVector{<:Real}

plot_args(y::RealVec) = (; y, type=:scatter)
plot_args(x::RealVec, y::RealVec) = (; x, y, type=:scatter)
plot_args(x::RealVec, y::RealVec, z::RealVec) = (; x, y, z, type=:scatter3d)

Base.propertynames(::typeof(plot)) = keys(plotly.schema.traces)
Base.getproperty(::typeof(plot), x::Symbol) = (args...; kw...) -> plot(args...; type=x, kw...)


end  # PlotlyX module
