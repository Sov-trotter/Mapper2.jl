module Example1

using Mapper2

# Export many functions for testing
export build_input_primitive,
    build_output_primitive,
    build_general_primitive,
    build_io_tile,
    build_general_tile,
    build_super_tile,
    build_double_general_tile,
    build_routing_tile,
    build_test_arch,
    # Taskgraph
    make_taskgraph,
    make_nodes,
    make_edges,
    # Map
    make_map,
    make_fanout

# Extensions of the base Mapper types
struct TestRuleSet <: RuleSet end

make_map() = Map(TestRuleSet(), build_test_arch(), make_taskgraph())
make_fanout() = Map(TestRuleSet(), build_test_arch(), make_fanout_taskgraph())

include("Architecture.jl")
include("Taskgraph.jl")
include("Placement.jl")
include("Routing.jl")

end
