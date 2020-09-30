############################### Semi-discrete Build functions ###########################

function add_device_ct(bus::PSY.Bus, capacity::Float64, name::String)
    return PSY.ThermalStandard(
        name,
        true,
        true,
        bus,
        capacity * 0.4,
        0.0496,
        0.223606797749979,
        PSY.PrimeMovers.CT,
        PSY.ThermalFuels.OTHER,
        (min = capacity * 0.4, max = capacity),
        (min = 0.0, max = 0.1),
        (up = 0.03, down = 0.03),
        (up = 1.0, down = 1.0),
        PSY.ThreePartCost(
            PSY.VariableCost([
                (782.911, 0.4 * capacity),
                (1174.36, 0.6 * capacity),
                (1566.65, 0.8 * capacity),
                (1995.198, capacity),
            ],),
            302.864,
            51.747,
            0.0,
        ),
        0.24,
    )
end

function make_semi_discrete_ct(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:CT]
    remainder_cap = capacity_per_bus % unit_capacity[:CT]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_ct(bus, unit_capacity[:CT], "new_CT_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_ct(bus, remainder_cap, "new_CT_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function add_device_cc(bus::PSY.Bus, capacity::Float64, name::String)
    return PSY.ThermalStandard(
        name,
        true,
        true,
        bus,
        capacity * 0.47,
        0.6843,
        3.853894134508627,
        PSY.PrimeMovers.CC,
        PSY.ThermalFuels.NATURAL_GAS,
        (min = capacity * 0.47, max = capacity),
        (min = -0.25, max = 1.5),
        (up = 0.0414, down = 0.0414),
        (up = 8.0, down = 4.5),
        PSY.ThreePartCost(
            PSY.VariableCost([
                (3838.085535700569, 0.47 * capacity),
                (5230.332257410263, 0.65 * capacity),
                (6941.875221559945, 0.82 * capacity),
                (8943.709296295801, capacity),
            ],),
            957.5389017269495,
            28046.681022000004,
            0.0,
        ),
        4.14,
    )
end

function make_semi_discrete_cc(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:CC]
    remainder_cap = capacity_per_bus % unit_capacity[:CC]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_cc(bus, unit_capacity[:CC], "new_CC_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_cc(bus, remainder_cap, "new_CC_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function add_device_st(bus::PSY.Bus, capacity::Float64, name::String)
    return PSY.ThermalStandard(
        name,
        true,
        true,
        bus,
        capacity * 0.39,
        0.0014,
        0.8170,
        PSY.PrimeMovers.ST,
        PSY.ThermalFuels.NATURAL_GAS,
        (min = capacity * 0.39, max = capacity),
        (min = -0.25, max = 0.3),
        (up = 0.02, down = 0.02),
        (up = 8.0, down = 4.0),
        PSY.ThreePartCost(
            PSY.VariableCost([
                (553.9076596522913, 0.39 * capacity),
                (837.0160191548608, 0.58 * capacity),
                (1156.6555351904503, 0.79 * capacity),
                (1501.9025167638265, capacity),
            ],),
            415.84297278910844,
            11172.014351999998,
            0.0,
        ),
        0.89,
    )
end

function make_semi_discrete_st(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:ST]
    remainder_cap = capacity_per_bus % unit_capacity[:ST]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_st(bus, unit_capacity[:ST], "new_ST_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_st(bus, remainder_cap, "new_ST_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function add_device_renewable(
    base_device::PSY.Device,
    bus::PSY.Bus,
    capacity::Float64,
    name::String,
)
    device = deepcopy(base_device)
    IS.clear_forecasts!(device)
    set_device_name!(device, name)
    set_uuid!(device)
    device.rating = capacity
    PSY.set_bus!(device, bus)
    IS.copy_forecasts!(base_device, device)
    IS.set_time_series_storage!(device, nothing)
    services = PSY.get_services(device)
    while !isempty(services)
        PSY._remove_service!(device, services[1])
    end
    return device
end

function make_semi_discrete_wt(
    sys::PSY.System,
    capacity::Float64,
    base_device = "309_WIND_1",
)
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:WT]
    remainder_cap = capacity_per_bus % unit_capacity[:WT]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_renewable(
                base_device,
                bus,
                unit_capacity[:WT],
                "new_WIND_$(ix)_$(bus.name)",
            )
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_renewable(
                base_device,
                bus,
                remainder_cap,
                "new_WIND_rem_$(bus.name)",
            )
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_pv(
    sys::PSY.System,
    capacity::Float64,
    base_device = "324_PV_3",
)
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:PVe]
    remainder_cap = capacity_per_bus % unit_capacity[:PVe]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_renewable(
                base_device,
                bus,
                unit_capacity[:PVe],
                "new_PVe_$(ix)_$(bus.name)",
            )
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_renewable(
                base_device,
                bus,
                remainder_cap,
                "new_PVe_rem_$(bus.name)",
            )
            push!(devices, device)
        end
    end
    return devices
end

function add_device_bat(bus::PSY.Bus, capacity::Float64, name::String)
    return PSY.GenericBattery(
        name,
        true,
        bus,
        PSY.PrimeMovers.BA,
        0.0,
        (min = 0.0, max = capacity),
        capacity,
        0.0,
        (min = 0.0, max = capacity),
        (min = 0.0, max = capacity),
        (in = 0.9, out = 0.9),
        0.0,
        (min = 0.0, max = 0.0),
        0.0,
    )
end

function make_semi_discrete_bat(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:BA]
    remainder_cap = capacity_per_bus % unit_capacity[:BA]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_bat(bus, unit_capacity[:BA], "new_BA_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_bat(bus, remainder_cap, "new_BA_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function add_device_hy(
    base_device::PSY.Device,
    bus::PSY.Bus,
    capacity::Float64,
    name::String,
)
    device = deepcopy(base_device)
    IS.clear_forecasts!(device)
    set_device_name!(device, name)
    set_uuid!(device)
    device.rating = capacity
    device.basepower = capacity  
    device.activepower = capacity
    device.activepowerlimits = (min= 0., max=capacity)                                                                            
    PSY.set_bus!(device, bus)
    IS.copy_forecasts!(base_device, device)
    IS.set_time_series_storage!(device, nothing)
    services = PSY.get_services(device)
    while !isempty(services)
        PSY._remove_service!(device, services[1])
    end
    return device
end

function make_semi_discrete_hy(sys::PSY.System, capacity::Float64, base_device = "222_HYDRO_3",)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    base_device = PSY.get_components_by_name(PSY.HydroGen, sys, base_device)[1]
    capacity == 0 ? (return devices) : nothing
    capacity_per_bus = capacity / length(buses)
                                                                                                        
    no_complete_devices = capacity_per_bus ÷ unit_capacity[:HY]
    remainder_cap = capacity_per_bus % unit_capacity[:HY]
    for bus in buses
        for ix in no_complete_devices
            device = add_device_hy(base_device, bus, unit_capacity[:HY], "new_HY_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_hy(base_device, bus, remainder_cap, "new_HY_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function _make_device_semi_discrete(
    sys::PSY.System,
    mover::PSY.PrimeMovers.PrimeMover,
    capacity::Float64,
)
    if mover == PSY.PrimeMovers.CT
        return make_semi_discrete_ct(sys, capacity)
    elseif mover == PSY.PrimeMovers.CC
        return make_semi_discrete_cc(sys, capacity)
    elseif mover == PSY.PrimeMovers.ST
        return make_semi_discrete_st(sys, capacity)
    elseif mover == PSY.PrimeMovers.WT
        return make_semi_discrete_wt(sys, capacity)
    elseif mover == PSY.PrimeMovers.PVe
        return make_semi_discrete_pv(sys, capacity)
    elseif mover == PSY.PrimeMovers.BA
        return make_semi_discrete_bat(sys, capacity)
    elseif mover == PSY.PrimeMovers.HY
        return make_semi_discrete_hy(sys, capacity)
    end
end

function add_copies!(
    sys::PSY.System,
    device_list::Dict{PSY.PrimeMovers.PrimeMover, Float64},
    semi_discrete::Bool,
)
    for (type, cap) in device_list
        if semi_discrete
            devices = _make_device_semi_discrete(sys, type, cap)
        else
            devices = _make_device(sys, type, cap)
        end
        isnothing(devices) ? continue : nothing
        services = PSY.get_components(PSY.Service, sys)
        for new_device in devices
            PSY.add_component!(sys, new_device)
            for service in services
                if check_service(service, new_device)
                    PSY.add_service!(new_device, service)
                end
            end
        end
    end
    return
end

############################### Regional semi-discrete device build functions ###########################

function make_semi_discrete_regional_ct(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:CT]
        remainder_cap = capacity_per_bus % unit_capacity[:CT]
        for ix in no_complete_devices
            device = add_device_ct(bus, unit_capacity[:CT], "new_CT_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_ct(bus, remainder_cap, "new_CT_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_cc(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:CC]
        remainder_cap = capacity_per_bus % unit_capacity[:CC]
        for ix in no_complete_devices
            device = add_device_cc(bus, unit_capacity[:CC], "new_CC_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_cc(bus, remainder_cap, "new_CC_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_st(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:ST]
        remainder_cap = capacity_per_bus % unit_capacity[:ST]
        for ix in no_complete_devices
            device = add_device_st(bus, unit_capacity[:ST], "new_ST_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_st(bus, remainder_cap, "new_ST_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_wt(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
    base_device = "309_WIND_1",
)
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:WT]
        remainder_cap = capacity_per_bus % unit_capacity[:WT]
        for ix in no_complete_devices
            device = add_device_renewable(
                base_device,
                bus,
                unit_capacity[:WT],
                "new_WIND_$(ix)_$(bus.name)",
            )
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_renewable(
                base_device,
                bus,
                remainder_cap,
                "new_WIND_rem_$(bus.name)",
            )
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_pv(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
    base_device = "324_PV_3",
)
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:PVe]
        remainder_cap = capacity_per_bus % unit_capacity[:PVe]
        for ix in no_complete_devices
            device = add_device_renewable(
                base_device,
                bus,
                unit_capacity[:PVe],
                "new_PVe_$(ix)_$(bus.name)",
            )
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_renewable(
                base_device,
                bus,
                remainder_cap,
                "new_PVe_rem_$(bus.name)",
            )
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_bat(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:BA]
        remainder_cap = capacity_per_bus % unit_capacity[:BA]
        for ix in no_complete_devices
            device = add_device_bat(bus, unit_capacity[:BA], "new_BA_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_bat(bus, remainder_cap, "new_BA_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function make_semi_discrete_regional_hy(
    sys::PSY.System,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
    base_device = "222_HYDRO_3",
)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    _device = PSY.get_components_by_name(PSY.HydroGen, sys, base_device)[1]
    capacity == 0 ? (return devices) : nothing
    for (ix, bus) in enumerate(buses)
        capacity_per_bus = capacity * split_ratio[ix]
        no_complete_devices = capacity_per_bus ÷ unit_capacity[:HY]
        remainder_cap = capacity_per_bus % unit_capacity[:HY]
        for ix in no_complete_devices
            device = add_device_hy(_device, bus, unit_capacity[:HY], "new_HY_$(ix)_$(bus.name)")
            push!(devices, device)
        end
        if remainder_cap != 0
            device = add_device_hy(_device, bus, remainder_cap, "new_HY_rem_$(bus.name)")
            push!(devices, device)
        end
    end
    return devices
end

function _make_device_semi_discrete_regional(
    sys::PSY.System,
    mover::PSY.PrimeMovers.PrimeMover,
    capacity::Float64,
    split_ratio::NTuple{3, Float64},
)
    if mover == PSY.PrimeMovers.CT
        return make_semi_discrete_regional_ct(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.CC
        return make_semi_discrete_regional_cc(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.ST
        return make_semi_discrete_regional_st(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.WT
        return make_semi_discrete_regional_wt(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.PVe
        return make_semi_discrete_regional_pv(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.BA
        return make_semi_discrete_regional_bat(sys, capacity, split_ratio)
    elseif mover == PSY.PrimeMovers.HY
        return make_semi_discrete_regional_hy(sys, capacity, split_ratio)
    end
end

function ContinuousRegionalBuildContainer()
    return Dict{PSY.PrimeMovers.PrimeMover, Tuple{Float64, NTuple{3, Float64}}}(
        PSY.PrimeMovers.CT => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.CC => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.ST => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.WT => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.PVe => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.BA => (0.0, (0.,0.,0.)),
        PSY.PrimeMovers.HY => (0.0, (0.,0.,0.)),
    )
end

function update_continuous_reg_samples(config, mapping, data)
    for pm in keys(mapping)
        ix, split_ratio = mapping[pm]
        config[pm] = (data[ix], split_ratio)
    end
    return config
end

function continuous_sampling_regional(
    distribution_dict::Dict{PSY.PrimeMovers.PrimeMover, Distributions.Distribution},
    count::Int,
)
    samples = Dict()
    distribustion_array = []
    distribution_idx = Dict()
    for (ix, (pm, dist)) in enumerate(distribution_dict)
        push!(distribustion_array, dist)
        r = rand(3)
        r = r / sum(r)
        r = Tuple(r)
        push!(distribution_idx, pm => (ix, r))
    end
    sample_set = Distributions.Product([distribustion_array...])
    samples_distribution = rand(sample_set, count)
    for ix in 1:count
        _temp = ContinuousRegionalBuildContainer()
        _temp =
            update_continuous_reg_samples(_temp, distribution_idx, samples_distribution[:, ix])
        samples[ix] = _temp
    end
    return samples
end

function add_copies!(
    sys::PSY.System,
    device_list::Dict{PSY.PrimeMovers.PrimeMover, Tuple{Float64, NTuple{3, Float64}}},
)
    for (type, (cap, split_ratio)) in device_list
        devices = _make_device_semi_discrete_regional(sys, type, cap, split_ratio)
        isnothing(devices) ? continue : nothing
        services = PSY.get_components(PSY.Service, sys)
        for new_device in devices
            PSY.add_component!(sys, new_device)
            for service in services
                if check_service(service, new_device)
                    PSY.add_service!(new_device, service)
                end
            end
        end
    end
    return
end
