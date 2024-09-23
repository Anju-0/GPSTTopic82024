#=
    File containing the network test environments for use throughout testing.
=# 
case1_eg4w = parse_file("../test/data/opendss/ENWLNW9F6/Master.dss", transformations=[transform_loops!,remove_all_bounds!])
case1_eg4w["settings"]["sbase_default"] = 1
case1_math4w = transform_data_model(case1_eg4w, kron_reduce=false, phase_project=false)
add_start_vrvi!(case1_math4w)