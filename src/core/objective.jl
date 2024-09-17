
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

"""
    objective_mc_fair_pg_mse(pm::AbstractUnbalancedPowerModel)

Fuel cost minimisation and fairness objective, using squared difference from mean
"""
function objective_mc_fair_pg_mse(pm::_PMD.AbstractUnbalancedPowerModel; report::Bool=true)
    objective_variable_pg_fair_mse(pm; report=report)
 
    return JuMP.@objective(pm.model, Max,
            sum(
                sum( _PMD.var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen])
            for (n, nw_ref) in _PMD.nws(pm))
            - sum(
                sum(
                    (_PMD.var(pm, n, :pg_cost, i) - _PMD.var(pm, n, :pg_avg))^2 for (i,gen) in nw_ref[:gen]
                ) for (n, nw_ref) in _PMD.nws(pm)
            ) 
        )
end

"""
    objective_mc_fair_pg_abs(pm:AbstractUnbalancedPowerModel)

Fuel cost minimisation and fairness objective, using the absolute difference from mean
"""
function objective_mc_fair_pg_abs(pm::_PMD.AbstractUnbalancedPowerModel; report::Bool=true)
    objective_variable_pg_fair_abs(pm; report=report)
 
    return JuMP.@objective(pm.model, Max,
            sum(
                sum( 
                    _PMD.var(pm, n, :pg_cost, i) for (i,gen) in nw_ref[:gen]
                ) for (n, nw_ref) in _PMD.nws(pm))
            - sum(
                sum(
                    (_PMD.var(pm, n, :pg_abs, i)) for (i,gen) in nw_ref[:gen]
                ) for (n, nw_ref) in _PMD.nws(pm)
            ) 
        )
end

"""
    objective_variable_pg_fair_mse(pm::AbstractUnbalancedIVRModel)

Adds pg_cost and pg_avg variables and constraints for the IVR formulation
"""
function objective_variable_pg_fair_mse(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=report)
    for (n, nw_ref) in _PMD.nws(pm)
        #to avoid function calls inside of @NLconstraint
        pg_cost = _PMD.var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in _PMD.ids(pm, n, :gen)], base_name="$(n)_pg_cost",
        )
        report && _IM.sol_component_value(pm, pmd_it_sym, n, :gen, :pg_cost, _PMD.ids(pm, n, :gen), pg_cost)

        pg_avg = _PMD.var(pm, n)[:pg_avg] = JuMP.@variable(pm.model, avg, base_name="pg_avg")

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            pg = _PMD.var(pm, n, :pg, i)
            JuMP.@NLconstraint(pm.model, pg_cost[i] == gen["cost"]*sum(pg[c] for c in gen["connections"][1:end-1]))
        end

        JuMP.@constraint(pm.model, pg_avg == sum(pg_cost)/length(pg_cost))
    end
end

"""
    objective_variable_pg_fair_mse(pm::AbstractUnbalancedIVRModel)

Adds pg_cost, pg_avg and pg_abs variables and constraints for the IVR formulation
"""
function objective_variable_pg_fair_abs(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=report)
    for (n, nw_ref) in _PMD.nws(pm)
        #to avoid function calls inside of @NLconstraint
        pg_cost = _PMD.var(pm, n)[:pg_cost] = JuMP.@variable(pm.model,
            [i in _PMD.ids(pm, n, :gen)], base_name="$(n)_pg_cost",
        )
        report && _IM.sol_component_value(pm, pmd_it_sym, n, :gen, :pg_cost, _PMD.ids(pm, n, :gen), pg_cost)

        pg_avg = _PMD.var(pm, n)[:pg_avg] = JuMP.@variable(pm.model, avg, base_name="pg_avg")

        pg_abs = _PMD.var(pm, n)[:pg_abs] = JuMP.@variable(pm.model,
            [i in _PMD.ids(pm, n, :gen)], base_name="$(n)_pg_abs",
        )

        # gen pwl cost
        for (i, gen) in nw_ref[:gen]
            pg = _PMD.var(pm, n, :pg, i)
            JuMP.@NLconstraint(pm.model, pg_cost[i] == gen["cost"]*sum(pg[c] for c in gen["connections"][1:end-1]))
        end

        JuMP.@constraint(pm.model, pg_avg == sum(pg_cost)/length(pg_cost))
        
        for (i, _) in nw_ref[:gen]
            JuMP.@NLconstraint(pm.model, pg_abs[i] >= pg_cost[i] - pg_avg)
            JuMP.@NLconstraint(pm.model, pg_abs[i] >= -(pg_cost[i] - pg_avg))
        end
    end
end