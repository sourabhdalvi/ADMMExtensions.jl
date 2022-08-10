struct DecompositionTemplate
    network_model::PSI.NetworkModel{<:PSI.PM.AbstractPowerModel}
    devices::PSI.DevicesModelContainer
    branches::PSI.BranchModelContainer
    services::PSI.ServicesModelContainer
    function DecompositionTemplate(network::PSI.NetworkModel{T}) where {T <: PSI.PM.AbstractPowerModel}
        new(
            network,
            PSI.DevicesModelContainer(),
            PSI.BranchModelContainer(),
            PSI.ServicesModelContainer(),
        )
    end
end


DecompositionTemplate(::Type{T}) where {T <: PSI.PM.AbstractPowerModel} =
DecompositionTemplate(PSI.NetworkModel(T))
DecompositionTemplate() = DecompositionTemplate(PSI.CopperPlatePowerModel)

get_device_models(template::DecompositionTemplate) = template.devices
get_branch_models(template::DecompositionTemplate) = template.branches
get_service_models(template::DecompositionTemplate) = template.services
get_network_model(template::DecompositionTemplate) = template.network_model
get_network_formulation(template::DecompositionTemplate) =
    get_network_formulation(get_network_model(template))

function get_model(template::DecompositionTemplate, device_type)
    if device_type <: PSY.Device
        return get(template.devices, Symbol(device_type), nothing)
    elseif device_type <: PSY.Branch
        return get(template.branches, Symbol(device_type), nothing)
    elseif device_type <: PSY.Service
        return get(template.services, Symbol(device_type), nothing)
    else
        error("not supported: $device_type")
    end
end

# Note to devs. PSY exports set_model! these names are chosen to avoid name clashes

"""
Sets the network model in a template.
"""
function set_network_model!(
    template::DecompositionTemplate,
    model::PSI.NetworkModel{<:PSI.PM.AbstractPowerModel},
)
    template.network_model = model
    return
end

"""
Sets the device model in a template using the component type and formulation.
Builds a default DeviceModel
"""
function set_device_model!(
    template::DecompositionTemplate,
    component_type::Type{<:PSY.Device},
    formulation::Type{<:PSI.AbstractDeviceFormulation},
)
    PSI.set_device_model!(template, PSI.DeviceModel(component_type, formulation))
    return
end

"""
Sets the device model in a template using a DeviceModel instance
"""
function set_device_model!(
    template::DecompositionTemplate,
    model::DeviceModel{<:PSY.Device, <:PSI.AbstractDeviceFormulation},
)
    PSI._set_model!(template.devices, model)
    return
end

function set_device_model!(
    template::DecompositionTemplate,
    model::PSI.DeviceModel{<:PSY.Branch, <:PSI.AbstractDeviceFormulation},
)
    PSI._set_model!(template.branches, model)
    return
end

"""
Sets the service model in a template using a name and the service type and formulation.
Builds a default ServiceModel with use_service_name set to true.
"""
function set_service_model!(
    template::DecompositionTemplate,
    service_name::String,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(
        template,
        service_name,
        PSI.ServiceModel(service_type, formulation, use_service_name=true),
    )
    return
end

"""
Sets the service model in a template using a ServiceModel instance.
"""
function set_service_model!(
    template::DecompositionTemplate,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(template, PSI.ServiceModel(service_type, formulation))
    return
end

function set_service_model!(
    template::DecompositionTemplate,
    service_name::String,
    model::ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
)
    PSI._set_model!(template.services, service_name, model)
    return
end

function set_service_model!(
    template::DecompositionTemplate,
    model::ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
)
    PSI._set_model!(template.services, model)
    return
end
