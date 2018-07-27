"""
    Architecture

Abstract supertype for controlling dispatch to specialized functions for
architecture interpretation. Create a custom concrete subtype of this if you
want to use custom methods during placement or routing.
"""
abstract type Architecture end

"""
Enum for indicating driver directions.
"""
@enum Direction Source Sink

################################################################################
#                                  PORT TYPES                                  #
################################################################################

"""
Classification of port types.
"""
@enum PortClass Input Output

struct Port
    name        ::String

    """
    The class of this port. Must be a [`PortClass`](@ref)
    """
    class       ::PortClass
    metadata    ::Dict{String,Any}

    Port(name, class::PortClass; metadata = emptymeta()) = new(name, class, metadata)
end

const _port_compat = Dict(
    Source => (Input,),
    Sink => (Output,),
)

const _port_inverses = Dict(
    Input => Output,
    Output => Input,
)

"""
$(SIGNATURES)

Return `true` if `port` is the correct class for the given [`Direction`](@ref)
"""
checkclass(port::Port, direction::Direction) = port.class in _port_compat[direction]

"""
$(SIGNATURES)

Return a version of `port` with the class inverted.
"""
invert(port::Port) = Port(port.name, _port_inverses[port.class]; metadata = port.metadata)

############
# Port Doc #
############
@doc """
Port type for modeling input/output ports of a `Component`.

API
---
* [`checkclass`](@ref)
* [`invert`](@ref)
""" Port

################################################################################
#                                  LINK TYPE                                   #
################################################################################

struct Link
    name :: String
    sources :: Vector{Path{Port}}
    dests :: Vector{Path{Port}}
    metadata :: Dict{String,Any}

    function Link(name, srcs::T, dsts::T, metadata) where T <: Vector{Path{Port}}
        return new(name,srcs,dsts,Dict{String,Any}(metadata))
    end
end

"""
$(SIGNATURES)

Return [`Vector{Path{Port}}`](@ref Path) of sources for `link`.
"""
sources(link::Link) = link.sources

"""
$(SIGNATURES)

Return [`Vector{Path{Port}}`](@ref Path) of destinations for `link`.
"""
dests(link::Link)   = link.dests

############
# Link Doc #
############
@doc """
    struct Link{P <: AbstractComponentPath}

Link data type for describing which ports are connected. Can have multiple
sources and multiple sinks.

API
---
* [`sources`](@ref)
* [`dests`](@ref)
""" Link

################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
abstract type AbstractComponent end

"Return an iterator for the children within a component."
children(c::AbstractComponent) = values(c.children)
childnames(component::AbstractComponent) = keys(component.children)
"Return an iterator for links within the component."
links(c::AbstractComponent) = values(c.links)

#-------------------------------------------------------------------------------
# Component
#-------------------------------------------------------------------------------
struct Component <: AbstractComponent
    name :: String
    primitive :: String
    children :: Dict{String, Component}
    ports :: Dict{String, Port}
    links :: Dict{String, Link}
    portlink :: Dict{Path{Port}, Link}
    metadata :: Dict{String, Any}
end

function Component(
        name;
        primitive   ::String = "",
        metadata = Dict{String, Any}(),
    )
    # Add all component level ports to the ports of this component.
    children    = Dict{String, Component}()
    ports       = Dict{String, Port}()
    links       = Dict{String, Link}()
    portlink    = Dict{Path{Port}, String}()
    # Return the newly constructed type.
    return Component(
        name,
        primitive,
        children,
        ports,
        links,
        portlink,
        metadata,
    )
end

# Promote types for paths
path_promote(::Type{Component}, ::Type{T}) where T <: Union{Port,Link} = T
path_demote(::Type{T}) where T <: Union{Component,Port,Link} = Component

# String macros for constructing port and link paths.
macro component_str(s) :(Path{Component}($s)) end
macro link_str(s) :(Path{Link}($s)) end
macro port_str(s) :(Path{Port}($s)) end

function get_relative_port(c::AbstractComponent, p::Path{Port})
    # If the port is defined in the component, just return the port itself
    if length(p) == 1
        return c[p]
    # If the port is defined one level down in the component hierarchy,
    # extract the port from the level and "invert" it so the directionality
    # of the port is relative to the component "c"
    elseif length(p) == 2
        return invert(c[p])
    else
        error("Invalid relative port path $p for component $(c.name)")
    end
end

@doc """
    Component

Basic building block of architecture models. Can be used to construct
hierarchical models.

Components may be indexed using: `ComponentPath`, `PortPath{ComponentPath}`,
and `LinkPath{ComponentPath}`.
""" Component

#-------------------------------------------------------------------------------
ports(c::Component) = values(c.ports)
ports(c::Component, classes) = Iterators.filter(x -> x.class in classes, values(c.ports))

portnames(c::Component) = collect(keys(c.ports))
function portnames(c::Component, classes)
    return [k for (k,v) in c.ports if v.class in classes]
end

connected_ports(a::AbstractComponent) = collect(keys(a.portlink))

@doc """
    ports(c::Component, [classes])

Return an iterator for all the ports of the given component. Ports of children
are not given. If `classes` are provided, only ports matching the specified
classes will be returned.
""" ports

#-------------------------------------------------------------------------------
# TopLevel
#-------------------------------------------------------------------------------
struct TopLevel{A <: Architecture,D} <: AbstractComponent
    name :: String
    children :: Dict{String, Component}
    child_to_address :: Dict{String, Address{D}}
    address_to_child :: Dict{Address{D}, String} 
    links :: Dict{String, Link}
    portlink :: Dict{Path{Port}, Link}
    metadata :: Dict{String, Any}

    # --Constructor
    function TopLevel{A,D}(name, metadata = Dict{String,Any}()) where {A,D}
        links           = Dict{String, Link}()
        portlink        = Dict{Path{Port}, Link}()
        children        = Dict{String, Component}()
        child_to_address = Dict{String, Address{D}}()
        address_to_child = Dict{Address{D}, String}()

        return new{A,D}(
            name, 
            children, 
            child_to_address,
            address_to_child,
            links, 
            portlink, 
            metadata
        )
    end
end

################################################################################
# Convenience methods.
################################################################################

isgloballink(p::Path{Link}) = length(p) == 1
isgloballink(p::Path) = false

isglobalport(p::Path{Port}) = length(p) == 2
isglobalport(p::Path) = false

Base.string(::Type{Component})  = "Component"
Base.string(::Type{Port})       = "Port"
Base.string(::Type{Link})       = "Link"

"""
    addresses(t::TopLevel)

Return an iterator of all addresses with subcomponents of `t`.
"""
addresses(t::TopLevel) = keys(t.address_to_child)
Base.isassigned(t::TopLevel, a::Address) = haskey(t.address_to_child, a)

getaddress(t::TopLevel, p::Path) = getaddress(t, first(p))
getaddress(t::TopLevel, s::String) = t.child_to_address[s]
hasaddress(t::TopLevel, p::Path) = hasaddress(t, first(p))
hasaddress(t::TopLevel, s::String) = haskey(t.child_to_address, s)

getchild(t::TopLevel, a::Address) = t.children[t.address_to_child[a]]
getname(t::TopLevel, a::Address) = t.address_to_child[a]
function Base.size(t::TopLevel{A,D}) where {A,D} 
    return dim_max(addresses(t)) .- dim_min(addresses(t)) .+ Tuple(1 for _ in 1:D)
end

#-------------------------------------------------------------------------------
# Various overloadings of the method "getindex"
#-------------------------------------------------------------------------------

function Base.getindex(c::AbstractComponent, p::Path{T}) where T <: Union{Port,Link}
    length(p) == 0 && error("Paths to Ports and Links must have non-zero length")

    c = descend(c, p.steps, length(p)-1)
    return gettarget(c, T, last(p))
end

Base.getindex(c::AbstractComponent, p::Path{Component}) = descend(c, p.steps, length(p))
Base.getindex(c::AbstractComponent, s::Address) = c.children[c.address_to_child[s]]
function descend(c::AbstractComponent, steps::Vector{String}, n::Integer)
    for i in 1:n
        c = c.children[steps[i]]
    end
    return c
end

gettarget(c::Component, ::Type{Port}, target) = c.ports[target]
gettarget(c::AbstractComponent, ::Type{Link}, target) = c.links[target]


@doc """
    getindex(component, path::Path{T})::T where T <: Union{Port,Link,Component}

Return the architecture type referenced by `path`. Error horribly if `path` does
not exist.

    getindex(toplevel, address)::Component

Return the top level component of `toplevel` at `address`.
""" getindex

################################################################################

"""
    walk_children(c::Component)

Return `Vector{ComponentPath}` enumerating paths to all the children of `c`.
Paths are returned relative to `c`.
"""
function walk_children(component::AbstractComponent)
    # This is performed as a BFS walk through the sub-component hierarchy of c.
    components = [Path{Component}()]
    queue = [Path{Component}(id) for id in keys(component.children)]
    while !isempty(queue)
        path = popfirst!(queue)
        push!(components, path)
        # Need to push child the child name to the component path to get the
        # component path relative to component
        this_component = component[path]
        newpaths = [catpath(path, Path{Component}(child)) for child in childnames(this_component)]
        append!(queue, newpaths)
    end
    return components
end

function walk_children(tl::TopLevel, a::Address)
    # Walk the component at this address
    paths = walk_children(tl[a])
    component_path = tl.address_to_child[a]
    # Append the first part of the component path to each of the sub paths.
    return catpath.(Ref(Path{Component}(component_path)), paths)
end

function connected_components(tl::TopLevel{A,D}) where {A,D}
    # Construct the associative for the connected components.
    cc = Dict{Address{D}, Set{Address{D}}}()
    # Iterate through all links - record adjacency information
    for link in links(tl)
        for source_port in sources(link), sink_port in dests(link)
            src_address = getaddress(tl, source_port)
            snk_address = getaddress(tl, sink_port)

            push_to_dict(cc, src_address, snk_address)
        end
    end
    # Default unseen addresses to an empty set of addresses.
    for address in addresses(tl)
        if !haskey(cc, address)
            cc[address] = Set{Address{D}}()
        end
    end
    return cc
end

################################################################################
# METHODS FOR NAVIGATING THE HIERARCHY
################################################################################
function search_metadata(c::AbstractComponent, key, value, f::Function = ==)::Bool
    return haskey(c.metadata, key) ? f(value, c.metadata[key]) : false
end
search_metadata(c::AbstractComponent, key) = haskey(c.metadata, key)

function search_metadata!(c::AbstractComponent, key, value, f::Function = ==)
    # check top component
    search_metadata(c, key, value, f) && return true
    # recursively call search_metadata! on all subcomponents
    for child in values(c.children)
        search_metadata!(child, key, value, f) && return true
    end
    return false
end

function get_metadata!(c::AbstractComponent, key)
    if haskey(c.metadata, key)
        return c.metadata[key]
    end

    for child in values(c.children)
        val = get_metadata!(child, key)
        if val != nothing
            return val
        end
    end

    return nothing
end

################################################################################
# ASSERTION METHODS.
################################################################################

function assert_no_children(c::AbstractComponent)
    passed = true
    if length(c.children) != 0
        passed = false
        @error "Cmponent $(c.name) is not expected to have any children."
    end
    return passed
end

assert_no_intrarouting(c::AbstractComponent) = length(c.links) == 0
isfree(c::AbstractComponent, p::Path{Port}) = !haskey(c.portlink, p)

################################################################################
# Documentation for TopLevel
################################################################################
@doc """
    TopLevel{A <: Architecture, D}

Top level component for an architecture mode. Main difference is between a
`TopLevel` and a `Component` is that children of a `TopLevel` are accessed
via address instead of instance name. A `TopLevel` also does not have any
ports of its own.

Parameter `D` is the dimensionality of the `TopLevel`.

A `TopLevel{A,D}` may be indexed using: 
[`AddressPath{D}`](@ref AddressPath),
[`PortPath{AddressPath{D}}`](@ref PortPath), and 
[`LinkPath{AddressPath{D}}`](@ref LinkPath).

# Constructor
    TopLevel{A,D}(name, metadata = Dict{String,Any}()) where {A <: Architecture,D}

Return an empty `TopLevel` with the given name and `metadata`.

# Constructor functions
The following functions may be used to add subcomponents and connect 
subcomponents together:


# Analysis routines for TopLevel


# Fields
* `name::String` - The name of the TopLevel.
* `children::Dict{CartesinIndex{D},Component}` - Record of the subcomponents accessed
    by address.
* `links::Dict{String,Link{AddressPath{D}}}` - Record of links between ports of
    immediate children.
* `port_link::Dict{PortPath{AddressPath{D}},String}` - Look up giving the `Link`
    in the `links` field connected to the provided port.
* `metadata::Dict{String,Any}()` - Any extra data associated with the
    data structure.
""" TopLevel

@doc """
    connected_components(tl::TopLevel{A,D})

Return `d = Dict{Address{D},Set{Address{D}}` where key `k` is a 
valid address of `tl` and where `d[k]` is the set of valid addresses of `tl` 
whose components are the destinations of links originating at address `k`.
""" connected_components

@doc """
    search_metadata(c::AbstractComponent, key, value, f::Function = ==)

Search the metadata of field of `c` for `key`. If `c.metadata[key]` does not
exist, return `false`. Otherwise, return `f(value, c.metadata[key])`.

If `isempty(key) == true`, will return `true` regardless of `value` and `f`.
""" search_metadata

@doc """
    search_metadata!(c::AbstractComponent, key, value, f::Function = ==)

Call `search_metadata` on each subcomponent of `c`. Return `true` if function
call return `true` for any subcomponent.
""" search_metadata!

# Assertion Methods
@doc """
    assert_no_children(c::AbstractComponent)

Return `true` if `c` has no children. Otherwise, return `false` and log an
error.
""" assert_no_children

@doc """
    assert_no_intrarouting(c::AbstractComponent)

Return `true` if `c` has not internal links. Otherwise, return `false` and
log an error.
""" assert_no_intrarouting

@doc """
    isfree(c::AbstractComponent, p::PortPath)

Return `true` if portpath `p` is assigned a link in component `c`.
""" isfree
