function json_join(io::IO, itr, sep)
    for (i, item) in enumerate(itr)
        i == 1 || print(io, sep)
        json(io, item)
    end
end

json(x) = sprint(json, x)

json(io::IO, args...) = foreach(x -> json(io, x), args)

# Strings
json(io::IO, x::Union{AbstractString, Symbol, AbstractChar}) = print(io, '"', x, '"')

# Numbers
json(io::IO, x::Real) = print(io, x)
json(io::IO, x::Rational) = json(io, float(x))

# Null
json(io::IO, ::Union{Missing, Nothing}) = print(io, "null")

# Bool
json(io::IO, x::Bool) = print(io, x ? "true" : "false")

# Arrays
json(io::IO, x::AbstractVector) = (print(io, '['); json_join(io, x, ','); print(io, ']'))
json(io::IO, x::AbstractArray) = json(io, eachslice(x; dims=1))
json(io::IO, x) = (print(io, '['); json_join(io, x, ','); print(io, ']'))  # ← FALLBACK METHOD

# Objects
json(io::IO, x::Pair) = (json(io, string(x.first)); print(io, ':'); json(io, x.second))
json(io::IO, x::Union{NamedTuple, AbstractDict}) = (print(io, '{'); json_join(io, pairs(x), ','); print(io, '}'))
