var documenterSearchIndex = {"docs":
[{"location":"functions.html#Exported-Types","page":"Exported Functions","title":"Exported Types","text":"","category":"section"},{"location":"functions.html","page":"Exported Functions","title":"Exported Functions","text":"SamplingType","category":"page"},{"location":"functions.html#ConvexSampling.SamplingType","page":"Exported Functions","title":"ConvexSampling.SamplingType","text":"SamplingType\n\nSpecify the sampling strategy and the number of evaluations of f. Of the type enum.\n\nPossible Inputs\n\nSAMPLE_COMPASS_STAR: (default), uses (2n+1) function evaluations in a                       compass-star stencil, where n is domain dimension of f.\nSAMPLE_SIMPLEX_STAR: uses (n+2) evaluations; this is experimental,                       and does not currently utilize lambda or epsilon.\n\n\n\n\n\n","category":"type"},{"location":"functions.html#Exported-Functions","page":"Exported Functions","title":"Exported Functions","text":"","category":"section"},{"location":"functions.html","page":"Exported Functions","title":"Exported Functions","text":"eval_sampling_underestimator_coeffs\r\nconstruct_sampling_underestimator\r\neval_sampling_underestimator\r\neval_sampling_lower_bound\r\nplot_sampling_underestimator","category":"page"},{"location":"functions.html#ConvexSampling.eval_sampling_underestimator_coeffs","page":"Exported Functions","title":"ConvexSampling.eval_sampling_underestimator_coeffs","text":"eval_sampling_underestimator_coeffs(f::Function, xL::T, xU::T;\n    samplingPolicy::SamplingType = SAMPLE_COMPASS_STAR, alpha::T,\n    lambda::T, epsilon::Float64 = 0.0)\n\nwhere T is either Vector{Float64} or Float64\n\nEvaluate the coefficients c, b, w0 for which the affine function fAffine(x) = c + dot(b, x - w0) is guaranteed to underestimate f on [xL, xU].\n\nArguments\n\nf:Function: must be convex and of the form f(x::Vector{Float64})::Float64\nxL::T: coordinates for lower bound of box domain on which f is defined\nxU::T: coordinates for upper bound of box domain on which f is defined\n\nKeywords\n\nTODO: need to find a way to include all key argument detail\n\nsamplingPolicy::SamplingType: an enum specifying sampling strategy.       See SamplingType for more details.\nlambda::T: an offset of location of domain midpoint, w0.       All components must be between (-1.0, 1.0).\nalpha::T: dimensionless step length of each sampled point from stencil centre w0.\nepsilon::Float64: an absolute error bound for evaluations of f.\n\nNotes\n\nAdditional output sR is only used by experimental method SAMPLE_SIMPLEX_STAR.\n\nExamples\n\nTo construct the underestimator function as its constant coefficients for function f on box domain xL[i] <= x[i] <= xU[i]:\n\nw0, b, c = eval_sampling_underestimator_coeffs(f, xL, xU)\n\nin which case fAffine(x) == c + dot(b, x - w0) for all x inputs.\n\n\n\n\n\n","category":"function"},{"location":"functions.html#ConvexSampling.construct_sampling_underestimator","page":"Exported Functions","title":"ConvexSampling.construct_sampling_underestimator","text":"construct_sampling_underestimator(f::Function, xL::T, xU::T;\n    samplingPolicy::SamplingType = SAMPLE_COMPASS_STAR, alpha::T,\n    lambda::T, epsilon::Float64 = 0.0)\n\nwhere T is either Vector{Float64} or Float64\n\nReturn affine underestimator function of the format fAffine(x) = c + dot(b, x - w0) by sampling function f at 2n+1 domain points where n is the function dimension.\n\nSee eval_sampling_underestimator_coeffs for more details on function inputs.\n\nExample\n\nTo construct the underestimator function for the function f on box domain xL[i] <= x[i] <= xU[i] for all x inputs:\n\njulia> 2+2\n5\n\nfAffine(x) = constructsamplingunderestimator(f, xL, xU)\n\n\n\n\n\n","category":"function"},{"location":"functions.html#ConvexSampling.eval_sampling_underestimator","page":"Exported Functions","title":"ConvexSampling.eval_sampling_underestimator","text":"eval_sampling_underestimator(f::Function, xL::T, xU::T, xIn::T;\nsamplingPolicy::SamplingType = SAMPLE_COMPASS_STAR, alpha::T,\nlambda::T, epsilon::Float64 = 0.0)\n\nwhere T is either Vector{Float64} or Float64\n\nEvaluate underestimator fAffine constructed by construct_sampling_underestimator at a domain point xIn. That is, yOut = fAffine(xIn).\n\nSee eval_sampling_underestimator_coeffs for more details on function inputs.\n\n\n\n\n\n","category":"function"},{"location":"functions.html#ConvexSampling.eval_sampling_lower_bound","page":"Exported Functions","title":"ConvexSampling.eval_sampling_lower_bound","text":"eval_sampling_lower_bound(f::Function, xL::T, xU::T;\nsamplingPolicy::SamplingType = SAMPLE_COMPASS_STAR, alpha::T,\nlambda::T, epsilon::Float64 = 0.0)\n\nwhere T is either Vector{Float64} or Float64\n\nCompute the scalar lower bound of f on the interval [xL, xU], so that f(x) >= fL for each x in the box.\n\nSee eval_sampling_underestimator_coeffs for more details on function inputs.\n\nExample\n\nfL = eval_sampling_lower_bound(f, xL, xU)\n\n\n\n\n\n","category":"function"},{"location":"functions.html#ConvexSampling.plot_sampling_underestimator","page":"Exported Functions","title":"ConvexSampling.plot_sampling_underestimator","text":"plot_sampling_underestimator(f::Function, xL::T, xU::T;\nsamplingPolicy::SamplingType = SAMPLE_COMPASS_STAR, alpha::T,\nlambda::T, epsilon::Float64 = 0.0,\nplot3DStyle::Vector = [surface!, wireframe!, surface],\nfEvalResolution::Int64 = 10)\n\nwhere T is either Vector{Float64} or Float64\n\nPlot (1) function, f, (2) affine underestimator, fAffine, and (3) lower bound fL on the box domain [xL, xU].\n\nAdditional Keywords\n\nplot3DStyle::Vector: sets the plot style (ex. wireframe, surface, etc.)       of each individual plot component in the set order:       (1) lower bound, (2) affine under-estimator, (3) convex function.\nfEvalResolution::Int64: number of mesh rows per domain dimension in the resulting plot.\n\nNotes\n\nf must be a function of either 1 or 2 variables and must take a Vector{Float64} input. The produced graph may be stored to a variable and later retrieved with @show.\n\nSee eval_sampling_underestimator_coeffs for more details on function inputs.\n\n\n\n\n\n","category":"function"},{"location":"index.html#**convex-sampling-Documentation**","page":"Introduction","title":"convex-sampling Documentation","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Welcome to the documentation page. \"Insert overview here\"","category":"page"},{"location":"index.html#Installation-and-Usage","page":"Introduction","title":"Installation and Usage","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"ConvexSampling is not currently a registered Julia package. From the Julia REPL, type ] to access the Pkg REPL mode and then run the following command:","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"add https://github.com/kamilkhanlab/convex-sampling","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Then, to use the package:","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"using ConvexSampling","category":"page"},{"location":"index.html#Example","page":"Introduction","title":"Example","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"\"Insert example here\"","category":"page"},{"location":"index.html#Authors","page":"Introduction","title":"Authors","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Maha Chaudhry, Department of Chemical Engineering, McMaster University\nKamil Khan, TODO","category":"page"},{"location":"index.html#References","page":"Introduction","title":"References","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Yingkai Song, Huiyi Cao, Chiral Mehta, and Kamil A. Khan, Bounding convex relaxations of process models from below by tractable black-box sampling, Computers & Chemical Engineering, 153:107413, 2021, DOI: 10.1016/j.compchemeng.2021.107413","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"TODO: Next page should be method outline","category":"page"}]
}
