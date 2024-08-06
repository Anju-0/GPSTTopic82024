
"""
    objective_mc_min_fuel_cost_pwl(pm::AbstractUnbalancedPowerModel)

Fuel cost minimization objective with piecewise linear terms
"""
function objective_mc_max_pg_competitive(pm::_PMD.AbstractUnbalancedPowerModel; report::Bool=true)
    objective_variable_pg_competitive(pm; report=report)
    return JuMP.@objective(pm.model, Max,
        sum(
            sum( _PMD.var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
        for (n, nw_ref) in _PMD.nws(pm))
    )
end

"""
    objective_variable_pg_cost(pm::AbstractUnbalancedIVRModel)

adds pg_cost variables and constraints for the IVR formulation
"""
function objective_variable_pg_competitive(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=report)
    for (n, nw_ref) in _PMD.nws(pm)
        #to avoid function calls inside of @NLconstraint
        pg_cost = _PMD.var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in _PMD.ids(pm, n, :gen)], base_name="$(n)_pg_cost",
        )
        report && _IM.sol_component_value(pm, pmd_it_sym, n, :gen, :pg_cost, _PMD.ids(pm, n, :gen), pg_cost)

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            pg = _PMD.var(pm, n, :pg, i)
            JuMP.@NLconstraint(pm.model, pg_cost[i] == gen["cost"]*sum(pg[c] for c in gen["connections"][1:end-1]))
        end
    end
end