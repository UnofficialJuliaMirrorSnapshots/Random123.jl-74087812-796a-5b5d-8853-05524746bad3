import Libdl
import Random: rand, seed!
import RandomNumbers: AbstractRNG

const librandom123 = Libdl.find_library(["librandom123"], 
                                        [joinpath(dirname(@__FILE__), "../deps/")])

"True when AES-NI library has been compiled."
const R123_USE_AESNI = librandom123 != ""

const R123Array1x{T<:Union{UInt128}}        = NTuple{1, T}
const R123Array2x{T<:Union{UInt32, UInt64}} = NTuple{2, T}
const R123Array4x{T<:Union{UInt32, UInt64}} = NTuple{4, T}

"The base abstract type for RNGs in [Random123 Family](@ref)."
abstract type AbstractR123{T<:Union{UInt32, UInt64, UInt128}} <: AbstractRNG{T} end

"RNG that generates one number at a time."
abstract type R123Generator1x{T} <: AbstractR123{T} end
"RNG that generates two numbers at a time."
abstract type R123Generator2x{T} <: AbstractR123{T} end
"RNG that generates four numbers at a time."
abstract type R123Generator4x{T} <: AbstractR123{T} end

"Set the counter of a Random123 RNG."
@inline function set_counter!(r::R123Generator1x{T}, ctr::Integer) where T <: UInt128
    r.ctr = ctr % T
    random123_r(r)
    r
end

@inline function set_counter!(r::AbstractR123{T}, ctr::Integer) where T <: Union{UInt32, UInt64}
    r.p = 0
    r.ctr1 = ctr % T
    random123_r(r)
    r
end

@inline function rand(r::R123Generator1x{T}, ::Type{T}) where T <: UInt128
    r.ctr += 1
    random123_r(r)
    r.x
end

@inline function rand(r::R123Generator2x{T}, ::Type{T}) where T <: Union{UInt32, UInt64}
    if r.p == 1
        r.ctr1 += 1
        random123_r(r)
        r.p = 0
        return r.x2
    end
    r.p = 1
    r.x1
end

@inline function rand(r::R123Generator4x{T}, ::Type{T}) where T <: Union{UInt32, UInt64}
    if r.p == 4
        r.ctr1 += 1
        random123_r(r)
        r.p = 0
    end
    r.p += 1
    unsafe_load(Ptr{T}(pointer_from_objref(r)), r.p)
end

@inline function rand(r::R123Generator1x{T}, ::Type{R123Array1x{T}}) where T <: UInt128
    r.ctr += 1
    random123_r(r)
end

@inline function rand(r::R123Generator2x{T}, ::Type{R123Array2x{T}}) where T <: Union{UInt32, UInt64}
    if r.p > 0
        r.ctr1 += 1
    end
    ret = random123_r(r) # which returns a Tuple{T, T}
    r.p = 1
    ret
end

@inline function rand(r::R123Generator4x{T}, ::Type{R123Array4x{T}}) where T <: Union{UInt32, UInt64}
    if r.p > 0
        r.ctr1 += 1
    end
    ret = random123_r(r)
    r.p = 4
    ret
end

for (T, DT) in ((UInt32, UInt64), (UInt64, UInt128))
    @eval @inline function rand(r::R123Generator2x{$T}, ::Type{$DT})
        if r.p == 1
            r.ctr1 += 1
            random123_r(r)
        end
        r.p = 1
        unsafe_load(Ptr{$DT}(pointer_from_objref(r)), 1)
    end
end

@inline function rand(r::R123Generator4x{UInt32}, ::Type{UInt128})
    if r.p > 0
        r.ctr1 += 1
        random123_r(r)
    end
    r.p = 4
    unsafe_load(Ptr{UInt128}(pointer_from_objref(r)), 1)
end

"Do one iteration and return the a tuple of a Random123 RNG object."
random123_r
