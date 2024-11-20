using PlotlyX
using PlotlyX: Plot, Help, Object, settings, json, presets
using Test
using Aqua

html(x) = repr("text/html", x)

#-----------------------------------------------------------------------------# json
@testset "json" begin
    @test json(1:3) == "[1,2,3]"
    @test json([1, 2, 3]) == "[1,2,3]"
    @test json("test") == "\"test\""
    @test json('a') == "a"
    @test json([1 2 3; 4 5 6]) == "[[1,2,3],[4,5,6]]"
    @test json((x=1,y=2)) == "{\"x\":1,\"y\":2}"
end

#-----------------------------------------------------------------------------# trace
@testset "trace" begin
    t = trace()
    @test t isa Object
    @test t.type == :scatter
    @test hasproperty(t, :marker)
    @test hasproperty(t.marker, :line)
    @test t.marker isa Object
    @test t.marker.line isa Object
    @test (t.marker.line.width = 1) == 1
    @test t.marker.line.width == 1
    @test :bar in propertynames(trace)
    @test trace.bar() isa Object
    @test trace.bar().type == :bar
end

#-----------------------------------------------------------------------------# layout
@testset "layout" begin
    l = layout()
    @test l isa Object
    @test hasproperty(l, :title)
    @test hasproperty(l.title, :text)
end

#-----------------------------------------------------------------------------# config
@testset "config" begin
    c = config()
    @test c isa Object
    @test hasproperty(c, :edits)
    @test hasproperty(c.edits, :legendPosition)
end

#-----------------------------------------------------------------------------# help
@testset "help" begin
    h = help(trace())
    @test h isa Help
    @test hasproperty(h, :marker)
    @test h.marker isa Help
    @test hasproperty(h.marker, :line)
    @test h.marker.line isa Help
end

#-----------------------------------------------------------------------------# Plot methods
@testset "Plot methods" begin
    @test plot() isa Plot
    @test contains(repr("text/html", plot()), "Plotly.newPlot")
    for type in propertynames(plot)
        @test getproperty(plot, type)() isa Plot
    end
end

#-----------------------------------------------------------------------------# presets
@testset "presets" begin
    # Check that nothing is broken
    for (k, v) in pairs(presets)
        for (k2, v2) in pairs(v)
            v2()
        end
    end
end

#-----------------------------------------------------------------------------# Aqua
Aqua.test_all(PlotlyX; deps_compat=(; ignore=[:Aqua, :Test], check_extras = (;ignore=[:Aqua, :Test])))
