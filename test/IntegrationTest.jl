@testset "Testing Whole Flow" begin
    using Example
    local m
    passed = true 
    try
        m = make_map()
        m = place(m, move_attempts = 5000)
        m = route(m)
    catch
        passed = false
    end
    @test passed

    # Get statistics from the map
    MapType.report_routing_stats(m)
end