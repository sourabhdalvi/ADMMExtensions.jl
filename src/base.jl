
function build_sub_problem(
    system::PSY.System,
    template::PSI.ProblemTemplate,
    initial_time::DateTime,
    solver,
    output_dir =mktemp(cleanup=true),
)

    problem = DecisionModel(
        template, 
        system, 
        name = "SubProblem",
        optimizer = solver, 
        warm_start = false,
        initialize_model = false,
        initial_time = initial_time,
    )
    build!(problem, output_dir = output_dir)
    return problem
end


function populate_ext!(problem::PSI.DecisionModel{GenericOpProblem}, scenario_no, params)
    problem.ext["scenario_no"] = scenario_no
    problem.ext["efficiency_data"] = params["efficiency_data"]
    problem.ext["total_scenarios"] = params["total_scenarios"] 
    return
end


function get_consensus_varnames(problem::DecisionModel{GenericOpProblem})
    optimization_container = PSI.get_optimization_container(problem)
    jump_model = PSI.get_jump_model(optimization_container)
    varnames = String[]

    optimization_container = PSI.get_optimization_container(problem)
    energy_var = PSI.get_variable(optimization_container, EnergyGhostVarType(), GenericBattery)
    battery_names, timesteps = axes(energy_var)

    thermal_var = PSI.get_variable(optimization_container, UCGhostVarType(), ThermalStandard)
    thermal_names, timesteps = axes(thermal_var)

    println(battery_names)
    println(thermal_names)

    #=
    for name in device_names
        for sec in 1:params["total_scenarios"]
            varname = "Energy_{$(name)_{$(sec)}}"
            push!(varnames, varname)
        end
    end

    thermal_var = PSI.get_variable(optimization_container, OnVariable(), PSY.ThermalStandard)
    thermal_names, timesteps = axes(thermal_var)

    for name in thermal_names
        for sec in 1:params["total_scenarios"]
            varname = "ThermalStandardOn_Ghost_{$(name)_{$(sec)}}"
            push!(varnames, varname)
        end 
    end

    return varnames
    consensus_varname_list =  JuMP.VariableRef[]
    for (var_key, cont) in PSI.get_variables(problem) 
        if var_key == PSI.VariableKey(EnergyGhostVarType, GenericBattery)
            push!(consensus_varname_list, cont.name)
        end
        if var_key == PSI.VariableKey(UCGhostVarType, ThermalStandard)
            push!(consensus_varname_list, cont.name)
        end
    end
    
    return consensus_varname_list
    =#
end



function create_rts_model(nodeid, args)
    # TODO: Add params as function call
    params = Dict()
    params["scenario_len"] = SCEN_LEN
    params["total_scenarios"] = NUM_SCENS
    overlap = get(args, "overlap", 1)
    curtailment = get(args, "curtailment", -1)

    scen_len = params["scenario_len"] # Number of days (later generalize to scenarios)
    sys_name = "/projects/pvb/cju/jucaleb4/workbench/gen_systems/data/rts_with_battery_060822_sys.json"

    solver = optimizer_with_attributes(Xpress.Optimizer, 
                                       "MIPRELSTOP" => 1e-3, 
                                       "MAXTIME" => 120,
                                       "CONCURRENTTHREADS" => 4)
    # we only want more overlap for all but last time stage
    if nodeid < params["total_scenarios"]
        hour_len = 24 * scen_len + (overlap-1)
    else
        hour_len = 24 * scen_len 
    end
    initial_time = DateTime("2020-01-01T00:00:00") + Dates.Day(scen_len*(nodeid-1))
    println(initial_time)
    system = PSY.System(sys_name, time_series_directory = "/tmp/scratch")
    PSY.transform_single_time_series!(system, hour_len, Hour(hour_len))
    problem = build_rts_operations_problem(
        system,
        initial_time,
        solver,
        curtailment,
        CopperPlatePowerModel,
        "./simulation_folder/",
    )
    
    efficiency_data = Dict()
    for h in  get_components(GenericBattery, system)
        name = PSY.get_name(h)
        efficiency_data[name] = PSY.get_efficiency(h)
    end
    params["efficiency_data"] = efficiency_data
    populate_ext!(problem, nodeid, params)
    add_battery_consensus_constraints!(problem, overlap)
    add_uc_consensus_constraints!(problem)

    optimization_container = PSI.get_optimization_container(problem)
    jump_model = PSI.get_jump_model(optimization_container)
    # JuMP.set_optimizer(jump_model, Xpress.Optimizer)
    # JuMP.set_optimizer_attribute(model, "MIPRELSTOP", 1e-4)
    # consensus_varnames = get_consensus_varnames(problem::DecisionModel{GenericOpProblem})
    return jump_model, problem
    # jump_model, variable_map = get_subproblem(problem)
    # return JuMPSubproblem(jump_model, scenario_id, variable_map)
end
