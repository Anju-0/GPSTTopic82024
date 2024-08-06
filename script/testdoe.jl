using GPSTTopic82024
using PowerModelsDistribution
using Ipopt
file = "data/ENWLNW1F1/Master.dss"
eng4w = parse_file(file, transformations=[transform_loops!,remove_all_bounds!])
eng4w["settings"]["sbase_default"] = 1
math4w = transform_data_model(eng4w, kron_reduce=false, phase_project=false)
ipopt = Ipopt.Optimizer

res = solve_mc_doe(math4w, ipopt)