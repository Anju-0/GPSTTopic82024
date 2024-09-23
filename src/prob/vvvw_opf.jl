"""
	function solve_mc_vvvw_opf(
		data::Union{Dict{String,<:Any},String},
		model_type::Type,
		solver;
		kwargs...
	)

Solve DOE quantification problem
"""
function solve_mc_vvvw_opf(data::Union{Dict{String,<:Any},String},  solver; kwargs...)
    return _PMD.solve_mc_model(data, _PMD.IVRENPowerModel, solver, build_mc_vvvw_opf; kwargs...)
end

"""
	function build_mc_vvvw_opf(
		pm::AbstractExplicitNeutralIVRModel
	)

constructor for DOE quantification in current-voltage variable space with explicit neutrals
"""
function build_mc_vvvw_opf(pm::_PMD.AbstractExplicitNeutralIVRModel)
    # Register volt-var/watt functions
    vv_curve_pu = voltvar_handle()
    vw_curve_pu = voltwatt_handle()
    JuMP.register(pm.model, :vv_curve_pu, 1, vv_curve_pu; autodiff = true)
    JuMP.register(pm.model, :vw_curve_pu, 1, vw_curve_pu; autodiff = true)

    # Variables
    _PMD.variable_mc_bus_voltage(pm)
    _PMD.variable_mc_bus_voltage_magnitude_only(pm) #add for volt-var/watt
    _PMD.variable_mc_branch_current(pm)
    _PMD.variable_mc_load_current(pm)
    _PMD.variable_mc_load_power(pm)
    _PMD.variable_mc_generator_current(pm)
    _PMD.variable_mc_generator_power(pm)
    _PMD.variable_mc_transformer_current(pm)
    _PMD.variable_mc_transformer_power(pm)
    _PMD.variable_mc_switch_current(pm)

    # Constraints
    for i in _PMD.ids(pm, :bus)

        if i in _PMD.ids(pm, :ref_buses)
            _PMD.constraint_mc_voltage_reference(pm, i)
        end

        _PMD.constraint_mc_voltage_absolute(pm, i)
        _PMD.constraint_mc_voltage_pairwise(pm, i)
    end

    # components should be constrained before KCL, or the bus current variables might be undefined

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
        _PMD.constraint_mc_generator_current(pm, id)
        constraint_mc_voltvarwatt(pm, id)
    end

    for id in _PMD.ids(pm, :load)
        _PMD.constraint_mc_load_power(pm, id)
        _PMD.constraint_mc_load_current(pm, id)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_voltage(pm, i)
        _PMD.constraint_mc_transformer_current(pm, i)

        _PMD.constraint_mc_transformer_thermal_limit(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)

        _PMD.constraint_mc_branch_current_limit(pm, i)
        _PMD.constraint_mc_thermal_limit_from(pm, i)
        _PMD.constraint_mc_thermal_limit_to(pm, i)
    end

    for i in _PMD.ids(pm, :switch)
        _PMD.constraint_mc_switch_current(pm, i)
        _PMD.constraint_mc_switch_state(pm, i)

        _PMD.constraint_mc_switch_current_limit(pm, i)
        _PMD.constraint_mc_switch_thermal_limit(pm, i)
    end

    for i in _PMD.ids(pm, :bus)
        _PMD.constraint_mc_current_balance(pm, i)
    end

    # Objective
    _PMD.objective_mc_min_fuel_cost(pm)
end

function rectifier(x,y,a;type="smooth", ϵ=ϵ)
    if type=="nonsmooth"
        return f = vals -> a*max(0, vals - x) + y
    elseif type=="smooth"
        return f = vals -> a*ϵ*StatsFuns.log1pexp((vals-x)/ϵ) + y
    end
end

function voltvar_handle(;ϵ=0.01, type="smooth")
    V_vv = [195; 207; 220; 240; 258; 276]./230
    Q_vv = [44; 44;   0;   0;  -60;  -60]./100

    r1pu = rectifier(207/230,44/100,-44/13*(230/100);type=type, ϵ=ϵ)
    r2pu = rectifier(220/230,0,+44/13*(230/100);type=type, ϵ=ϵ)
    r3pu = rectifier(240/230,0,-60/18*(230/100);type=type, ϵ=ϵ)
    r4pu = rectifier(258/230,0,+60/18*(230/100);type=type, ϵ=ϵ)
    vv_curve_pu(x) = r1pu(x) + r2pu(x) + r3pu(x) + r4pu(x)
end

function voltwatt_handle(;ϵ=0.01, type="smooth")
    V_vw = [195; 253; 260; 276]./230
    P_vw = [100; 100; 20; 20]./100

    relupu = rectifier(253/230,1,-80/7*(230/100);type=type, ϵ=ϵ)
    relu2pu =rectifier(260/230,0,+80/7*(230/100);type=type, ϵ=ϵ)
    vw_curvepu(x) = relupu(x) + relu2pu(x)
end

function constraint_mc_voltvarwatt(pm::_PMD.ExplicitNeutralModels, id::Int; nw::Int=nw_id_default, report::Bool=true)
    generator = _PMD.ref(pm, nw, :gen, id)
    configuration = generator["configuration"]
    # smax = generator["smax"]
    N = length(generator["connections"])
    smax = 50.0*ones(N-1)

    pg = _PMD.var(pm, nw, :pg, id)
    qg = _PMD.var(pm, nw, :qg, id)
     

    bus = _PMD.ref(pm, nw, :bus, generator["gen_bus"])["bus_i"]
    vr = _PMD.var(pm, nw, :vr, bus)
    vi = _PMD.var(pm, nw, :vi, bus)
    vm = _PMD.var(pm, nw, :vm, bus)


    if configuration==_PMD.WYE
        if N==2 #single-phase 
            n_phase = generator["connections"][1]
            n_neutral = generator["connections"][end]
            JuMP.@constraint(pm.model,  (vr[n_phase]-vr[n_neutral])^2 + (vi[n_phase]-vi[n_neutral])^2 == vm[n_phase]^2)
            JuMP.@constraint(pm.model, vm[2] == 0.0)
            JuMP.@constraint(pm.model, vm[3] == 0.0)
            JuMP.@constraint(pm.model, vm[4] == 0.0)
            
            # JuMP.@NLconstraint(pm.model, pg[1] <= vw_curve_pu(vm[n_phase])*smax[n_phase])
            a = JuMP.@NLconstraint(pm.model, qg[1] <= vv_curve_pu(vm[n_phase])*smax[n_phase])
            # println(a)
        end
        
        if N==4 #three-phase 
            n_neutral = 4
            JuMP.@constraint(pm.model, (vr[1]-vr[n_neutral])^2 + (vi[1]-vi[n_neutral])^2 == vm[1]^2)
            JuMP.@constraint(pm.model, (vr[2]-vr[n_neutral])^2 + (vi[2]-vi[n_neutral])^2 == vm[2]^2)
            JuMP.@constraint(pm.model, (vr[3]-vr[n_neutral])^2 + (vi[3]-vi[n_neutral])^2 == vm[3]^2)
            JuMP.@constraint(pm.model, vm[4] == 0.0)
            
            
            # JuMP.@NLconstraint(pm.model,  pg[1] <= vw_curve_pu(vm[1])*smax[1])
            # JuMP.@NLconstraint(pm.model,  pg[2] <= vw_curve_pu(vm[2])*smax[2])
            # JuMP.@NLconstraint(pm.model , pg[3] <= vw_curve_pu(vm[3])*smax[3])

            a = JuMP.@NLconstraint(pm.model, qg[1] <= vv_curve_pu(vm[1])*smax[1])
            JuMP.@NLconstraint(pm.model, qg[2] <= vv_curve_pu(vm[2])*smax[2])
            JuMP.@NLconstraint(pm.model, qg[3] <= vv_curve_pu(vm[3])*smax[3])
            # println(a)
            
        end
    else #Delta

    end
end

