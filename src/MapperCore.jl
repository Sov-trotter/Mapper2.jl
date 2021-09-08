module MapperCore

using ..Mapper2.Helper
Helper.@SetupDocStringTemplates

using ..Mapper2.MapperGraphs

using IterTools
using DataStructures

using Logging
using Serialization

"""
    RuleSet

Abstract supertype for controlling dispatch to specialized functions for
architecture interpretation. Create a custom concrete subtype of this if you
want to use custom methods during placement or routing.
"""
abstract type RuleSet end

struct DefaultRuleSet <: RuleSet end

include("Taskgraphs.jl")

# Architecture includes
include("Architecture/Paths.jl")
include("Architecture/Architecture.jl")
include("Architecture/Methods.jl")
include("Architecture/Constructors.jl")

# Map Includes
include("Map/Map.jl")
include("Map/Verification.jl")
include("Map/Inspection.jl")

#-------------------------------------------------------------------------------
# Mapping methods
#-------------------------------------------------------------------------------

const TN = TaskgraphNode
const TE = TaskgraphEdge
const PLC = Union{Port,Link,Component}

# Placement Queries
"""
    isequivalent(ruleset::RuleSet, a::TaskgraphNode, b::TaskgraphNode) :: Bool

Return `true` if `TaskgraphNodes` `a` and `b` are semantically equivalent for
placement.

Default: `true`
"""
isequivalent(::RuleSet, a::TN, b::TN) = true

"""
    ismappable(ruleset::RuleSet, component::Component) :: Bool

Return `true` if some task can be mapped to `component` under `ruleset`.

Default: `true`
"""
ismappable(::RuleSet, c::Component) = true

"""
    canmap(ruleset::RuleSet, t::TaskgraphNode, c::Component) :: Bool

Return `true` if `t` can be mapped to `c` under `ruleset`.

Default: `true`
"""
canmap(::RuleSet, t::TN, c::Component) = true

# Routing Queries

"""
    canuse(ruleset::RuleSet, item::Union{Port,Link,Component}, edge::TaskgraphEdge)::Bool

Return `true` if `edge` can use `item` as a routing resource under `ruleset`.

Default: `true`
"""
canuse(::RuleSet, item::PLC, edge::TE) = true

"""
    getcapacity(ruleset::RuleSet, item::Union{Port,Link,Component})

Return the capacity of routing resource `item` under `ruleset`.

Default: `1`
"""
getcapacity(::RuleSet, item) = 1

"""
    is_source_port(ruleset::RuleSet, port::Port, edge::TaskgraphEdge)::Bool

Return `true` if `port` is a valid source port for `edge` under `ruleset`.

Default: `true`
"""
is_source_port(::RuleSet, port::Port, edge::TE) = true

"""
    is_sink_port(ruleset::RuleSet, port::Port, edge::TaskgraphEdge)::Bool

Return `true` if `port` is a vlid sink port for `edge` under `ruleset`.

Default: `true`
"""
is_sink_port(::RuleSet, port::Port, edge::TE) = true

"""
    needsrouting(ruleset::RuleSet, edge::TaskgraphEdge)::Bool

Return `true` if `edge` needs to be routed under `ruleset`.

Default: `true`
"""
needsrouting(::RuleSet, edge::TE) = true

#-------------------------------------------------------------------------------
# Exports
#-------------------------------------------------------------------------------

export isequivalent,
    ismappable, canmap, canuse, is_sink_port, is_source_port, getcapacity, needsrouting

### Taskgraph Exports###

export TaskgraphNode,
    TaskgraphEdge,
    Taskgraph,
    # Methods
    getsources,
    getsinks,
    getnodes,
    getedges,
    getnode,
    getedge,
    nodenames,
    num_nodes,
    num_edges,
    add_node,
    add_edge,
    out_edges,
    out_edge_indices,
    in_edges,
    in_edge_indices,
    hasnode,
    outnode_names,
    innode_names,
    out_nodes,
    in_nodes,

    ### Architecture Exports ###
    # Path Types
    AbstractPath,
    Path,
    AddressPath,
    catpath,
    striplast,
    splitpath,
    stripfirst,

    # Architecture stuff
    Port,
    Link,
    # Port Methods
    Input,
    Output,
    invert,
    # Link Methods
    isaddresslink,
    sources,
    dests,
    # Components
    AbstractComponent,
    TopLevel,
    Component,
    isaddress,
    @port_str,
    @link_str,
    @component_str,
    # Verification
    check_routing,
    # Methods
    getoffset,
    checkclass,
    ports,
    portpaths,
    addresses,
    pathtype,
    children,
    walk_children,
    connected_components,
    search_metadata,
    search_metadata!,
    get_metadata!,
    check_connectivity,
    get_connected_port,
    isfree,
    isgloballink,
    isglobalport,
    getaddress,
    hasaddress,
    getchild,
    getname,
    mappables,
    # Asserts
    assert_no_children,
    assert_no_intrarouting,
    # Constructor Types
    OffsetRule,
    PortRule,
    # Constructor Functions
    add_port,
    add_child,
    add_link,
    connection_rule,
    build_mux,
    check,
    ConnectionRule,
    Offset,
    # Analysis methods
    build_distance,
    build_component_table,

    ### Map ###
    RuleSet,
    Mapping,
    Map,
    NodeMap,
    EdgeMap,
    rules,
    save,
    load,
    getpath
end
