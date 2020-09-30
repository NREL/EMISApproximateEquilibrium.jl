function make_copy(device::PSY.Component, name::AbstractString)
    new_device = deepcopy(device)
    IS.clear_forecasts!(new_device)
    set_device_name!(new_device, name)
    set_uuid!(new_device)
    IS.copy_forecasts!(device, new_device)
    IS.set_time_series_storage!(new_device, nothing)
    return new_device
end

function set_uuid!(device::PSY.Component)
    device.internal.uuid = UUIDs.uuid4()
    return
end

function set_device_name!(device::PSY.Component, name::AbstractString)
    device.name = name
    return
end

function add_copies!(
    sys::PSY.System,
    device_list::Dict{Type{<:PSY.Component}, Array{AbstractString}},
)
    buses = collect(PSY.get_components(PSY.Bus, sys))
    for (type, device_names) in device_list
        if !isempty(device_names)
            for (ix, name) in enumerate(device_names)
                bus = buses[rand(1:3)]
                device = PSY.get_components_by_name(supertype(type), sys, name)[1]
                new_device = make_copy(device, name * "_copy_$(ix)")
                PSY.set_bus!(new_device, bus)
                services = PSY.get_services(new_device)
                _services = deepcopy(PSY.get_services(new_device))
                while !isempty(services)
                    PSY._remove_service!(new_device, services[1])
                end
                PSY.add_component!(sys, new_device)
                for service in _services
                    PSY.add_service!(new_device, service)
                end

            end
        end
    end
    return
end

function ConfigDataContainer()
    return Dict{Type{<:PSY.Component}, Array{AbstractString}}(
        PSY.ThermalStandard => Vector{String}(),
        PSY.RenewableFix => Vector{String}(),
        PSY.RenewableDispatch => Vector{String}(),
        PSY.GenericBattery => Vector{String}(),
        PSY.HydroDispatch => Vector{String}(),
        PSY.HydroEnergyReservoir => Vector{String}(),
    )
end

function update_config(future_config_dict, future, sample_count)
    for config in future
        future_config_dict[sample_count] = ConfigDataContainer()
        future_config_dict[sample_count][PSY.ThermalStandard] = config[1]
        future_config_dict[sample_count][PSY.HydroEnergyReservoir] = config[2]
        future_config_dict[sample_count][PSY.RenewableDispatch] = config[3]
        future_config_dict[sample_count][PSY.GenericBattery] = config[4]
        sample_count += 1
    end
    return future_config_dict, (sample_count - 1)
end
