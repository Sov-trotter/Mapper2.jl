export  TaskgraphNode,
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
        in_edges,
        hasnode,
        out_nodes


"""
    struct TaskgraphNode

Simple container representing a node in a taskgraph. Miscellaneous data should
be stored in the `metadata` field.

# Fields:
* `name::String` - The name of the task.
* `metadata::Dict{String,Any}` - Flexible container for storing any additional
    information with the type to build datastructure down stream.

# Constructor
    TaskgraphNode(name, metadata = Dict{String,Any}())

"""
struct TaskgraphNode
    name    ::String
    metadata::Dict{String,Any}
    # Constructor
    TaskgraphNode(name, metadata = Dict{String,Any}()) = new(name, metadata)
end

"""
    struct TaskgraphEdge

Simple container representing an edge in a taskgraph. Miscellaneous data should
be stored in the `metadatea` field.

# Fields
* `sources::Vector{String}` - Names of `TaskgraphNodes`s that are sources for
    this edge.
* `sinks::Vector{String}` - Names of `TaskgraphNode`s that are destinations
    for this edge.
* `metadata::Dict{String,Any}` - Flexible container for storing any additional
    information with the type to build datastructure down stream.

# Constructor
    TaskgraphEdge(source, sink, metadata = Dict{String,Any}())

Arguments `source` and `sink` may either be of type `String` or `Vector{String}`.
"""
struct TaskgraphEdge
    sources ::Vector{String}
    sinks   ::Vector{String}
    metadata::Dict{String,Any}

    function TaskgraphEdge(source, sink, metadata = Dict{String,Any}())
        sources = typeof(source)   <: Vector ? source : [source]
        sinks   = typeof(sink)     <: Vector ? sink   : [sink]
        return new(sources, sinks, metadata)
    end
end

"Return the names of sources of a `TaskgraphEdge`."
getsources(t::TaskgraphEdge) = t.sources
"Return the names of sinks of a `TaskgraphEdge`."
getsinks(t::TaskgraphEdge)   = t.sinks

"""
    struct Taskgraph

Data structure encoding tasks and their relationships.

# Fields
* `name::String` - The name of the taskgraph.
* `nodes::Dict{String, TaskgraphNode}` - Tasks within the taskgraph. Keys are
    the instance names of the node, value is the data structure.
* `edges::Vector{TaskgraphEdge}` - Collection of edges between `TaskgraphNode`s.
* `adjacency_out::Dict{String,Vector{TaskgraphEdge}}` - Fast adjacency lookup.
    Given a task name, returns a collection of `TaskgraphEdge` that have the
    corresponding task as a source.
* `adjacency_in::Dict{String,Vector{TaskgraphEdge}}` - Fast adjacency lookup.
    Given a task name, returns a collection of `TaskgraphEdge` that have the
    corresponding task as a sink.

# Constructor
    Taskgraph(name, node_container, edge_container)

Return a `TaskGraph` with the given name, nodes, and edges. Arguments
`node_container` and `edge_container` must have elements of type
`TaskgraphEdge` and `TaskgraphNode` respectively.
"""
struct Taskgraph
    name            ::String
    nodes           ::Dict{String, TaskgraphNode}
    edges           ::Vector{TaskgraphEdge}
    adjacency_out   ::Dict{String, Vector{TaskgraphEdge}}
    adjacency_in    ::Dict{String, Vector{TaskgraphEdge}}

    function Taskgraph(name, node_container, edge_container)
        if eltype(node_container) != TaskgraphNode
            typer = TypeError(
                  :Taskgraph,
                  "Incorrect Node Element Type",
                  TaskgraphNode,
                  eltype(node_container))

            throw(typer)
        end
        if eltype(edge_container) != TaskgraphEdge
            typer = TypeError(
                  :Taskgraph,
                  "Incorrect Edge Element Type",
                  TaskgraphEdge,
                  eltype(edge_container))

            throw(typer)
        end
        # First - create the dictionary to store the nodes. Nodes can be
        # accessed via their name.
        nodes = Dict(n.name => n for n in node_container)
        # Initialize the adjacency lists with an entry for each node. Initialize
        # the values to empty arrays of edges so down-stream algortihms won't
        # have to check if an adjacency list exists for a node.
        edges = collect(edge_container)
        adjacency_out = Dict(name => TaskgraphEdge[] for name in keys(nodes))
        adjacency_in  = Dict(name => TaskgraphEdge[] for name in keys(nodes))
        # Iterate through all edges - grow adjacency lists correctly.
        for edge in edges
            for source in edge.sources
                push!(adjacency_out[source], edge)
            end
            for sink in edge.sinks
                push!(adjacency_in[sink], edge)
            end
        end
        # Return the data structure
        return new(
            name,
            nodes,
            edges,
            adjacency_out,
            adjacency_in,
        )
    end
end

################################################################################
# METHODS FOR THE TASKGRAPH
################################################################################
# -- Some accessor methods.
getnodes(tg::Taskgraph) = values(tg.nodes)
getedges(tg::Taskgraph) = tg.edges
getnode(tg::Taskgraph, node::String) = tg.nodes[node]
getedge(tg::Taskgraph, i::Integer) = tg.edges[i]

# -- helpful query methods.
nodenames(t::Taskgraph) = keys(t.nodes)
num_nodes(t::Taskgraph) = length(getnodes(t))
num_edges(t::Taskgraph) = length(getedges(t))

"""
    add_node(t::Taskgraph, task::TaskgraphNode)

Add a new node to `t`. Error if node already exists.
"""
function add_node(t::Taskgraph, task::TaskgraphNode)
    if haskey(t.nodes, task.name)
        error("Task $(task.name) already exists in taskgraph.")
    end
    t.nodes[task.name] = task
    # Create adjacency list entries for the new nodes
    t.adjacency_out[task.name] = TaskgraphEdge[]
    t.adjacency_in[task.name]  = TaskgraphEdge[]
    return nothing
end

"""
    add_edge(t::Taskgraph, edge::TaskgraphEdge)

Add a new edge to `t`.
"""
function add_edge(t::Taskgraph, edge::TaskgraphEdge)
    # Update the edge array
    push!(t.edges, edge)
    # Update the adjacency lists.
    for source in edge.sources
        push!(t.adjacency_out[source], edge)
    end
    for sink in edge.sinks
        push!(t.adjacency_in[sink], edge)
    end
    return nothing
end


# Methods for accessing the adjacency lists
out_edges(tg::Taskgraph, task::String) = tg.adjacency_out[task]
out_edges(tg::Taskgraph, task::TaskgraphNode) = out_edges(tg, task.name)

in_edges(tg::Taskgraph, task::String) = tg.adjacency_in[task]
in_edges(tg::Taskgraph, task::TaskgraphNode) = in_edges(tg, task.name)

hasnode(tg::Taskgraph, node::String) = haskey(tg.nodes, node)

@doc """
    out_edges(t::Taskgraph, task::Union{String,TaskgraphNode})

Return `Vector{TaskgraphEdge}` for which `task` is a source."
""" out_edges

@doc """
    in_edges(t::Taskgraph, task::Union{String,TaskgraphNode})

Return `Vector{TaskgraphEdge}` for which `task` is a sink.
""" in_edges

@doc """
    hasnode(t::Taskgraph, node::String)

Return `true` if `t` has a task named `node`.
""" hasnode

"""
    out_nodes(t::Taskgraph, node)

Return a collection of nodes from `t` for which are the sink of an edge starting
at `node`.
"""
function out_nodes(t::Taskgraph, node)
    # Check for empty adjacency lists
    if length(out_edges(t, node)) == 0
        return TaskgraphNode[]
    end

    # Sink node iterators
    sink_name_iters = (e.sinks for e in out_edges(t, node))
    # Flatten the sink iterators and get the distinct results.
    distinct_sink_names = distinct(Base.Iterators.flatten(sink_name_iters))
    # Finally, pipe this into a generator to return the actual node object.
    nodes = (getnode(t, n) for n in distinct_sink_names)
    return nodes
end
