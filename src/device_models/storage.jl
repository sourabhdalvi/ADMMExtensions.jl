function add_consensus_variables!(
    problem::DecisionModel{GenericOpProblem},
    device_type::PSY.Component=PSY.GenericBattery,
    overlap::Int=1, ## TODO: Should pass from a struct
)
    no_scenarios = problem.ext["total_scenarios"]
    time_no = problem.ext["scenario_no"]
    #TODO: problem has the system, please use system to grab this
    efficiency_data = problem.ext["efficiency_data"]
    system = PSI.get_system(problem)
    devices = PSI.get_available_components(device_type, system)
    optimization_container = PSI.get_optimization_container(problem)
    time_steps = PSI.get_time_steps(optimization_container)
    pin_var   = PSI.get_variable(optimization_container, ActivePowerInVariable(), device_type)
    pout_var  = PSI.get_variable(optimization_container, ActivePowerOutVariable(), device_type)
    energy_var = PSI.get_variable(optimization_container, EnergyVariable(), device_type)
    e_balance_cons = PSI.get_constraint(optimization_container, EnergyBalanceConstraint(), device_type)
    
    names = get_name.(devices)
    num_hours = size(timesteps)[1] + (overlap-1) # this value is determined by @transform_single_time_series!
    num_hours = 24

    ## Maybe this should happend in the build 
    storage_consensus = PSI.add_constraints_container!(
        optimization_container,
        StorageConsensusType(),
        device_type,
        names,
        1:2*overlap-1, # TEMP
    )

    e_ghost_var = PSI.add_variable_container!(
        optimization_container,
        EnergyGhostVarType(), 
        device_type,
        names,
        1:no_scenarios, # why ?
        1:overlap,
    )

    # TODO: Get rid of this magic number (NUM_SCENS)
    if time_no == 14
        e_end_constr = PSI.add_constraints_container!(
                optimization_container,
                EndStorageType(),
                device_type,
                names,
        )
    end

    jump_model = PSI.get_jump_model(optimization_container)
    # First create all the variables
    for name in device_names, sec in 1:no_scenarios, t in 1:overlap # NEW
        e_ghost_var[name, sec, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "Energy_{$(name)_{$(sec),$(t)}}",
        )
    end
    return
end



function add_battery_consensus_constraints!(
    problem::DecisionModel{GenericOpProblem},
    device_type::PSY.Component=PSY.GenericBattery,
    overlap::Int=1, ## TODO: Should pass from a struct
)
    no_scenarios = problem.ext["total_scenarios"]
    time_no = problem.ext["scenario_no"]
    #TODO: problem has the system, please use system to grab this
    efficiency_data = problem.ext["efficiency_data"]
    system = PSI.get_system(problem)
    devices = PSI.get_available_components(device_type, sys)
    optimization_container = PSI.get_optimization_container(problem)
    time_steps = PSI.get_time_steps(optimization_container)
    pin_var   = PSI.get_variable(optimization_container, ActivePowerInVariable(), device_type)
    pout_var  = PSI.get_variable(optimization_container, ActivePowerOutVariable(), device_type)
    energy_var = PSI.get_variable(optimization_container, EnergyVariable(), device_type)
    e_balance_cons = PSI.get_constraint(optimization_container, EnergyBalanceConstraint(), device_type)
    
    names = get_name.(devices)
    num_hours = size(timesteps)[1] + (overlap-1) # this value is determined by @transform_single_time_series!
    num_hours = 24
        
    for name in device_names
        # All but first stage must match consensus with previous
        if time_no > 1
            (eff_in, eff_out) = efficiency_data[name]

            JuMP.delete(jump_model, e_balance_cons[name, 1])

            e_balance_cons[name, 1] = JuMP.@constraint(jump_model, 
                energy_var[name, 1] == e_ghost_var[name, time_no-1,1] 
                    + eff_in * pin_var[name,1] - pout_var[name,1]/eff_out
            )
        end

        # TODO Allow this to be an option (end w/ >= 10 Watts)
        if time_no == 14 
            e_end_constr[name] = JuMP.@constraint(
                jump_model,
                energy_var[name, num_hours] >= 0.1
            )
        end
    end
    # Consensus for the ending values
    for name in device_names, t in 1:overlap
        if time_no < 14 
            storage_consensus[name,t] = JuMP.@constraint(
                jump_model, 
                energy_var[name, num_hours + (t-1)] == e_ghost_var[name, time_no, t])
        end
    end
    # Consensus for the beginning values (overlap-1 since we do not count time 0)
    if time_no > 1 && overlap > 1
        for name in device_names, t in 1:overlap-1
            storage_consensus[name,overlap+t] = JuMP.@constraint(
                jump_model, 
                energy_var[name, t] == e_ghost_var[name, time_no-1, t])
        end
    end
end
