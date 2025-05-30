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
include("core/variable.jl")


include("prob/doe.jl")
include("prob/vvvw_opf.jl")
include("prob/vvvw_doe.jl")

include("form/en_ivr.jl")

include("util/curve_definitions.jl")


export nw_id_default, optimize_model!, ismultinetwork, update_data!
export solve_mc_vvvw_opf

#exports without vv/vw
export solve_mc_doe_max_pg_competitive, solve_mc_doe_fair_pg_mse, solve_mc_doe_fair_pg_abs, solve_mc_doe_equal, solve_mc_doe_log_fairness
#exports with vv/vw
export solve_mc_vvvw_doe_competitive,   solve_mc_vvvw_doe_mse,    solve_mc_vvvw_doe_abs,    solve_mc_vvvw_doe_equal, solve_mc_vvvw_doe_log_fairness

end # module GPSTTopic82024
