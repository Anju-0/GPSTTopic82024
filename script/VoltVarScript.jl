using Statistics
using Plots
import OpenDSSDirect as ODSS

NUM_LOADS_PER_PV = 1
KVA_MULTI = 18
VSOURCE_PU = 1.0
RG_OHM = 30
PV_PHASES = 1

NETWORK_LOCATION = "./resources/ENWL_NW2_F5/Master.dss"

GLOBAL_YMIN = [240.0]
GLOBAL_YMAX = [240.0]

function allPlots()
    pvPlot = plotWithPv()
    loadPlot = plotWithLoad()
    vvPlot = plotWithVoltVar()
    vvwPlot = plotWithVoltVarWatt()
    savefig(vvPlot, "./testvv.png")
end

function plotWithPv()
	# Clear and recompile
	ODSS.dss("""
	    clear
	    compile $NETWORK_LOCATION
	    closedi
	""")
	cd("../../")
	
	# Add PV systems
	if(PV_PHASES == 3)
		add_pv_3ph(NUM_LOADS_PER_PV, KVA_MULTI)
	elseif(PV_PHASES == 1)
		add_pv_1ph(NUM_LOADS_PER_PV, KVA_MULTI)
	end
	
	# Update Vsource pu
	local vs_nr = ODSS.Vsources.First()
    while vs_nr > 0
        ODSS.Vsources.PU(VSOURCE_PU)
        vs_nr = ODSS.Vsources.Next()
    end
	# Add reactors to load points
	add_reactors(RG_OHM)

	# Re-solve
    ODSS.dss("solve")

	# # PV buses
	p2 = Plots.plot(plot_3ph_load_w_neutral())
	return p2
end

function plotWithLoad()
	
	# Clear & compile
	ODSS.dss("""
	    clear
	    compile $NETWORK_LOCATION
	    closedi
	""")
	# Update Vsource pu
	local vs_nr = ODSS.Vsources.First()
    while vs_nr > 0
        ODSS.Vsources.PU(VSOURCE_PU)
        vs_nr = ODSS.Vsources.Next()
    end

	# Add reactors to load points
	add_reactors(RG_OHM)

	# Re-solve
    ODSS.dss("solve")
	
	cd("../../")

	# Plot
    p1 = Plots.plot(plot_3ph_load_w_neutral())
	return p1
end

function plotWithVoltVar()

    # Clear and recompile
	ODSS.dss("""
    clear
    compile $NETWORK_LOCATION
    closedi
    """)
    cd("../../")

    # Add PV systems
    if(PV_PHASES == 3)
        add_pv_3ph(NUM_LOADS_PER_PV, KVA_MULTI)
    elseif(PV_PHASES == 1)
        add_pv_1ph(NUM_LOADS_PER_PV, KVA_MULTI)
    end

    # Update Vsource pu
    local vs_nr = ODSS.Vsources.First()
    while vs_nr > 0
        ODSS.Vsources.PU(VSOURCE_PU)
        vs_nr = ODSS.Vsources.Next()
    end

    # Add reactors to load points
    add_reactors(RG_OHM)

    # Add inverter control
    ODSS.dss("""
        New XYCurve.VoltVarCurve npts=4 Yarray=(0.44,0,0,-0.6) Xarray=(0.9,0.9565,1.0435,1.1217)
        New InvControl.pv_VV_VW mode=VoltVar voltage_curvex_ref=rated vvc_curve1=VoltVarCurve
        Set Maxcontroliter=100
        Set Maxiter=100
    """)

    # Re-solve
    ODSS.dss("solve")

    # Plot
    p3 = Plots.plot(plot_3ph_load_w_neutral())
    # PV buses
    Plots.hline!([207, 253], linestyle=:dash, linecolor=:green, lab="Normal Range")
    Plots.hline!([240, 258], linestyle=:dash, linecolor=:brown, lab="Inverter VoltVar response range")
    p3
end

function plotWithVoltVarWatt()

    # Clear and recompile
	ODSS.dss("""
    clear
    compile $NETWORK_LOCATION
    closedi
    """)
    cd("../../")

    # Add PV systems
    if(PV_PHASES == 3)
        add_pv_3ph(NUM_LOADS_PER_PV, KVA_MULTI)
    elseif(PV_PHASES == 1)
        add_pv_1ph(NUM_LOADS_PER_PV, KVA_MULTI)
    end

    # Update Vsource pu
    local vs_nr = ODSS.Vsources.First()
    while vs_nr > 0
        ODSS.Vsources.PU(VSOURCE_PU)
        vs_nr = ODSS.Vsources.Next()
    end

    # Add reactors to load points
    add_reactors(RG_OHM)

    # Add inverter control
    ODSS.dss("""
        New XYCurve.VoltVarCurve npts=4 Yarray=(0.44,0,0,-0.6) Xarray=(0.9,0.9565,1.0435,1.1217)
        New XYCurve.VoltWattCurve npts=4 Yarray=(1,1,1,0.2) Xarray=(0.9,0.9565,1.1,1.1304)
        New InvControl.pv_VV_VW Combimode=VV_VW voltage_curvex_ref=rated vvc_curve1=VoltVarCurve VoltwattYAxis=PMPPPU voltwatt_curve=VoltWattCurve VoltageChangeTolerance=0.0001 VarChangeTolerance=0.025 ActivePChangeTolerance=0.01 EventLog=True
        Set Maxcontroliter=100
        Set Maxiter=100
    """)

    # Re-solve
    ODSS.dss("solve")

    # Plot
    p4 = Plots.plot(plot_3ph_load_w_neutral())
    Plots.hline!([207, 253], linestyle=:dash, linecolor=:green, lab="Normal Range")
    Plots.hline!([240, 258], linestyle=:dash, linecolor=:brown, lab="Inverter VoltVar response range")
    Plots.hline!([253, 260], linestyle=:dash, linecolor=:orange, lab="Inverter VoltWatt response range")
    p4
end

function plot_3ph_load_w_neutral()
	p = Plots.plot(size=(600,300), xlims=[-Inf,0.4], widen=true)
	pn = Plots.plot(size=(600,150), xlims=[-Inf,0.4], widen=true)
	Plots.xlabel!(pn, "Distance from source (km)")
	Plots.ylabel!(pn, "Neutral (V)")
	Plots.ylabel!(p, "Average Voltage Magnitude (V)")

	# Bus connections
	line_nr = ODSS.Lines.First()
	vlims = []
	while line_nr > 0
		voltage = [[],[],[],[]]
		dist = []
		buses = [ODSS.Lines.Bus1(), ODSS.Lines.Bus2()]
		for b in buses
			ODSS.Circuit.SetActiveBus(b)
			[append!(voltage[i], hypot.(ODSS.Bus.Voltages())[i]) for i in 1:4]
			append!(dist, ODSS.Bus.Distance())
		end

        labels = [false false false false]
        if line_nr <= 0 
            labels = ["Phase A" "Phase B" "Phase C" "Neutral"]
        end
        Plots.plot!(p, dist, voltage[1], linecolor=:blue, label=labels[1])
        Plots.plot!(p, dist, voltage[2], linecolor=:purple, label=labels[2])
        Plots.plot!(p, dist, voltage[3], linecolor=:green, label=labels[3])
        Plots.plot!(pn, dist, voltage[4], linecolor=:brown, label=labels[4])
        
                
        [append!(vlims, voltage[i]) for i in 1:3]
		line_nr = ODSS.Lines.Next()
	end
	
	# Fix ylims
	ymin = minimum(vlims)
	ymax = maximum(vlims)
	if ymin < minimum(GLOBAL_YMIN)
		append!(GLOBAL_YMIN, ymin)
	end
	if ymax > maximum(GLOBAL_YMAX)
		append!(GLOBAL_YMAX, ymax)
	end
	Plots.ylims!(p, minimum(GLOBAL_YMIN), maximum(GLOBAL_YMAX))
	
	# Load buses
	load_nr = ODSS.Loads.First()
	voltage = [[],[],[],[]]
	dist = []
	while load_nr > 0
		name = ODSS.Loads.Name()
		ODSS.Circuit.SetActiveElement("Load.$name")
		bus1 = ODSS.Properties.Value("bus1")
		ODSS.Circuit.SetActiveBus(bus1)
		[append!(voltage[i], hypot.(ODSS.Bus.Voltages())[i]) for i in 1:4]
		append!(dist, ODSS.Bus.Distance())
		load_nr = ODSS.Loads.Next()
	end
	labels = ["Load Buses", false, false]
	[Plots.scatter!(p, dist, voltage[i], label=labels[i], color=:red) for i in 1:length(labels)]
	Plots.plot!(p, legend=true)
	Plots.scatter!(pn, dist, voltage[4], label=false, color=:red)
	
	# PV buses
	pv_nr = ODSS.PVsystems.First()
	pv_voltage = [[],[],[],[]]
	pv_dist = []
	while pv_nr > 0
		name = ODSS.PVsystems.Name()
		ODSS.Circuit.SetActiveElement("PVSystem.$name")
		bus1 = ODSS.Properties.Value("bus1")
		ODSS.Circuit.SetActiveBus(bus1)
		[append!(pv_voltage[i], hypot.(ODSS.Bus.Voltages())[i]) for i in 1:4]
		append!(pv_dist, ODSS.Bus.Distance())
		pv_nr = ODSS.PVsystems.Next()
	end
	pv_labels = ["PV Buses", false, false]
	[Plots.scatter!(p, pv_dist, pv_voltage[i], label=pv_labels[i], color=:yellow) for i in 1:length(pv_labels)]
	Plots.plot!(p, legend=true)
	Plots.scatter!(pn, pv_dist, pv_voltage[4], label=false, color=:yellow)
	
	# Combine plots
	l = Plots.@layout [a
				 b{0.3h}]
	pt = Plots.plot(p, pn, layout=l, yguidefontvalign = :top, size=(600,450))
	pt
end

function add_pv_1ph(num, multiplier)
	count = 0
    load_nr = ODSS.Loads.First()
    while load_nr > 0
        count += 1
        name = ODSS.Loads.Name()
        ODSS.Circuit.SetActiveElement("Load.$name")
        bus1 = ODSS.Properties.Value("bus1")
		# (num_loads_per_pv == 0) ? num_loads_per_pv = Inf : nothing
        if (count % num == 0)
            # Add PV system
            name = "PV_" * name
            phases = ODSS.Loads.Phases()
            kV = ODSS.Loads.kV()
            kVA = ODSS.Loads.kVABase() * multiplier
            
            ODSS.dss("New PVSystem.$(name) phases=$(phases) bus1=$(bus1) kV=$(kV) kVA=$(kVA) irrad=1 Pmpp=$(kVA*0.9) temperature=25")
        end
        load_nr = ODSS.Loads.Next()
    end
end

function add_pv_3ph(num, multiplier)
	count = 0
    load_nr = ODSS.Loads.First()
    while load_nr > 0
        count += 1
        name = ODSS.Loads.Name()
        ODSS.Circuit.SetActiveElement("Load.$name")
        bus1 = ODSS.Properties.Value("bus1")
        if (count % num == 0)
            # Add PV system
            name = "PV_" * name
            kV = ODSS.Loads.kV() * sqrt(3)
            kVA = ODSS.Loads.kVABase() * multiplier
			b_name = split(bus1, ".")[1]
            
            ODSS.dss("New PVSystem.$(name) phases=3 bus1=$(b_name) kV=$(kV) kVA=$(kVA) irrad=1 Pmpp=$(kVA*0.9) temperature=25")
        end
        load_nr = ODSS.Loads.Next()
    end
end

function add_reactors(ohms)
	load_nr = ODSS.Loads.First()
    while load_nr > 0
        l_name = ODSS.Loads.Name()
        ODSS.Circuit.SetActiveElement("Load.$l_name")
        bus1 = ODSS.Properties.Value("bus1")
        r_name = "Grounding_" * l_name
		b_name = split(bus1, ".")[1]
		ODSS.dss("New Reactor.$(r_name) bus1=$(b_name).4 bus2=$(b_name).0 R=$(ohms) X=1E-10")
        load_nr = ODSS.Loads.Next()
    end
end