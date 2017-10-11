function traitfun(eco::Ecosystem, pos::Int64, spp::Int64)
    hab = eco.abenv.habitat
    trts = eco.spplist.traits
    rel = eco.relationship
  _traitfun(hab, trts, rel, pos, spp, iscontinuous(hab))
end
function _traitfun(hab::AbstractHabitat, trts::AbstractTraits,
     rel::AbstractTraitRelationship, pos::Int64,
     spp::Int64, cont::Array{Bool, 1})
    traitnames = fieldnames(trts)
    habnames = fieldnames(hab)
    relnames = fieldnames(rel)
    results = map(length(traitnames)) do tr
        thishab = gethabitat(hab, habnames[tr])
        thistrt = getpref(trts, traitnames[tr])
        thisrel = getrelationship(rel, relnames[tr])
        _traitfun(thishab, thistrt, thisrel, pos, spp, iscontinuous(thishab))
    end
    combineTR(rel)(results)
end
function _traitfun(hab::ContinuousHab, trts::ContinuousTrait,
    rel::AbstractTraitRelationship, pos::Int64, spp::Int64, cont::Bool)
        h = gethabitat(hab, pos)
        mean, var = getpref(trts, spp)
    return rel(h, mean, var)
end

function _traitfun(hab::DiscreteHab, trts::DiscreteTrait,
    rel::AbstractTraitRelationship, pos::Int64, spp::Int64, cont::Bool)
        currentniche = gethabitat(hab, pos)
        preference = getpref(trts, spp)
    return rel(currentniche, preference)
end

#function TraitFun(eco::Ecosystem, pos::Int64, spp::Int64, cont::Bool = true)
#  T = gethabitat(eco, pos)
#  T_opt, Var = getpref(env, eco, spp)
#  return gettraitfun(eco)(T, T_opt, Var)
#end

#function TraitFun(eco::Ecosystem, pos::Int64, spp::Int64, cont::Bool = false)
#  T = gethabitat(eco, pos)
#  T_opt, Var = getpref(env, eco, spp)
#  return gettraitfun(eco)(T, T_opt, Var)
#end
#function TraitFun(env::Type{DiscreteHab{Niches}}, eco::Ecosystem, pos::Int64, spp::Int64)
#  currentniche = gethabitat(eco, pos)
#  preference = getpref(env, eco, spp)
#  return gettraitfun(eco)(currentniche, preference)
#end

#function TraitFun(env::Type{ContinuousHab{None}}, eco::Ecosystem, pos::Int64, spp::Int64)
#  return 1.0
#end
function getpref(traits::ContinuousTrait, spp::Int64)
  return traits.mean[spp], traits.var[spp]
end

function getpref(traits::DiscreteTrait, spp::Int64)
  return traits.val[spp]
end

function getpref(traits::AbstractTraits, field::Symbol)
  return getfield(traits, field)
end

function getrelationship(rel::AbstractTraitRelationship, field::Symbol)
  return getfield(rel, field)
end
