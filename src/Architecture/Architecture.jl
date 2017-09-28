#=
Authors:
    Mark Hildebrand

This defines the basic architecture data types and methods that define an
architecture model. We define a master class "AbstractComponent". From that,
we define concrete "Components".

STRUCTURE

These components will represent functional units of an architecture. For example,
in the case of KiloCore, these could represent the actual processors, routing
muxes, packet routers etc. Components will be hierarchical. Each component
will keep track of its children, and its parent. One constraint is that
all child components must be the same concrete sub-type of AbstractComponent
in order to satisfy Julia's requirement of type stability.

METADATA

Each component will have a meta-data dictionary that will accept string keys
and return the corresponding component. This will allow storage of things
like attributes supplied (as an array of strings), or the number of writes
done by a processor etc.

NOTE: Initially, this will be a
dictionary of type Dict{String, Any}. This is a bit dangerous because of the
type ambiguity, but hopefully this will not have to be referenced that often,
of it it does have to be referenced often will be accelerated externally. If
this causes performance problems in the future, we'll have to revisit it and
see if we can bring performance up.

PRIMITIVE IDENTIFIERS

Further, each component will a string identifier to its primitive type. (If
a primitive type is undeclared, a null string will be used). For example,
primitives like multiplexors will have special methods for building a routing
graph and dumping configuration information post-routing.

COMPONENT NAMES

Each component will also have a name (if no name is supplied, a default will
be supplied). Names of sub-components will be recorded by a parent. Sub
conponents can be accesses using "dot" notation. For example, if the top
level is "arch", it has a sub componend "tile1" which has a sub component
"mux0", the component "mux0" can be accessed from the parent using the
string "arch.tile1.mux0".

PORTS

Components will also have ports which can be connected using links.
Ports will have adjacency lists to record the other ports to which they
are connected. For simplicity, ports may only be connected to other ports
at the same level of hierarchy. Otherwise, it would be way too complicated
to keep track of everything.

Complementary dictionaries in each port will record information about the link,
such as the capacity, cost, and other metrics that people may find relevant
to include with the link.

TOPLEVEL

The top level will be an TopLevel component, which will still behave
like a normal component, but also have the ability to assign addresses
to sub components and will be used as the top level architecture

--------------------------------------------------------------------------------
NOTATION
--------------------------------------------------------------------------------
Some accessor functions will have two versions, one that is called only on the
present Component, and one that will be recursively called on the component
and each sub-component. In these cases, the function that works recusrively
will end in an exclamation point "!".
=#


################################################################################
#                                  PORT TYPES                                  #
################################################################################

# Master abstract type - probably not needed.
abstract type AbstractPort end

# Must make the port mutable so we can progressively assign links.
mutable struct Port
    """The name of the port."""
    name        ::String
    """
    The class of the port. Can be "input", "output", "bidir".
    More can be added if needed.
    """
    class       ::String
    """
    Neighbor List.
    """
    neighbors   ::Array{String,1}
    """
    Metadata list - associated with characteristics of the link. Can include
    attributes like "capacity", "network" etc.
    """
    metadata    ::Array{Any,1}
end

"""
    Port(name::String)

Create a new port with the given `name`.
"""
function Port(name::String, class::String)
    # Make sure this is a valid port class.
    @assert class in PORT_CLASSES
    # Create a port without any notion of connection.
    neighbors = String[]
    metadata  = Any[]
    return Port(
        name,
        class,
        neighbors,
        metadata,
)
end
#=
Collect all valid port class strings here.
=#
const PORT_CLASSES = Set([
    "input",
    "output",
    "bidir",
 ])
#=
Valid port classes that can serve as the source of a connection. Do this to
help assure consistency of generated architectures.
=#
const PORT_SOURCES = Set([
    "input",
    "bidir",
 ])
const PORT_SINKS = Set([
    "output",
    "bidir",
 ])

# Various convenience methods for ports.

# We simply need to look for a "." in the name. If it exists, then the port
# belongs to a child. Otherwise, it is a toplevel component.
"""
    is_top_port(p::Port)

Return `true` if port `p` is the top level port of a component and does not
belong to a child of that component.
"""
is_top_port(p::Port) = !contains(p.name, ".")

"""
    flipdir(p::Port)

Flip the direction of a port. Useful for converting a port from a component level
port to a child level port. In these instances, the directionality of a port
will filp.
"""
function flipdir(p::Port)
    class = p.class
    # If the class of the port is input or output, return the opposite of that.
    # If the port if bidirectional, nothing needs to be done.
    class_dict = Dict(
        "bidir" => "bidir",
        "input" => "output",
        "output" => "input",
     )
    if !haskey(class_dict, class)
        error("Port class: ", class, " not defined.")
    end
    return class_dict[class]
end
################################################################################
#                               COMPONENT TYPES                                #
################################################################################

# Master abstract type from which all component types will subtype
abstract type AbstractComponent end

#=
When creating components from the ground up, we might not know the type of
the parent immediately. An OrphanComponent will be used to build up a component
until the type of its parent is known. Then, a component can be created
from the orphan component and the parent.
=#
mutable struct Component <: AbstractComponent
    """The declared name of this component"""
    name    ::String
    """Reference to primitive for special operations. Default is \"\"."""
    primitive::String
    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{String, Component}
    ports   ::Dict{String, Port}
    metadata::Dict{String, Any}

    # Constructor
    """
        Component(name, children = Dict{String, Component}(), metadata = Dict{String, Any}())

    Return an orphan component with the given name. Can construct with the
    given `children` and `metadata`, otherwise those fields will be empty.
    """
    function Component(
            name;
            primitive   ::String = "",
            metadata = Dict{String, Any}(),
        )
        # Add all component level ports to the ports of this component.
        ports = Dict{String, Port}()
        children = Dict{String, Component}()
        # Return the newly constructed type.
        return new(
            name,
            primitive,
            children,
            ports,
            metadata,
        )
    end
end

"""
    extract_ports(c::Component, error_if_conflict::Bool=false)

Extract ports from children component of component `c`. Grabs top level children
ports and makes a new port entity in the current component.

Automatically flips the direction of the port to maintain consistency.

If error_if_conflict = true, thrown an error if redundant port names are discovered.
Otherwise, take no effect if a port already exists.
"""
function extract_ports!(c::AbstractComponent, error_if_conflict::Bool=false)
    # Iterate through the key-value pairs of the component children dictionary.
    for (name, child) in c.children, port in values(child.ports)
        # Check if port is a top level port of the current child. 
        is_top_port(port) || continue
        # Make a new port name by appending the child instantiation name to
        # the port name with a '.' in between
        port_name = join([name, port.name], ".")
        #=
        Check if the port already exists in the component. If it does, check
        the error status to decide whether to throw an option or abort the
        port creation operation.
        =#
        if haskey(c.ports, port_name)
            if error_if_conflict
                error("Port ", port_name, " already exists in component ", c.name)
            else
                continue
            end
        end

        # Flip the direction of the port
        class_name = flipdir(port)
        # Create a new port and add it to the component
        new_port = Port(port_name, class_name)
        c.ports[port_name] = new_port
    end
    return nothing
end

#=
The only difference with the top level is that children are accessed via
addresses instead of names. Since it subtypes from AbstractComponent, it can
share many of the methods defined for normal components.
=#
mutable struct TopLevel{N} <: AbstractComponent
    """The declared name of this component"""
    name    ::String
    """Reference to primitive for special operations. Default is \"\"."""
    primitive::String
    """
    Dictionary of all children of this component. String keys will be the
    instance names of the component.
    """
    children::Dict{Address{N}, Component}
    ports   ::Dict{String, Port}
    metadata::Dict{String, Any}

    # Constructor
    """
        TopLevel(name, dimensions, metadata = Dict{String,Any}())

    Create a top level component with the given name and number of dimensions.
    """
    function TopLevel{N}(name, metadata = Dict{String,Any}()) where {N}
        # Add all component level ports to the ports of this component.
        primitive   = "toplevel"
        ports       = Dict{String, Port}()
        children    = Dict{Address{N}, Component}()
        # Return the newly constructed type.
        return new{N}(
            name,
            primitive,
            children,
            ports,
            metadata,
        )
    end
end