"""
$(SIGNATURES)

Move node at `index` to `new_location`.
"""
@propagate_inbounds function assign(sa_struct::SAStruct, index, new_location)
    node = sa_struct.nodes[index]
    # Assign this location to the new node.
    assign(node, new_location)
    # Update the grid to point to the node.
    return sa_struct.grid[location(node)] = index
end

@propagate_inbounds function unsafe_assign(sa_struct::SAStruct, node::SANode, new_location)
    return assign(node, new_location)
end

"""
$(SIGNATURES)

Move node at `index` from its current location to `new_location`.
"""
@propagate_inbounds function move(sa_struct::SAStruct, index, new_location)
    node = sa_struct.nodes[index]
    # Zero out this node's original location in the grid, then assign the new
    # location.
    sa_struct.grid[location(node)] = 0
    sa_struct.grid[new_location] = index
    return unsafe_assign(sa_struct, node, new_location)
end

"""
$(SIGNATURES)

Swap the locations of two nodes with indices `node1_idx` and `node2_idx`.
"""
@propagate_inbounds function swap(sa_struct::SAStruct, node1_idx, node2_idx)
    # Get references to these objects to make life easier.
    n1 = sa_struct.nodes[node1_idx]
    n2 = sa_struct.nodes[node2_idx]
    # Swap address/component assignments
    s = location(n1)
    t = location(n2)

    unsafe_assign(sa_struct, n1, t)
    unsafe_assign(sa_struct, n2, s)

    # Swap grid.
    sa_struct.grid[t] = node1_idx
    sa_struct.grid[s] = node2_idx

    return nothing
end

################################################################################
# DEFAULT METRIC FUNCTIONS
################################################################################
#=
Right now, this first function is basically a dispatch method to handle the
case when we have multiple channel types.

Ideas include:

1. Allow type dispatch to do everything.
2. Make this a "generated" function based on all the types of the channels and
    build a "case" statement out of it.
=#
@propagate_inbounds function channel_cost(sa_struct::SAStruct, idx::Int)
    return channel_cost(sa_struct, sa_struct.channels[idx])
end

"""
    channel_cost(sa_struct{T}, channel :: SAChannel) where {T <: RuleSet}

Return the cost of `channel`. Default implementation accumulates the distances
between the source and sink addresses of the channel using `sa_struct.distance`.

Method List
-----------
$(METHODLIST)
"""
@propagate_inbounds function channel_cost(sa_struct::SAStruct, channel::TwoChannel)
    a = sa_struct.nodes[channel.source]
    b = sa_struct.nodes[channel.sink]
    return Float64(getdistance(sa_struct.distance, a, b))
end

@propagate_inbounds function channel_cost(sa_struct::SAStruct, channel::MultiChannel)
    cost = 0.0
    for src in channel.sources, snk in channel.sinks
        a = sa_struct.nodes[src]
        b = sa_struct.nodes[snk]
        cost += getdistance(sa_struct.distance, a, b)
    end
    return cost
end

"""
    address_cost(sa_struct{T}, node :: SANode, address_data::AddressData) where {T <: RuleSet}

Return the address cost for `node` for RuleSet `T`. Default return value
is `zero(Float64)`.

Called by default during [`node_cost`](@ref) and [`node_pair_cost`](@ref)

Method List
-----------
$(METHODLIST)
"""
address_cost(sa_struct::SAStruct, node::SANode, address_data::AddressData) = zero(Float64)
function address_cost(sa_struct::SAStruct, node::SANode, address_data::DefaultAddressData)
    return address_data[getlocation(node)]
end

# Convenience wrapper.
function address_cost(sa_struct::SAStruct, node::SANode)
    return address_cost(sa_struct, node, sa_struct.address_data)
end

"""
    aux_cost(sa_struct{T}) where {T <: RuleSet}

Return an auxiliary cost associated with the entire mapping of the `sa_struct`.
May use any field of `sa_struct` but may only mutate `sa_struct.aux`.

Default: `zero(Float64)`

Method List
-----------
$(METHODLIST)
"""
aux_cost(sa_struct::SAStruct) = zero(Float64)

function map_cost(sa_struct::SAStruct)
    cost = aux_cost(sa_struct)
    for i in eachindex(sa_struct.channels)
        cost += channel_cost(sa_struct, i)
    end
    for n in sa_struct.nodes
        cost += address_cost(sa_struct, n)
    end
    return cost
end

"""
    node_cost(sa_struct{T}, idx) where {T <: RuleSet}

Return the cost of the node with index `idx` in ruleset `T`.

Default implementation sums the node's:
* incoming channels
* outgoing channels
* address cost
* auxiliary cost.

Method List
-----------
$(METHODLIST)
"""
@propagate_inbounds function node_cost(sa_struct::SAStruct, idx::Integer)
    # Unpack node data type.
    n = sa_struct.nodes[idx]
    cost = aux_cost(sa_struct)
    for channel in n.outchannels
        cost += channel_cost(sa_struct, channel)
    end
    for channel in n.inchannels
        cost += channel_cost(sa_struct, channel)
    end
    cost += address_cost(sa_struct, n)

    return cost
end

#=
Node pair cost is slightly more subtle than just each independent node cost if

    1. The communication resources in the array are asymmetric. Then if two
        nodes are swapped and are connected by a channel, the double cost of
        that channel is not cancelled out correctly.

    2. For multi-pin nets, if a source and sink are swapped, then the the
        objective function is calculated incorrectly due to counting the channel
        twice.
=#
"""
    node_pair_cost(sa_struct{T}, idx1, idx2) where {T <: RuleSet}

Compute the cost of the pair of nodes with indices `idx1` and `idx2`. Call this
function when computing the cost of two nodes because in general, the total
cost of two nodes is not the sum of the individual nodes' costs.

Method List
-----------
$(METHODLIST)
"""
@propagate_inbounds function node_pair_cost(sa_struct::SAStruct, idx1, idx2)
    cost = node_cost(sa_struct, idx1)
    # Get the two node types for calculating the cost of the second node.
    a = sa_struct.nodes[idx1]
    b = sa_struct.nodes[idx2]

    for channel in b.outchannels
        if !in(channel, a.inchannels)
            cost += channel_cost(sa_struct, channel)
        end
    end
    for channel in b.inchannels
        if !in(channel, a.outchannels)
            cost += channel_cost(sa_struct, channel)
        end
    end
    cost += address_cost(sa_struct, b)
    return cost
end
