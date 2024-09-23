@info "Running doe objective tests"

@testset "doeobjective" begin


    @testset "objective_mc_max_pg_competitive" begin
        for (i,bus) in case1_math4w["bus"]
            if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
                bus["vm_pair_lb"] = [(1, 4, 0.9);(2, 4, 0.9);(3, 4, 0.9)]
                bus["vm_pair_ub"] = [(1, 4, 1.1);(2, 4, 1.1);(3, 4, 1.1)]
                # bus["grounded"] .=  0
            end
        end

        for (g,gen) in case1_math4w["gen"]
            gen["cost"] = 0.0
        end

        add_gens!(case1_math4w)

        case1_math4w["gen"]["4"]["pmax"] = ones(3)

        res = GPSTTopic82024.solve_mc_doe_max_pg_competitive(case1_math4w, ipopt)
    end

    @testset "objective_mc_fair_pg_mse" begin
        for (i,bus) in case1_math4w["bus"]
            if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
                bus["vm_pair_lb"] = [(1, 4, 0.9);(2, 4, 0.9);(3, 4, 0.9)]
                bus["vm_pair_ub"] = [(1, 4, 1.1);(2, 4, 1.1);(3, 4, 1.1)]
                # bus["grounded"] .=  0
            end
        end

        for (g,gen) in case1_math4w["gen"]
            gen["cost"] = 0.0
        end

        add_gens!(case1_math4w)

        case1_math4w["gen"]["4"]["pmax"] = ones(3)

        res = GPSTTopic82024.solve_mc_doe_max_pg_competitive(case1_math4w, ipopt)
    end

    @testset "objective_variable_pg_fair_abs" begin
        for (i,bus) in case1_math4w["bus"]
            if bus["bus_type"] != 3 && !startswith(bus["source_id"], "transformer")
                bus["vm_pair_lb"] = [(1, 4, 0.9);(2, 4, 0.9);(3, 4, 0.9)]
                bus["vm_pair_ub"] = [(1, 4, 1.1);(2, 4, 1.1);(3, 4, 1.1)]
                # bus["grounded"] .=  0
            end
        end

        for (g,gen) in case1_math4w["gen"]
            gen["cost"] = 0.0
        end

        add_gens!(case1_math4w)

        case1_math4w["gen"]["4"]["pmax"] = ones(3)

        res = GPSTTopic82024.solve_mc_doe_max_pg_competitive(case1_math4w, ipopt)
    end
end