#=
Simple address type. Parameterized by the number of dimensions to explore
arbitrary dimensional architectures.
=#

module Addresses

export  Address

# Internal storage representation for an address
const __ADDR_REP = Int16

"""
    Address{N}

Address data type used to abstract the notion of the location of a processor
in a grid to an arbitrary number of dimensions.

# Fields:
* `addr::NTuple{N,Int16}` - Container with the actual coordinate of the address.

# Constructors
* `Address{N}()` - Construct an address of length `N` filled with all zeros.
* `Address(x::NTuple{N,T}) where {N,T <: Integer}` - Construct an address
    from a tuple of integers.
* `Address(x::T...) where {T <: Integer}` - Construct an address from vararg
    number of integers.
"""
struct Address{N}
    addr::NTuple{N, __ADDR_REP}
end

Address{N}() where {N} = Address(Tuple(zero(__ADDR_REP) for ~ = 1:N))
Address(x::NTuple{N,T}) where {N,T <: Integer} = Address{N}(__ADDR_REP.(x))
Address(x::T...) where {T <: Integer} = Address{length(x)}(__ADDR_REP.(x))

"""
    getindex(a::Address{N}, i::Integer) where {N}

Return the `i`th component of address `a`.
"""
Base.getindex(a::Address{N}, i::Integer) where {N} = a.addr[i]

#=
Function to efficiently generate a random address given a tuple of lower bounds
and a tuple of upper bounds.
=#
function rand_address_impl(lb::Type{T}, ub::Type{T}) where T <: NTuple{N,Any} where N
    # Chain together a bunch of calls to rand
    ex = [:(rand(lb[$i]:ub[$i])) for i in 1:N]
    # Construct the address type
    return :(Address($(ex...)))
end

"""
    rand_address(lb::NTuple{N}, ub::NTuple{N}) where {N}

Generate a random address of dimension `N` where each entry `i` is chosen 
generated by `rand(lb[i]:ub[i])`.
"""
@generated function rand_address(lb::NTuple{N}, ub::NTuple{N}) where {N}
    return rand_address_impl(lb,ub)
end

Base.length(::Address{D}) where {D} = D
Base.show(io::IO, a::Address) = print(io, "Address", a.addr)
Base.string(a::Address) = join(("Address", string(a.addr)))
################################################################################
# METHODS
################################################################################
# For comparison methods, just use the fallback methods of the underlying
# tuples
Base.:(==)(a::Address{N}, b::Address{N}) where {N} = a.addr == b.addr
Base.isless(a::Address{N}, b::Address{N}) where {N} = a.addr < b.addr

function Base.isempty(a::Address{N}) where {N} 
    for i in a.addr
        i != 0 && return false
    end
    return true
end

"""
    maximum(a::Address)

Return the maximum component of `a`.
"""
Base.maximum(a::Address) = maximum(a.addr)

# Simple Iterator Interface.
Base.start(a::Address) = false
Base.next(a::Address, state::Bool) = (a, true)
Base.done(a::Address, state::Bool) = state

# Address Arithmetic
import Base: +,-,*
+(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .+ b.addr)
-(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .- b.addr)
*(a::Address{N}, b::Address{N}) where {N} = Address(a.addr .* b.addr)
-(a::Address{N}) where {N} = Address(-1 .* a.addr)

for (name, op) in zip((:dim_max, :dim_min), (:max, :min))
    eval(quote
        function ($name)(addresses)
            # Copy the first element of the address iterator.
            ex = first(addresses).addr
            for address in addresses
                ex = ($op).(ex, address.addr)
            end
            return ex
        end
    end)
end

# Documentation for the max and min functions generated above.
@doc """
    `dim_max(addresses)` returns tuple of the minimum componentwise values 
    from a collection of addresses.
    """ dim_max

@doc """
    `dim_min(addresses)` returns tuple of the minimum componentwise values 
    from a collection of addresses.
    """ dim_min

################################################################################
# Lookup Table Access Methods
################################################################################
function Base.setindex!(A::AbstractArray{T}, v::T, a::Address{N}) where {T,N}
    A[a.addr...] = v
end

function Base.getindex(A::AbstractArray{T}, a::Address{N}) where {T,N}
    A[a.addr...]
end

function Base.setindex!(A::AbstractArray{T}, v::T, a::Address{N}, b::Address{N}) where {T,N}
    A[a.addr..., b.addr...] = v
end

function Base.getindex(A::AbstractArray{T}, a::Address{N}, b::Address{N}) where {T,N}
    A[a.addr..., b.addr...]
end

function Base.setindex!(A::AbstractArray{T}, v::T, i::Integer, a::Address{N}) where {T,N}
    A[i, a.addr...] = v
end

function Base.getindex(A::AbstractArray{T}, i::Integer, a::Address{N}) where {T,N}
    A[i, a.addr...]
end

end # module Addresses
