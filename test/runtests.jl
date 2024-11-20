using PlotlyX
using PlotlyX: settings
using Test
using Aqua

html(x) = repr("text/html", x)

#-----------------------------------------------------------------------------# Plot methods
@testset "Plot methods" begin
    plot()
end

#-----------------------------------------------------------------------------# Aqua
Aqua.test_all(PlotlyX; deps_compat=(; ignore=[:Aqua, :Test], check_extras = (;ignore=[:Aqua, :Test])))
