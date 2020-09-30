############################### Continuous device build functions ###########################

function ContinuousBuildContainer()
    return Dict{PSY.PrimeMovers.PrimeMover, Float64}(
        PSY.PrimeMovers.CT => 0.0,
        PSY.PrimeMovers.CC => 0.0,
        PSY.PrimeMovers.ST => 0.0,
        PSY.PrimeMovers.WT => 0.0,
        PSY.PrimeMovers.PVe => 0.0,
        PSY.PrimeMovers.BA => 0.0,
        PSY.PrimeMovers.HY => 0.0,
    )
end

function update_continuous_samples(config, mapping, data)
    for pm in keys(mapping)
        config[pm] = data[mapping[pm]]
    end
    return config
end

function continuous_sampling(
    distribution_dict::Dict{PSY.PrimeMovers.PrimeMover, Distributions.Distribution},
    count::Int,
)
    samples = Dict()
    distribustion_array = []
    distribution_idx = Dict()
    for (ix, (pm, dist)) in enumerate(distribution_dict)
        push!(distribustion_array, dist)
        push!(distribution_idx, pm => ix)
    end
    sample_set = Distributions.Product([distribustion_array...])
    samples_distribution = rand(sample_set, count)
    for ix in 1:count
        _temp = ContinuousBuildContainer()
        _temp =
            update_continuous_samples(_temp, distribution_idx, samples_distribution[:, ix])
        samples[ix] = _temp
    end
    return samples
end

function make_continuous_ct(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity = capacity / length(buses)
    for bus in buses
        device = PSY.ThermalStandard(
            "new_CT_$(bus.name)",
            true,
            true,
            bus,
            0.1,
            0.0496,
            0.223606797749979,
            PSY.PrimeMovers.CT,
            PSY.ThermalFuels.OTHER,
            (min = 0.1, max = capacity),
            (min = 0.0, max = 0.1),
            (up = 0.03 * (capacity / 0.3), down = 0.03 * (capacity / 0.3)),
            (up = 1.0, down = 1.0),
            PSY.ThreePartCost(
                PSY.VariableCost([
                    (782.9114112000003, 0.4 * capacity),
                    (1174.3671168, 0.6 * capacity),
                    (1566.6507744000003, 0.8 * capacity),
                    (1995.1987296000002, capacity),
                ],),
                302.86484159999975,
                51.747,
                0.0,
            ),
            0.24,
        )

        push!(devices, device)
    end
    return devices
end

function make_continuous_cc(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity = capacity / length(buses)
    for bus in buses
        device = PSY.ThermalStandard(
            "new_CC_$(bus.name)",
            true,
            true,
            bus,
            0.5,
            0.6843,
            3.853894134508627,
            PSY.PrimeMovers.CC,
            PSY.ThermalFuels.NATURAL_GAS,
            (min = 0.5, max = capacity),
            (min = -0.25, max = 1.5),
            (up = 0.0414 * (capacity / 3.55), down = 0.0414 * (capacity / 3.55)),
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

        push!(devices, device)
    end
    return devices
end

function make_continuous_st(sys::PSY.System, capacity::Float64)
    devices = []
    buses = PSY.get_components(PSY.Bus, sys)
    capacity = capacity / length(buses)
    for bus in buses
        device = PSY.ThermalStandard(
            "new_ST_$(bus.name)",
            true,
            true,
            bus,
            0.1,
            0.0014000000000000002,
            0.8170679286326199,
            PSY.PrimeMovers.ST,
            PSY.ThermalFuels.NATURAL_GAS,
            (min = 0.1, max = capacity),
            (min = -0.25, max = 0.3),
            (up = 0.02 * (capacity / 0.76), down = 0.02 * (capacity / 0.76)),
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

        push!(devices, device)
    end
    return devices
end

function make_continuous_wt(sys::PSY.System, capacity::Float64, base_device = "309_WIND_1")
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity = capacity / length(buses)
    for bus in buses
        device = deepcopy(base_device)
        IS.clear_forecasts!(device)
        set_device_name!(device, "new_WIND_$(bus.name)")
        set_uuid!(device)
        device.rating = capacity
        PSY.set_bus!(device, bus)
        IS.copy_forecasts!(base_device, device)
        IS.set_time_series_storage!(device, nothing)
        services = PSY.get_services(device)
        while !isempty(services)
            PSY._remove_service!(device, services[1])
        end
        push!(devices, device)
    end
    return devices
end

function make_continuous_pv(sys::PSY.System, capacity::Float64, base_device = "324_PV_3")
    devices = []
    base_device = PSY.get_components_by_name(PSY.RenewableGen, sys, base_device)[1]
    buses = PSY.get_components(PSY.Bus, sys)
    capacity = capacity / length(buses)
    for bus in buses
        device = deepcopy(base_device)
        IS.clear_forecasts!(device)
        set_device_name!(device, "new_PVe_$(bus.name)")
        set_uuid!(device)
        device.rating = capacity
        PSY.set_bus!(device, bus)
        IS.copy_forecasts!(base_device, device)
        IS.set_time_series_storage!(device, nothing)
        services = PSY.get_services(device)
        while !isempty(services)
            PSY._remove_service!(device, services[1])
        end
        push!(devices, device)
    end
    return devices
end

function _make_device(sys::PSY.System, mover::PSY.PrimeMovers.PrimeMover, capacity::Float64)
    if mover == PSY.PrimeMovers.CT
        return make_continuous_ct(sys, capacity)
    elseif mover == PSY.PrimeMovers.CC
        return make_continuous_cc(sys, capacity)
    elseif mover == PSY.PrimeMovers.ST
        return make_continuous_st(sys, capacity)
    elseif mover == PSY.PrimeMovers.WT
        return make_continuous_wt(sys, capacity)
    elseif mover == PSY.PrimeMovers.PVe
        return make_continuous_pv(sys, capacity)
    elseif mover == PSY.PrimeMovers.BA
        return make_continuous_ba(sys, capacity)
    elseif mover == PSY.PrimeMovers.HY
        return make_continuous_hy(sys, capacity)
    end
end

function check_service(service, new_device)
    if (occursin("Reg_Up_R1", service.name)) &&
       (PSY.get_name(PSY.get_bus(new_device))) == "Abel"
        return true
    elseif (occursin("Reg_Up_R2", service.name)) &&
           (PSY.get_name(PSY.get_bus(new_device))) == "Bach"
        return true
    elseif (occursin("Reg_Up_R3", service.name)) &&
           (PSY.get_name(PSY.get_bus(new_device))) == "Cabell"
        return true
    elseif (occursin("Reg_Down_R1", service.name)) &&
           (PSY.get_name(PSY.get_bus(new_device))) == "Abel"
        return true
    elseif (occursin("Reg_Down_R2", service.name)) &&
           (PSY.get_name(PSY.get_bus(new_device))) == "Bach"
        return true
    elseif (occursin("Reg_Down_R3", service.name)) &&
           (PSY.get_name(PSY.get_bus(new_device))) == "Cabell"
        return true
    else
        return false
    end
end
