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

        @test isapprox(78.00000073488262, res["objective"]; atol=0.001)
        @test res["termination_status"] == LOCALLY_SOLVED
        @test isapprox([gen["pg_cost"] for (g,gen) in res["solution"]["gen"]], [3.000000022473671, 0.0, 15.000000142481792, 15.00000014248179, 15.000000142481792, 15.000000142481788, 15.000000142481792]; atol=0.001)

        # println("Obj: $(res["objective"])")
        # println("termination: $(res["termination_status"])")
        # println("Gen: $([gen["pg_cost"] for (g,gen) in res["solution"]["gen"]])")
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

        res = GPSTTopic82024.solve_mc_doe_fair_pg_mse(case1_math4w, ipopt)

        @test isapprox(res["objective"], 10.37500000748229; atol=0.001)
        @test res["termination_status"] == LOCALLY_SOLVED
        @test isapprox([gen["pg_cost"] for (g,gen) in res["solution"]["gen"]], [3.000000014964578, 0.0, 3.250000010465425, 3.250000010465425, 3.250000010465425, 3.250000010465421, 3.2500000104654223]; atol=0.001)
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

        res = GPSTTopic82024.solve_mc_doe_fair_pg_abs(case1_math4w, ipopt)
        
        @test isapprox(res["objective"], 39.42857183020957; atol=0.001)
        @test res["termination_status"] == LOCALLY_SOLVED
        @test isapprox([gen["pg_cost"] for (g,gen) in res["solution"]["gen"]], [3.0000000269044715, 1.1093727935885338e-37, 15.000000132458675, 15.000000132458673, 15.000000132458673, 15.000000132458673, 15.000000132458675]; atol=0.001)
    end
end