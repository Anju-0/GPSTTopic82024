using GPSTTopic82024
using PowerModelsDistribution
using Ipopt
using Plots
using CSV
using DataFrames


# ipopt = Ipopt.Optimizer
# ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=> 0, "max_iter"=>1000, "tol" => 1e-6)
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "max_iter"=>1000, "tol" => 1e-6)
## Main loop
case = "LV9_258bus"
casepath = "data/$case"
file = "$casepath/Master.dss"
busdistancesdf = CSV.read("$casepath/busdistances.csv", DataFrame)
busdistances_dict = Dict(busdistancesdf.Bus[i] => busdistancesdf.busdistances[i] for i in 1:nrow(busdistancesdf))
p = CSV.read("data/penetration_samples.csv", DataFrame)

result_usable(res) = res["termination_status"]==LOCALLY_SOLVED || res["termination_status"]==ALMOST_LOCALLY_SOLVED

vscale = 1.08
loadscale = 0.2

pens =  ["r10", "r20", "r30", "r40", "r50", "r60", "r70", "r80", "r90"]
pen = pens[7]

for vscale in 1.00:0.01:1.10, loadscale in 0.1:0.1:1, pen in pens 
    @show vscale, loadscale, pen 
    eng4w = parse_file(file, transformations=[transform_loops!,remove_all_bounds!])
    eng4w["settings"]["sbase_default"] = 1
    eng4w["voltage_source"]["source"]["rs"] *=0
    eng4w["voltage_source"]["source"]["xs"] *=0
    eng4w["voltage_source"]["source"]["vm"] *=vscale

    reduce_line_series!(eng4w)
    math4w = transform_data_model(eng4w, kron_reduce=false, phase_project=false)
    busnumber_dist_dict = Dict(busid=> busdistances_dict[busname] for (busname,busid) in math4w["bus_lookup"])
    dist_array = zeros(length(busnumber_dist_dict))
    for i in 1:length(busnumber_dist_dict)
        dist_array[i] = busnumber_dist_dict[i]

    end


    for (i,bus) in math4w["bus"]
        if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
            lb =0.9
            bus["vm_pair_lb"] = [(1, 4, lb);(2, 4, lb);(3, 4, lb)]
            ub = 1.1
            bus["vm_pair_ub"] = [(1, 4, ub);(2, 4, ub);(3, 4, ub)]
            bus["vmax"] = ones(4)*1.5
            # bus["vmax"][end] = 0.05 
            bus["vmin"] = zeros(4)
            # bus["grounded"] .=  0
        else
            @show bus
        end

    end

    for (g,gen) in math4w["gen"]
        gen["cost"] = 0.0
    end

    for (d,load) in math4w["load"]
        load["pd"] .*= loadscale
        load["qd"] .*= loadscale
    end

    function add_gens!(math4w)
        gen_counter = 2
        for (d, load) in math4w["load"]
            if p[!,pen][load["index"]]
                phases = length(load["connections"])-1
                math4w["gen"]["$gen_counter"] = deepcopy(math4w["gen"]["1"])
                math4w["gen"]["$gen_counter"]["name"] = "$gen_counter"
                math4w["gen"]["$gen_counter"]["index"] = gen_counter
                math4w["gen"]["$gen_counter"]["cost"] = 1.0 #*math4w["gen"]["1"]["cost"]
                math4w["gen"]["$gen_counter"]["gen_bus"] = load["load_bus"]
                math4w["gen"]["$gen_counter"]["pmax"] = 5.0*ones(phases)
                math4w["gen"]["$gen_counter"]["pmin"] = 0.0*ones(phases) 
                math4w["gen"]["$gen_counter"]["qmax"] = 0.0*ones(phases) #PF 1 PV systems
                math4w["gen"]["$gen_counter"]["qmin"] = -0.0*ones(phases) #PF 1 PV systems
                math4w["gen"]["$gen_counter"]["connections"] = load["connections"]
                math4w["gen"]["$gen_counter"]["distance"] = busnumber_dist_dict[load["load_bus"]]
                gen_counter = gen_counter + 1
            end
        end
        @show "added $(gen_counter-1) PV systems at penetration $(pen) for $(length(math4w["load"])) loads"
    end
    
    add_gens!(math4w)
    gen_dist_array = zeros(length(math4w["gen"])-1)
    for i in 1:length(math4w["gen"])-1
        gen_dist_array[i] = math4w["gen"]["$(i+1)"]["distance"]
    end
    add_start_vrvi!(math4w)

    all_feasible = true


    res_comp = solve_mc_doe_max_pg_competitive(math4w, ipopt)
    # @assert(result_usable(res_comp))
    all_feasible = all_feasible && result_usable(res_comp)
    res_comp_obj = round(res_comp["objective"], digits=2)
    pg_cost1 = [gen["pg_cost"] for (g,gen) in res_comp["solution"]["gen"] if g!="1"]
    pg_ref_comp = res_comp["solution"]["gen"]["1"]["pg"]
    qg_ref_comp = res_comp["solution"]["gen"]["1"]["qg"]

    # res_ms = solve_mc_doe_fair_pg_mse(math4w, ipopt)
    # @assert(res_ms["termination_status"]==LOCALLY_SOLVED || res_ms["termination_status"]==ALMOST_LOCALLY_SOLVED)
    # pg_cost2 = [gen["pg_cost"] for (g,gen) in res_ms["solution"]["gen"] if g!="1"]
    # res_ms_obj = round(res_ms["objective"], digits=2)
    # pg_ref_ms = res_ms["solution"]["gen"]["1"]["pg"]

    # res_abs = solve_mc_doe_fair_pg_abs(math4w, ipopt)
    # @assert(res_abs["termination_status"]==LOCALLY_SOLVED || res_abs["termination_status"]==ALMOST_LOCALLY_SOLVED)
    # pg_cost3 = [gen["pg_cost"] for (g,gen) in res_abs["solution"]["gen"] if g!="1"]
    # res_abs_obj = round(res_abs["objective"], digits=2)
    # pg_ref_abs = res_abs["solution"]["gen"]["1"]["pg"]

    res_log = solve_mc_doe_log_fairness(math4w, ipopt)
    # @assert(result_usable(res_log))
    all_feasible = all_feasible && result_usable(res_log)

    pg_cost5 = [gen["pg_cost"] for (g,gen) in res_log["solution"]["gen"] if g!="1"]
    res_log_obj = round(res_log["objective"], digits=2)
    pg_ref_log = res_log["solution"]["gen"]["1"]["pg"]
    qg_ref_log = res_log["solution"]["gen"]["1"]["qg"]

    res_eq_obj = 0
    res_eq = solve_mc_doe_equal(math4w, ipopt)
    if res_eq["termination_status"]==LOCALLY_INFEASIBLE
        pg_cost4 = 0 .*pg_cost1
        res_eq_obj = 0
        pg_ref_eq = NaN
        qg_ref_eq = NaN
    else
        @assert(result_usable(res_eq))
        pg_cost4 = [gen["pg_cost"] for (g,gen) in res_eq["solution"]["gen"] if g!="1"]
        res_eq_obj = round(res_eq["objective"], digits=2)
        @show (res_eq["solution"]["gen"]["1"]["pg"], res_eq["solution"]["gen"]["1"]["qg"])
        pg_ref_eq = res_eq["solution"]["gen"]["1"]["pg"]
        qg_ref_eq = res_eq["solution"]["gen"]["1"]["qg"]
    end

    bb = sortperm(pg_cost5)
    # bb = sortperm(gen_dist_array)

    pg_cost1a = pg_cost1[bb]
    # pg_cost2a = pg_cost2[bb]
    # pg_cost3a = pg_cost3[bb]
    pg_cost4a = pg_cost4[bb]
    pg_cost5a = pg_cost5[bb]


    if all_feasible
        plot(pg_cost1a, linestyle=:dash, label="max. competitive $res_comp_obj - net. P $(round(sum(pg_ref_comp),digits=1)), Q $(round(sum(qg_ref_comp),digits=1))) ")
        # plot!(pg_cost2a, linestyle=:dot,  label="min. deviation squared $res_ms_obj - net. cons. $(round(sum(pg_ref_ms),digits=2))")
        # plot!(pg_cost3a, linestyle=:dashdotdot, label="min. absolute deviation $res_abs_obj - net. cons. $(round(sum(pg_ref_abs),digits=2))")
        plot!(pg_cost4a, linstyle=:dashdot, label="equal $res_eq_obj  - net. P $(round(sum(pg_ref_eq),digits=1)), Q $(round(sum(qg_ref_eq),digits=1))")
        plot!(pg_cost5a, linstyle=:solid, label="log fairness  - net. P $(round(sum(pg_ref_log),digits=1)), Q $(round(sum(qg_ref_log),digits=1))", legend=:bottomright)
        xlabel!("PV system id (-)")
        ylabel!("Export DOE (kW)")
        ylims!(0,5.1)
        xlims!(0.5,length(pg_cost1)+0.5)
        title!("No VVWC, voltage of $vscale pu, load at $loadscale, pen $(pen[2:end])")
        savefig("figures/NOVVVW_vsource$vscale load$loadscale pen$pen.pdf")
    end
end
