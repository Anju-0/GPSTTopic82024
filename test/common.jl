#=
    Contains the common functions used throughout testing. Should be populated to be used in test env to simplify testing.
=#

function add_gens!(math4w)
    gen_counter = 2
    for (d, load) in math4w["load"]
        if mod(load["index"], 4) == 1
            math4w["gen"]["$gen_counter"] = deepcopy(math4w["gen"]["1"])
            math4w["gen"]["$gen_counter"]["name"] = "$gen_counter"
            math4w["gen"]["$gen_counter"]["index"] = gen_counter
            math4w["gen"]["$gen_counter"]["cost"] = 1.0 #*math4w["gen"]["1"]["cost"]
            math4w["gen"]["$gen_counter"]["gen_bus"] = load["load_bus"]
            math4w["gen"]["$gen_counter"]["pmax"] = 5*ones(3)
            math4w["gen"]["$gen_counter"]["pmin"] = 0.0*ones(3)
            math4w["gen"]["$gen_counter"]["connections"] = [1;2;3;4]
            gen_counter = gen_counter + 1
        end
    end
end