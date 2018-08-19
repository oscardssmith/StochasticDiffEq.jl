mutable struct ISSEMCache{uType,rateType,J,W,JC,UF,
                          uEltypeNoUnits,noiseRateType,F,dWType} <:
                          StochasticDiffEqMutableCache
  u::uType
  uprev::uType
  du1::rateType
  fsalfirst::rateType
  k::rateType
  z::uType
  dz::uType
  tmp::uType
  gtmp::noiseRateType
  gtmp2::rateType
  J::J
  W::W
  jac_config::JC
  linsolve::F
  uf::UF
  ηold::uEltypeNoUnits
  κ::uEltypeNoUnits
  tol::uEltypeNoUnits
  newton_iters::Int
  dW_cache::dWType
end

u_cache(c::ISSEMCache)    = (c.uprev2,c.z,c.dz)
du_cache(c::ISSEMCache)   = (c.k,c.fsalfirst)

function alg_cache(alg::ISSEM,prob,u,ΔW,ΔZ,p,rate_prototype,noise_rate_prototype,
                   uEltypeNoUnits,uBottomEltype,tTypeNoUnits,uprev,f,t,::Type{Val{true}})
  du1 = zero(rate_prototype)
  if has_jac(f) && !has_invW(f) && f.jac_prototype != nothing
    W = WOperator(f, zero(t))
    J = nothing
  else
    J = zeros(uEltypeNoUnits,length(u),length(u)) # uEltype?
    W = similar(J)
  end
  z = zero(u)
  dz = zero(u); tmp = zero(u); gtmp = zero(noise_rate_prototype)
  fsalfirst = zero(rate_prototype)
  k = zero(rate_prototype)

  uf = DiffEqDiffTools.UJacobianWrapper(f,t,p)
  linsolve = alg.linsolve(Val{:init},uf,u)
  jac_config = build_jac_config(alg,f,uf,du1,uprev,u,tmp,dz)
  ηold = one(uEltypeNoUnits)

  if alg.κ != nothing
    κ = alg.κ
  else
    κ = uEltypeNoUnits(1//100)
  end
  if alg.tol != nothing
    tol = alg.tol
  else
    reltol = 1e-1 # TODO: generalize
    tol = min(0.03,first(reltol)^(0.5))
  end

  if is_diagonal_noise(prob)
    gtmp2 = gtmp
    dW_cache = nothing
  else
    gtmp2 = zero(rate_prototype)
    dW_cache = zero(ΔW)
  end

  ISSEMCache(u,uprev,du1,fsalfirst,k,z,dz,tmp,gtmp,gtmp2,J,W,jac_config,linsolve,uf,
                  ηold,κ,tol,10000,dW_cache)
end

mutable struct ISSEMConstantCache{F,N} <: StochasticDiffEqConstantCache
  uf::F
  nlsolve::N
end

function alg_cache(alg::ISSEM,prob,u,ΔW,ΔZ,p,rate_prototype,noise_rate_prototype,
                   uEltypeNoUnits,uBottomEltype,tTypeNoUnits,uprev,f,t,::Type{Val{false}})
  @oopnlcachefields
  nlsolve = typeof(_nlsolve)(NLSolverCache(κ,tol,min_iter,max_iter,100000,new_W,z,W,alg.theta,zero(t),ηold,z₊,dz,tmp,b,k))
  ISSEMConstantCache(uf,nlsolve)
end

mutable struct ISSEulerHeunCache{uType,rateType,J,W,JC,UF,uEltypeNoUnits,
                                 noiseRateType,F,dWType} <:
                                 StochasticDiffEqMutableCache
  u::uType
  uprev::uType
  du1::rateType
  fsalfirst::rateType
  k::rateType
  z::uType
  dz::uType
  tmp::uType
  gtmp::noiseRateType
  gtmp2::rateType
  gtmp3::noiseRateType
  J::J
  W::W
  jac_config::JC
  linsolve::F
  uf::UF
  ηold::uEltypeNoUnits
  κ::uEltypeNoUnits
  tol::uEltypeNoUnits
  newton_iters::Int
  dW_cache::dWType
end

u_cache(c::ISSEulerHeunCache)    = (c.uprev2,c.z,c.dz)
du_cache(c::ISSEulerHeunCache)   = (c.k,c.fsalfirst)

function alg_cache(alg::ISSEulerHeun,prob,u,ΔW,ΔZ,p,rate_prototype,noise_rate_prototype,
                   uEltypeNoUnits,uBottomEltype,tTypeNoUnits,uprev,f,t,::Type{Val{true}})
  du1 = zero(rate_prototype)
  if has_jac(f) && !has_invW(f) && f.jac_prototype != nothing
    W = WOperator(f, zero(t))
    J = nothing
  else
    J = zeros(uEltypeNoUnits,length(u),length(u)) # uEltype?
    W = similar(J)
  end
  z = zero(u)
  dz = zero(u); tmp = zero(u); gtmp = zero(noise_rate_prototype)
  fsalfirst = zero(rate_prototype)
  k = zero(rate_prototype)

  uf = DiffEqDiffTools.UJacobianWrapper(f,t,p)
  linsolve = alg.linsolve(Val{:init},uf,u)
  jac_config = build_jac_config(alg,f,uf,du1,uprev,u,tmp,dz)
  ηold = one(uEltypeNoUnits)

  if alg.κ != nothing
    κ = alg.κ
  else
    κ = uEltypeNoUnits(1//100)
  end
  if alg.tol != nothing
    tol = alg.tol
  else
    reltol = 1e-1 # TODO: generalize
    tol = min(0.03,first(reltol)^(0.5))
  end

  gtmp2 = zero(rate_prototype)

  if is_diagonal_noise(prob)
      gtmp3 = gtmp2
      dW_cache = nothing
  else
      gtmp3 = zero(noise_rate_prototype)
      dW_cache = zero(ΔW)
  end

  ISSEulerHeunCache(u,uprev,du1,fsalfirst,k,z,dz,tmp,gtmp,gtmp2,gtmp3,
                         J,W,jac_config,linsolve,uf,ηold,κ,tol,10000,dW_cache)
end

mutable struct ISSEulerHeunConstantCache{F,N} <: StochasticDiffEqConstantCache
  uf::F
  nlsolve::N
end

function alg_cache(alg::ISSEulerHeun,prob,u,ΔW,ΔZ,p,rate_prototype,noise_rate_prototype,
                   uEltypeNoUnits,uBottomEltype,tTypeNoUnits,uprev,f,t,::Type{Val{false}})
  nlcache = alg.nlsolve.cache
  @unpack κ,tol,max_iter,min_iter,new_W = nlcache
  z = uprev
  uf = alg.nlsolve isa NLNewton ? DiffEqDiffTools.UDerivativeWrapper(f,t,p) : nothing
  ηold = one(uEltypeNoUnits)
  if DiffEqBase.has_jac(f) && alg.nlsolve isa NLNewton
    J = f.jac(uprev, p, t)
    if !isa(J, DiffEqBase.AbstractDiffEqLinearOperator)
      J = DiffEqArrayOperator(J)
    end
    W = WOperator(f.mass_matrix, zero(t), J)
  else
    W = typeof(u) <: Number ? u : Matrix{uEltypeNoUnits}(undef, 0, 0) # uEltype?
  end

  if κ != nothing
    κ = κ
  else
    κ = uEltypeNoUnits(1//100)
  end
  if tol == nothing
    reltol = 1e-1 # TODO: generalize
    tol = min(0.03,first(reltol)^(0.5))
  end
  z₊,dz,tmp,b,k = z,z,z,z,rate_prototype
  _nlsolve = oop_nlsolver(alg.nlsolve)

  nlsolve = typeof(_nlsolve)(NLSolverCache(κ,tol,min_iter,max_iter,100000,new_W,z,W,alg.theta,zero(t),ηold,z₊,dz,tmp,b,k))
  ISSEulerHeunConstantCache(uf,ηold,κ,tol,100000)
end
