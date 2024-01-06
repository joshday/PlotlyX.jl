using PlotlyX
using PlotlyX: settings
using Test
using Aqua

html(x) = repr("text/html", x)

#-----------------------------------------------------------------------------# Plot methods
@testset "Plot methods" begin
    p = Plot(Config(x = 1:10))
    @test p isa Plot
    @test Plot(; x=1:10) == p
    @test !occursin("Title", html(p))
    @test !occursin("displaylogo", html(p))

    p2 = Plot(Config(x = 1:10), Config(title="Title"))
    @test occursin("Title", html(p2))
    @test !occursin("displaylogo", html(p2))

    p3 = Plot(Config(x = 1:10), Config(title="Title"), Config(displaylogo=true))
    @test occursin("Title", html(p3))
    @test occursin("displaylogo", html(p3))

    p4 = Plot()
    @test isempty(only(p4.data))
    p4(Config(x=1:10,y=1:10))
    @test length(p4.data) == 2
    p4(;x=1:10, y=1:10)
    @test length(p4.data) == 3
    @test p4.data[2] == p4.data[3]
end
#-----------------------------------------------------------------------------# Presets
@testset "Presets" begin
    p = Plot(x=1:10);

    @testset "Template" begin
        for k in keys(PlotlyLight.templates)
            settings.layout.template = nothing
            getproperty(Preset.Template, Symbol("$(k)!"))()
            @test !isnothing(settings.layout.template)
            @test occursin("axis", repr("text/html", p))
            settings.layout.template = nothing
        end
    end

    @testset "Source" begin
        Preset.Source.none!()
        @test !occursin("cdn", html(p))

        Preset.Source.cdn!()
        @test occursin("cdn", html(p))

        Preset.Source.local!()
        @test length(html(p)) < 1000
        @test occursin("scratchspace", html(p))

        Preset.Source.standalone!()
        @test length(html(p)) > 1000
    end

    @testset "PlotContainer" begin
        Preset.PlotContainer.fillwindow!()
        @test occursin("height:100vh", html(p))

        Preset.PlotContainer.responsive!()
        @test occursin("\"responsive\":true", html(p))

        Preset.PlotContainer.iframe!()
        @test occursin("iframe", html(p))
    end
end

#-----------------------------------------------------------------------------# Aqua
Aqua.test_all(PlotlyLight)
