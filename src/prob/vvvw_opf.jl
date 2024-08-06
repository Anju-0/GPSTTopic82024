"""
	function solve_mc_vvvw_opf(
		data::Union{Dict{String,<:Any},String},
		model_type::Type,
		solver;
		kwargs...
	)

Solve DOE quantification problem
"""
function solve_mc_vvvw_opf(data::Union{Dict{String,<:Any},String}, model_type::Type, solver; kwargs...)
    return solve_mc_model(data, model_type, solver, build_mc_vvvw_opf; kwargs...)
end

"""
	function build_mc_vvvw_opf(
		pm::AbstractExplicitNeutralIVRModel
	)

constructor for DOE quantification in current-voltage variable space with explicit neutrals
"""
function build_mc_vvvw_opf(pm::_PMD.AbstractExplicitNeutralIVRModel)
    # Variables
    _PMD.variable_mc_bus_voltage(pm)
    _PMD.variable_mc_branch_current(pm)
    _PMD.variable_mc_load_current(pm)
    _PMD.variable_mc_load_power(pm)
    _PMD.variable_mc_generator_current(pm)
    _PMD.variable_mc_generator_power(pm)
    _PMD.variable_mc_transformer_current(pm)
    _PMD.variable_mc_transformer_power(pm)
    _PMD.variable_mc_switch_current(pm)

    # Constraints
    for i in _IM.ids(pm, :bus)

        if i in _IM.ids(pm, :ref_buses)
            _PMD.constraint_mc_voltage_reference(pm, i)
        end

        _PMD.constraint_mc_voltage_absolute(pm, i)
        _PMD.constraint_mc_voltage_pairwise(pm, i)
    end

    # components should be constrained before KCL, or the bus current variables might be undefined

    for id in _IM.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
        _PMD.constraint_mc_generator_current(pm, id)
    end

    for id in _IM.ids(pm, :load)
        _PMD.constraint_mc_load_power(pm, id)
        _PMD.constraint_mc_load_current(pm, id)
    end

    for i in _IM.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_voltage(pm, i)
        _PMD.constraint_mc_transformer_current(pm, i)

        _PMD.constraint_mc_transformer_thermal_limit(pm, i)
    end

    for i in _IM.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)

        _PMD.constraint_mc_branch_current_limit(pm, i)
        _PMD.constraint_mc_thermal_limit_from(pm, i)
        _PMD.constraint_mc_thermal_limit_to(pm, i)
    end

    for i in _IM.ids(pm, :switch)
        _PMD.constraint_mc_switch_current(pm, i)
        _PMD.constraint_mc_switch_state(pm, i)

        _PMD.constraint_mc_switch_current_limit(pm, i)
        _PMD.constraint_mc_switch_thermal_limit(pm, i)
    end

    for i in _IM.ids(pm, :bus)
        _PMD.constraint_mc_current_balance(pm, i)
    end

    # Objective
    _PMD.objective_mc_min_fuel_cost(pm)
end