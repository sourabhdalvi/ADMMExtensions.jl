  
function add_consensus_variables!(
    problem::DecisionModel{GenericOpProblem},
    device_type::{<:PSY.ThermalGen},
    overlap::Int=1, ## TODO: Should pass from a struct
)
    no_scenarios = problem.ext["total_scenarios"]
    time_no = problem.ext["scenario_no"]
    # time_no += 1 # nodeid is 1-indexed based
    system = PSI.get_system(problem)
    devices = PSI.get_available_components(device_type, system)
    optimization_container = PSI.get_optimization_container(problem)
    
    names = get_name.(devices)
    uc_consensus = PSI.add_constraints_container!(
        optimization_container,
        UCConsensusType(),
        device_type,
        names,
    )

    uc_on_ghost_var = PSI.add_variable_container!(
        optimization_container,
        UCGhostVarType(), 
        device_type,
        names,
        1:no_scenarios,
    )

    return
end


function add_uc_consensus_constraints!(problem::DecisionModel{GenericOpProblem})
    no_scenarios = problem.ext["total_scenarios"]
    time_no = problem.ext["scenario_no"]
    # time_no += 1 # nodeid is 1-indexed based
    
    optimization_container = PSI.get_optimization_container(problem)
    stop_var  = PSI.get_variable(optimization_container, StopVariable(), device_type)
    start_var = PSI.get_variable(optimization_container, StartVariable(), device_type)
    on_var    = PSI.get_variable(optimization_container, OnVariable(), device_type)
    uc_thermal_cons = PSI.get_constraint(optimization_container, CommitmentConstraint(), device_type)
    
    thermal_names, timesteps = axes(on_var)
    num_hours = size(timesteps)[1] 

    uc_consensus = PSI.get_variable(optimization_container, UCConsensusType(), device_type)

    uc_on_ghost_var =  PSI.get_variable(optimization_container, UCGhostVarType(), device_type)

    jump_model = PSI.get_jump_model(optimization_container)
    for name in thermal_names
        for sec in 1:no_scenarios
            uc_on_ghost_var[name, sec] = JuMP.@variable(
                optimization_container.JuMPmodel,
                base_name = "ThermalStandardOn_Ghost_{$(name)_{$(sec)}}",
            )
        end

        if time_no > 1
            JuMP.delete(jump_model, uc_thermal_cons[name, 1])
            
            uc_thermal_cons[name, 1] = JuMP.@constraint(jump_model, 
                on_var[name, 1] == uc_on_ghost_var[name, time_no-1] + start_var[name,1]  - stop_var[name,1]
            )
        end

        uc_consensus[name] = 
            JuMP.@constraint(jump_model, on_var[name, num_hours] == uc_on_ghost_var[name, time_no])
    end

    return
end
