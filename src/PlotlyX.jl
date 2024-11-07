module PlotlyX

using Artifacts, JSON3
using OrderedCollections: OrderedDict
using DefaultApplication

export Trace, Layout, Config, Plot, help

#-----------------------------------------------------------------------------# PlotlyArtifacts
artifact(x...) = joinpath(artifact"plotly_artifacts", x...)

Base.@kwdef struct PlotlyArtifacts
    version::VersionNumber  = VersionNumber(read(artifact("version.txt"), String))
    url::String             = "https://cdn.plot.ly/plotly-$version.min.js"
    path::String            = artifact("plotly.min.js")
    schema::JSON3.Object    = JSON3.read(read(artifact("plot-schema.json"), String))
    templates::Dict{String,String} = Dict(t => artifact("templates", t) for t in readdir(artifact("templates")))
end
Base.show(io::IO, p::PlotlyArtifacts) = print(io, "PlotlyArtifacts: v$(p.version)")

global plotly::PlotlyArtifacts
function __init__()
    global plotly = PlotlyArtifacts()
end

#-----------------------------------------------------------------------------# "piracy" for JSON3.write
json(io::IO, x::Union{Number, AbstractString, Symbol, AbstractVector}) = JSON3.write(io, x, allow_inf=true)


#-----------------------------------------------------------------------------# PlotlyObject
abstract type PlotlyObject  <: AbstractDict{String, Any} end
# Requires:
# 1) Constructor to be: T(kw::Pair...)
# 2) Base.propertynames to return all possible attributes in the schema

attrs(o::PlotlyObject) = getfield(o, :attributes)
Base.iterate(o::PlotlyObject) = iterate(attrs(o))
Base.iterate(o::PlotlyObject, state) = iterate(attrs(o), state)
Base.length(o::PlotlyObject) = length(attrs(o))

Base.getindex(o::PlotlyObject, key::String) = attrs(o)[key]
Base.getindex(o::PlotlyObject, key::Symbol) = o[string(key)]
Base.keys(o::PlotlyObject) = keys(attrs(o))
Base.setindex!(o::PlotlyObject, value, key::String) = setindex!(attrs(o), value, key)

# kwarg constructor for PlotlyObject subtypes
(::Type{T})(; kw...) where {T <: PlotlyObject} = T([string(k) => v for (k,v) in kw]...)

Base.propertynames(o::PlotlyObject) = keys(help(o))
function Base.getproperty(o::PlotlyObject, prop::Symbol)
    haskey(attrs(o), string(prop)) && return o[prop]
    help(o, prop)
end

#-----------------------------------------------------------------------------# Trace
struct Trace <: PlotlyObject
    attributes::OrderedDict{String, Any}
    Trace(kw::Pair...) = new(OrderedDict{String,Any}("type" => "scatter", kw...))
end
help(t::Trace) = plotly.schema.traces[t.type]
help(t::Trace, x::Symbol) = help(t).attributes[x]

#-----------------------------------------------------------------------------# Layout
struct Layout <: PlotlyObject
    attributes::OrderedDict{String, Any}
    Layout(kw::Pair...) = new(OrderedDict{String,Any}(kw...))
end
help(l::Layout) = plotly.schema.layout.layoutAttributes
help(l::Layout, x::Symbol) = help(l)[x]

#-----------------------------------------------------------------------------# Config
struct Config <: PlotlyObject
    attributes::OrderedDict{String, Any}
    Config(kw::Pair...) = new(OrderedDict{String,Any}(kw...))
end
help(c::Config) = plotly.schema.config
help(c::Config, x::Symbol) = help(c)[x]


#-----------------------------------------------------------------------------# Plot
struct Plot
    data::Vector{Trace}
    layout::Layout
    config::Config
end


end  # PlotlyLight module
