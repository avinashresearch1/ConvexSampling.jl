#=
module ConvexSample
=====================
A quick implementation of:

- Bounding convex relaxations of process models from below by
tractable black-box sampling, developed in the article:
Song et al. (2021),
https://doi.org/10.1016/j.compchemeng.2021.107413

This implementation applies the formulae in this article to calculate affine
relaxations of a convex function on a box domain on a box domain using
2n+1 function evaluations. An alternate method under construction
has also been implemented, which uses n+2 evaluations.

...

Written by Maha Chaudhry on June 13, 2022
=#
module SamplingUnderestimators

using LinearAlgebra
using Plots

export SamplingPolicyType, Sample_Compass_Star, Sample_Simplex_Star,
    eval_sampling_underestimator_coeffs,
    construct_sampling_underestimator,
    eval_sampling_underestimator,
    eval_sampling_lower_bound,
    plot_sampling_underestimator

## define affine under-estimator function operations, given a convex function f
## defined on a box domain with a Vector input

# define sampling method type
#   Sample_Compass_Star = sample 2n+1 points
#   Sample_Simplex Star = sample n+2 points
@enum SamplingPolicyType begin
    Sample_Compass_Star = 1
    Sample_Simplex_Star = 2
end

# default step size (alpha)
# small alphas generates tighter relaxations, but the smaller it gets, the larger
# the source of error introduced into calculation
const DEFAULT_ALPHA = 0.1

# compute 2n+1 sampled values required to construct affine relaxation:
#   (w0,y0) = midpoint of the box domain
#   (wi,yi) = 2n points along defined step lengths (alpha)
function sample_convex_function(
        f::Function, #functions must accept Vector{Float64} inputs and output scalar Float64
        xL::Vector{Float64},
        xU::Vector{Float64};
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star, #set default sampling method to 2n+1
        alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)), #sets default value for α
        lambda::Vector{Float64} = zeros(length(xL)), #accomodates offset of sampled midpoint
        epsilon::Float64 = 0.0 #accounts for error in function evaluations
    )
    n = length(xL) #function dimension

    #domain error checks
    if length(xU) != n
        throw(DomainError("function dimension: length of xL and xU must be equal"))
    elseif any(alpha .> (1.0 .- lambda)) || any(alpha .<= 0.0)
        throw(DomainError("function dimension: alpha out of range of (0.0, 1.0-lambda)"))
    elseif (n > 1) && (SamplingPolicy == Sample_Simplex_Star) &&
        (lambda != zeros(length(xL)) || epsilon != 0.0)
        throw(DomainError("function dimension: this method does not use lambda or epsilon"))
    elseif any(lambda .<= -1.0) || any(lambda .>= 1.0)
        throw(DomainError("function dimension: lambda out of range of (-1.0, 1.0)"))
    end #if

    w0 = @. 0.5*(1 + lambda)*(xL + xU)
    y0 = f(w0)
    if typeof(y0) != Float64
        throw(DomainError("function dimension: function output must be scalar Float64"))
    end

    wStep = @. 0.5*alpha*(xU - xL)
    yPlus = [f(wPlus) for wPlus in eachcol(w0 .+ diagm(wStep))]
    if SamplingPolicy == Sample_Compass_Star
        yMinus = [f(wMinus) for wMinus in eachcol(w0 .- diagm(wStep))]
    elseif SamplingPolicy == Sample_Simplex_Star
        yMinus = [f(w0 - wStep)]
    end #if
    return w0, y0, wStep, yPlus, yMinus
end #function

# compute sampled values using scalar inputs for univariate functions
function sample_convex_function(
        f::Function, #functions must accept Vector{Float64} inputs and output scalar Float64
        xL::Float64,
        xU::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64= 0.0,
        epsilon::Float64 = 0.0
    )
    sample_convex_function(f, [xL], [xU]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon)
end #function

# compute coefficients for affine underestimator function where:
# f(x) = c + dot(b, x - w0)
#   coefficient b = centered simplex gradient of f at w0 sampled
#                   along coordinate vectors
#   coefficient c = resembles standard difference approximation of
#                   second-order partial derivatives
function eval_sampling_underestimator_coeffs(
        f::Function,
        xL::Vector{Float64},
        xU::Vector{Float64};
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)),
        lambda::Vector{Float64} = zeros(length(xL)),
        epsilon::Float64 = 0.0
    )
    n = length(xL)
    w0, y0, wStep, yPlus, yMinus = sample_convex_function(f, xL, xU; SamplingPolicy, alpha, lambda, epsilon)

    if n == 1 || SamplingPolicy == Sample_Compass_Star
        b = zeros(n,1)
        for (i, bi) in enumerate(b)
            if (xL[i] < xU[i]) || (xL[i] == xU[i])
                b[i] = (yPlus[i] - yMinus[i])/abs.(2.0.*wStep[i])
            end #if
        end #for

        #coefficient c can be tightened in special cases where f is univariate
        #dependent on the defined step length:
        c = y0[1]
        if n > 1
            c -= epsilon
            for i in range(1,n)
                c -= ((1.0 + abs(lambda[i]))*(yPlus[i] + yMinus[i]
                    - 2.0*y0 + 4.0*epsilon))/(2.0*alpha[i])
            end #for
        elseif n == 1 && alpha != [1.0]
            c = 2.0*c - 0.5*(yPlus[1] + yMinus[1])
        end #if=#
        return w0, b, c, []

    #alternate calculation for b and c vectors assuming n+2 sampled points:
    elseif SamplingPolicy == Sample_Simplex_Star
        sU = @. 2.0*(yPlus - y0)/abs(2.0*wStep)
        sL = zeros(n,1)
        for (i, sLi) in enumerate(sL)
            yjsum = 0.0
            for (j, yPlusj) in enumerate(yPlus)
                if j != i
                    yjsum += y0 - yPlus[j]
                end
            end
            sL[i] = @. 2.0*(y0 - yMinus[1] + yjsum)/abs(2.0*wStep[i])
        end
        b = 0.5.*(sL + sU)

        #coefficient c calculated as affineFunc(w0):
        sR = 0.5.*(sU - sL)
        c = y0 - 0.5.*dot(sR, xU - xL)
        return w0, b, c[1], sR
    end #if
end #function

# compute coefficients using scalar inputs for univariate functions:
function eval_sampling_underestimator_coeffs(
        f::Function,
        xL::Float64,
        xU::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64= 0.0,
        epsilon::Float64 = 0.0
    )
    eval_sampling_underestimator_coeffs(f, [xL], [xU]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon)
end #function

# define affine underestimator function using calculated b, c coefficients:
function construct_sampling_underestimator(
        f::Function,
        xL::Vector{Float64},
        xU::Vector{Float64};
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)),
        lambda::Vector{Float64} = zeros(length(xL)),
        epsilon::Float64 = 0.0
    )
    n = length(xL)
    w0, b, c, sR = eval_sampling_underestimator_coeffs(f, xL, xU; SamplingPolicy,
        alpha, lambda, epsilon)
    return x -> c + dot(b, x - w0)
end #function

# define affine underestimator function using scalar inputs for univariate functions:
function construct_sampling_underestimator(
        f::Function,
        xL::Float64,
        xU::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64= 0.0,
        epsilon::Float64 = 0.0
    )
    construct_sampling_underestimator(f, [xL], [xU]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon)
end #function

# compute affine underestimator y-value using:
#  (1) computed affine underestimator function
#  (2) x-input value
function eval_sampling_underestimator(
    f::Function,
    xL::Vector{Float64},
    xU::Vector{Float64},
    xIn::Vector{Float64}; #define x-input value
    SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
    alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)),
    lambda::Vector{Float64} = zeros(length(xL)),
    epsilon::Float64 = 0.0
)
    affinefunc = construct_sampling_underestimator(f, xL, xU; SamplingPolicy,
        alpha, lambda, epsilon)
    return affinefunc(xIn)
end #function

# affine underestimator y-value using scalar inputs for univariate functions:
function eval_sampling_underestimator(
        f::Function,
        xL::Float64,
        xU::Float64,
        xIn::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64= 0.0,
        epsilon::Float64 = 0.0
    )
    eval_sampling_underestimator(f, [xL], [xU], [xIn]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon)
end #function

# compute:
#  fL = guaranteed constant scalar lower bound of f on X
function eval_sampling_lower_bound(
        f::Function,
        xL::Vector{Float64},
        xU::Vector{Float64};
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)),
        lambda::Vector{Float64} = zeros(length(xL)),
        epsilon::Float64 = 0.0
    )
    n = length(xL)
    w0, y0, wStep, yPlus, yMinus = sample_convex_function(f, xL, xU; SamplingPolicy,
        alpha, lambda, epsilon)

    #coefficient c can be tightened in special cases where f is univariate:
    if (n > 1 || lambda != zeros(n) || epsilon != 0.0) && (SamplingPolicy == Sample_Compass_Star)
        fL = y0 - epsilon
        for i in range(1,n)
            fL -= ((1.0 + abs(lambda[i]))*(max(yPlus[i], yMinus[i])
                - y0 + 2.0*epsilon))/alpha[i]
        end #for
    elseif (n > 1) && (SamplingPolicy == Sample_Simplex_Star)
        w0, b, c, sR = eval_sampling_underestimator_coeffs(f, xL, xU; SamplingPolicy,
            alpha, lambda, epsilon)
        fL = y0 .- 0.5.*sum(abs.(b).*abs.(xL - xU)) .- 0.5*dot(sR, xU - xL)
    elseif n == 1
        fL = (@. min(2.0*y0-yPlus, 2.0*y0-yMinus,
            (1.0/alpha)*yMinus-((1.0-alpha)/alpha)*y0,
            (1.0/alpha)*yPlus-((1.0-alpha)/alpha)*y0))[1]
    end #if
    return fL
end #function

# compute lower bound using scalar inputs for univariate functions:
function eval_sampling_lower_bound(
        f::Function,
        xL::Float64,
        xU::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64= 0.0,
        epsilon::Float64 = 0.0
    )
    eval_sampling_lower_bound(f, [xL], [xU]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon)
end #function

# plot:
#  function f on plane (R^n) within box domain
#  lower bound fL on plane (R^n) within box domain
#  affine underestimator on plane within box domain
#  sampled points = (w0, y0) and (wi, yi)
function plot_sampling_underestimator(
    f::Function,
    xL::Vector{Float64},
    xU::Vector{Float64};
    SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
    alpha::Vector{Float64} = fill(DEFAULT_ALPHA, length(xL)),
    lambda::Vector{Float64} = zeros(length(xL)),
    epsilon::Float64 = 0.0,
    plot3DStyle::Vector = [surface!, wireframe!, surface], #Set plot style
    fEvalResolution::Int64 = 10 #Set # of function evaluations as points^n
)
    if !all(xU .> xL)
        throw(DomainError("function dimension: individual components of xU must be greater than individual components of xL"))
    end

    n = length(xL)
    #set function definition to speed up computational time:
    affineFunc = construct_sampling_underestimator(f, xL, xU; SamplingPolicy, alpha, lambda, epsilon)
    #calculate scalar values:
    w0, y0, wStep, yPlus, yMinus = sample_convex_function(f, xL, xU; SamplingPolicy, alpha, lambda, epsilon)
    fL = eval_sampling_lower_bound(f, xL, xU; SamplingPolicy, alpha, lambda, epsilon)

    if n == 1
        #sampled points on univariate functions are collinear, so range of points
        #is also univariate:
        xMesh = range(xL[1], xU[1], fEvalResolution)
        yMeshF = zeros(fEvalResolution,1) #to collect function evaluations
        yMeshAffine = zeros(fEvalResolution,1) #to collect affine underestimator evaluations
        for (i, xi) in enumerate(xMesh)
            yMeshF[i] = f(xi)
            yMeshAffine[i] = affineFunc([xi])
        end #for

        #to plot along 2 dimensions:
        plot(xMesh, yMeshF, label = "Function", xlabel = "x axis", ylabel = "y axis")
        plot!(xMesh, yMeshAffine, label = "Affine underestimator")
        plot!(xMesh, fill!(yMeshF,fL), label = "Lower bound")
        scatter!([w0; w0 + wStep; w0 - wStep], [y0; yPlus; yMinus], label = "Sampled points")
    elseif n == 2
        #for higher dimension functions, a meshgrid of points is required
        #as function and affine accuracy may differ, each require individual meshgrids
        x1range = range(xL[1], xU[1], fEvalResolution)
        x2range = range(xL[2], xU[2], fEvalResolution)
        yMeshF = zeros(length(x1range),length(x2range)) #to collect function evaluations
        yMeshAffine = zeros(length(x1range),length(x2range)) #to collect affine underestimator evaluations
        for (i, x1) in enumerate(x1range)
            for (j, x2) in enumerate(x2range)
                yMeshF[i,j] = f([x1, x2])
                yMeshAffine[i,j] = affineFunc([x1, x2])
            end #for
        end #for

        #to plot along 3 dimensions:
        plot3DStyle[3](x1range, x2range,
            fill(fL, length(x1range), length(x2range)),
            label = "Lower bound", c=:PRGn_3)
        plot3DStyle[2](x1range, x2range, yMeshAffine,
            label = "Affine underestimator", c=:grays)
        colorBar = true
        if plot3DStyle[1] == wireframe!
            colorBar = false
        end #if
        plot3DStyle[1](x1range, x2range, yMeshF, colorbar=colorBar,
            title="From top to bottom: (1) Original function,
            (2) Affine underestimator, and (3) Lower bound",
            titlefontsize=10, xlabel = "x₁ axis", ylabel = "x₂ axis",
            zlabel = "y axis", label = "Function", c=:dense)
        wPlus = w0 .+ diagm(wStep)
        if SamplingPolicy == Sample_Compass_Star
            wMinus= w0 .- diagm(wStep)
        elseif SamplingPolicy == Sample_Simplex_Star
            wMinus = w0 - wStep
        end #if
        scatter!([w0[1]; wPlus[1,:]; wMinus[1,:]],
            [w0[2]; wPlus[2,:]; wMinus[2,:]],
            [y0; yPlus; yMinus],
            c=:purple, legend=false)
    else
        throw(DomainError("function dimension: must be 1 or 2"))
    end #if
end #function

# plot using scalar inputs for univariate functions:
function plot_sampling_underestimator(
        f::Function,
        xL::Float64,
        xU::Float64;
        SamplingPolicy::SamplingPolicyType = Sample_Compass_Star,
        alpha::Float64 = DEFAULT_ALPHA,
        lambda::Float64 = 0.0,
        epsilon::Float64 = 0.0,
        plot3DStyle::Vector = [surface!, wireframe!, surface],
        fEvalResolution::Int64 = 10,
    )
    plot_sampling_underestimator(f, [xL], [xU]; SamplingPolicy,
        alpha = [alpha], lambda = [lambda], epsilon,
        plot3DStyle, fEvalResolution)
end #function

end #module
