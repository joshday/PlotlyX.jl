module PlotlyXUnitfulExt

import PlotlyX: json, plot_args
using Unitful

json(io::IO, x::Unitful.AbstractQuantity) = json(io, x.val)

const V = AbstractVector{<: Unitful.Quantity}
_unit(v::V) = string(unit(eltype(v)))

plot_args(y::V) = (; y, layout_yaxis_title=_unit(v))
plot_args(x::V, y::V) = (; x, y, layout_xaxis_title=_unit(x), layout_yaxis_title=_unit(y))
plot_args(x::V, y::V, z::V) = (; x, y, z, layout_scene_xaxis_title=_unit(x), layout_scene_yaxis_title=_unit(y), layout_scene_zaxis_title=_unit(z), type=:scatter3d)

end
