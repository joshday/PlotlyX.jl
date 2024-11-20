function json_join(io::IO, itr, x)
    first = true
    for item in itr
        first ? (first = false) : print(io, x)
        json(io, item)
    end
end

json(x) = sprint(json, x)

json(io::IO, args...) = foreach(x -> json(io, x), args)

json(io::IO, x::Union{AbstractString, Symbol, AbstractChar}) = print(io, '"', x, '"')
json(io::IO, x::Real) = print(io, x)
json(io::IO, x::Rational) = json(io, float(x))
json(io::IO, ::Union{Missing, Nothing}) = print(io, "null")
json(io::IO, x::Pair) = (json(io, string(x.first)); print(io, ':'); json(io, x.second))
json(io::IO, x::AbstractVector) = (print(io, '['); json_join(io, x, ','); print(io, ']'))
json(io::IO, x::AbstractArray) = json(io, eachslice(x; dims=1))
json(io::IO, x) = (print(io, '['); join(io, x, ','); print(io, ']'))
json(io::IO, x::Union{NamedTuple, AbstractDict}) = (print(io, '{'); json_join(io, pairs(x), ','); print(io, '}'))

struct JSON{T}
    content::T
end
json(io::IO, x::JSON) = print(io, x.content)

macro json_str(x); :(JSON($x)) end
