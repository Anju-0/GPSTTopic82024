module GPSTTopic82024

import InfrastructureModels
import PowerModelsDistribution
import JuMP
import StatsFuns

const _IM = InfrastructureModels
const _PMD = PowerModelsDistribution

const pmd_it_name = "pmd"
const pmd_it_sym = Symbol(pmd_it_name)

# Explicit imports for later export
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default, ismultinetwork, update_data!


include("core/objective.jl")


include("prob/doe.jl")
include("prob/vvvw_opf.jl")

include("form/en_ivr.jl")

export nw_id_default, optimize_model!, ismultinetwork, update_data!

export solve_mc_doe, solve_mc_vvvw_opf

end # module GPSTTopic82024
