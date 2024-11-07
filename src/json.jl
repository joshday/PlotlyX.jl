json(x) = sprint(json, x)

json(io::IO, x) = foreach(x -> print(io, x), json_itr(x))


json_itr(x::Union{AbstractString, Symbol, AbstractChar}) = ('"', x, '"')
json_itr(x::Real) = x
json_itr(x::Rational) = float(x)
json_itr(::Union{Missing, Nothing}) = "null"
json_itr(::AbstractVector) = ('['])


# json(io::IO, x::Union{AbstractString, Symbol, AbstractChar}) = print(io, '"', x, '"')
# json(io::IO, x::Real) = print(io, x)
# json(io::IO, x::Rational) = json(io, float(x))
# json(io::IO, ::Union{Missing, Nothing}) = print(io, "null")

# function json(io::IO, x::AbstractVector)
#   print(io, '[')
#   for (i, xi) in enumerate(x)
#     json(io, xi)
#     i < length(x) && print(io, ',')
#   end
#   print(io, ']')
# end

# json(io::IO, x::AbstractArray) = json(io, eachslice(x; dims=1))

# function json(io::IO, x::AbstractDict)
#     print(io, '{')
#     for (i, (k, v)) in enumerate(pairs(x))
#         json(io, k)
#         print(io, ':')
#         json(io, v)
#         i < length(x) && print(io, ',')
#     end
#     print(io, '}')
# end
