######################## Simulation Definations #######################
function create_uc_template()
    service = Dict(
        :ReserveUp =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, PSI.RangeReserve),
        :ReserveDown =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, PSI.RangeReserve),
    )
    devices = Dict(
        :Generators =>
            PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalStandardUnitCommitment),
        :Ren => PSI.DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch),
        :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
        :HydroROR =>
            PSI.DeviceModel(PSY.HydroEnergyReservoir, PSI.HydroDispatchRunOfRiver),
        :RenFx => PSI.DeviceModel(PSY.RenewableFix, PSI.FixedOutput),
        :Batt => PSI.DeviceModel(PSY.GenericBattery, PSI.BookKeepingwReservation),
    )

    template_uc = PSI.template_unit_commitment(
        network = PSI.PM.NFAPowerModel,
        devices = devices,
        services = service,
    )
    return template_uc
end

function create_ed_template()
    service = Dict(
        :ReserveUp =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, PSI.RangeReserve),
        :ReserveDown =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, PSI.RangeReserve),
    )
    devices = Dict(
        :Generators => PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalDispatch), # ramp limited creats infeasibilities
        :Ren => PSI.DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch),
        :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
        :HydroROR =>
            PSI.DeviceModel(PSY.HydroEnergyReservoir, PSI.HydroDispatchRunOfRiver),
        :RenFx => PSI.DeviceModel(PSY.RenewableFix, PSI.FixedOutput),
        :Batt => PSI.DeviceModel(PSY.GenericBattery, PSI.BookKeeping),
    )
    template_ed = PSI.template_economic_dispatch(
        network = PSI.PM.NFAPowerModel,
        devices = devices,
        services = service,
    )

    return template_ed
end

function create_continuous_template()
    service = Dict(
        :ReserveUp =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveUp}, PSI.RangeReserve),
        :ReserveDown =>
            PSI.ServiceModel(PSY.VariableReserve{PSY.ReserveDown}, PSI.RangeReserve),
    )
    devices = Dict(
        :Generators => PSI.DeviceModel(PSY.ThermalStandard, PSI.ThermalRampLimited),
        :Ren => PSI.DeviceModel(PSY.RenewableDispatch, PSI.RenewableFullDispatch),
        :Loads => PSI.DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad),
        :HydroROR =>
            PSI.DeviceModel(PSY.HydroEnergyReservoir, PSI.HydroDispatchRunOfRiver),
        :RenFx => PSI.DeviceModel(PSY.RenewableFix, PSI.FixedOutput),
        :Batt => PSI.DeviceModel(PSY.GenericBattery, PSI.BookKeeping),
    )

    template_uc = PSI.template_economic_dispatch(
        network = PSI.PM.NFAPowerModel,
        devices = devices,
        services = service,
    )
    return template_uc
end

function create_stage(
    template::PSI.OperationsProblemTemplate,
    sys::PSY.System,
    solver::JuMP.MOI.OptimizerWithAttributes;
    kwargs...,
)
    constraint_duals = get(kwargs, :constraint_duals, nothing)
    if isnothing(constraint_duals)
        stage = PSI.Stage(
            PSI.GenericOpProblem,
            template,
            sys,
            solver;
            balance_slack_variables = true,
            services_slack_variables = true,
        )
        return stage
    else
        stage = PSI.Stage(
            PSI.GenericOpProblem,
            template,
            sys,
            solver;
            balance_slack_variables = true,
            services_slack_variables = true,
            export_pwl_vars = true,
            constraint_duals = constraint_duals,
        )
        return stage
    end
end

function create_sequence(stage_1::AbstractString, stage_2::AbstractString)
    sequence = PSI.SimulationSequence(
        step_resolution = Dates.Hour(24),
        order = Dict(1 => stage_1, 2 => stage_2),
        feedforward_chronologies = Dict(
            (stage_1 => stage_2) => PSI.Synchronize(periods = 24),
        ),
        horizons = Dict(stage_1 => 24, stage_2 => 1),
        intervals = Dict(
            stage_1 => (Dates.Hour(24), PSI.Consecutive()),
            stage_2 => (Dates.Hour(1), PSI.Consecutive()),
        ),
        feedforward = Dict(
            (stage_2, :devices, :Generators) => PSI.SemiContinuousFF(
                binary_source_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        cache = Dict(
            (stage_1,) => PSI.TimeStatusChange(PSY.ThermalStandard, PSI.ON),
            (stage_1,) => PSI.StoredEnergy(PSY.GenericBattery, PSI.ENERGY),
        ),
        ini_cond_chronology = PSI.InterStageChronology(),
    )
    return sequence
end

function change_load_profile!(rawsys::PSY.PowerSystemTableData, multiplier::Float64)
    rt_dir = joinpath(
        dirname(rawsys.directory),
        "timeseries_data_files/Load/REAL_TIME_regional_Load.csv",
    )
    da_dir = joinpath(
        dirname(rawsys.directory),
        "timeseries_data_files/Load/DAY_AHEAD_regional_Load.csv",
    )
    rt_load = CSV.read(rt_dir)
    da_load = CSV.read(da_dir)
    rt_load[!, [Symbol(1), Symbol(2), Symbol(3)]] =
        rt_load[!, [Symbol(1), Symbol(2), Symbol(3)]] .* multiplier
    da_load[!, [Symbol(1), Symbol(2), Symbol(3)]] =
        da_load[!, [Symbol(1), Symbol(2), Symbol(3)]] .* multiplier
    CSV.write(rt_dir, rt_load)
    CSV.write(da_dir, da_load)
    return
end

function build_training_list(sys::PSY.System)
    category_dict = Dict()
    capacity_dict = Dict()
    reg_capacity_dict = Dict()
    technology = [
        PSY.PrimeMovers.ST,
        PSY.PrimeMovers.CT,
        PSY.PrimeMovers.CC,
        PSY.PrimeMovers.WT,
        PSY.PrimeMovers.HY,
        PSY.PrimeMovers.PVe,
        PSY.PrimeMovers.BA,
    ]
    devices = collect(PSY.get_components(PSY.Generator, sys))
    storage_devices = collect(PSY.get_components(PSY.Storage, sys))
    devices = vcat(devices, storage_devices)
    buses = collect(PSY.get_components(PSY.Bus, sys))
    for tech in technology
        _devices = filter(x -> x.primemover == tech, devices)
        if isempty(_devices)
            category_dict[Symbol(tech)] = []
            capacity_dict[Symbol(tech)] = 0.0
        else
            category_dict[Symbol(tech)] = PSY.get_name.(_devices)
            capacity_dict[Symbol(tech)] = sum(get_capacity.(_devices))
        end
        for bus in buses
            if !isempty(_devices)
                reg_devices = filter(x -> PSY.get_name(x.bus) == PSY.get_name(bus), _devices)
                if isempty(reg_devices)
                    reg_capacity_dict[(Symbol(tech), PSY.get_name(bus))] = 0.
                else
                    reg_capacity_dict[(Symbol(tech), PSY.get_name(bus))] = sum(get_capacity.(reg_devices))
                end
            else
                reg_capacity_dict[(Symbol(tech), PSY.get_name(bus))] = 0.
            end
        end
    end
    return category_dict, capacity_dict, reg_capacity_dict
end

get_capacity(v::PSY.ThermalGen) = v.activepowerlimits.max
get_capacity(v::PSY.HydroGen) = v.activepowerlimits.max
get_capacity(v::PSY.RenewableGen) = v.rating
get_capacity(v::PSY.Storage) = v.capacity.max

function create_simulation(
    file_path::AbstractString,
    days::Int64,
    pruned_unit::Dict{Type{<:PSY.Component}, Array{AbstractString}},
    device_list::Dict,
    time_series_directory::AbstractString,
    rts_dir = nothing,
    load_multiplier = 1.0,
    ;
    kwargs...,
)
    rts_dir = get_rts_data(; rts_dir = rts_dir)
    rawsys = read_rts_data(rts_dir)
    simulation_name = get(kwargs, :simulation_name, "surrogate_epec")
    optimizer = get(kwargs, :optimizer, Cbc_optimizer)
    sys_UC = PSY.System(
        rawsys;
        forecast_resolution = Dates.Hour(1),
        time_series_directory = time_series_directory,
    )

    add_copies!(sys_UC, device_list)

    prune_system_devices!(sys_UC, pruned_unit)
    template_uc = create_uc_template()
    template_ed = create_ed_template()

    uc_stage = create_stage(template_uc, sys_UC, optimizer)
    ed_stage = create_stage(
        template_ed,
        sys_UC,
        optimizer;
        constraint_duals = [
            Symbol("nodal_balance_active__PowerSystems.Bus"),
            Symbol("requirement__PowerSystems.VariableReserve_PowerSystems.ReserveDown"),
            Symbol("requirement__PowerSystems.VariableReserve_PowerSystems.ReserveUp"),
        ],
    )

    stages_definition = Dict("UC" => uc_stage, "ED" => ed_stage)

    sequence = create_sequence("UC", "ED")

    sim = PSI.Simulation(
        name = simulation_name,
        steps = days,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
        initial_time = Dates.DateTime("2020-01-01T00:00:00"),
    )
    PSI.build!(sim)

    sim_results = PSI.execute!(sim;)

    # res_uc = load_simulation_results(sim_results, "UC");
    res_ed = PSI.load_simulation_results(sim_results, "ED")
    PSI.write_to_CSV(res_ed)
    category_dict, capacity_dict, reg_capacity_dict = build_training_list(sys_UC)
    bus_mapping = Dict(
        PSY.get_name(d) => PSY.get_name(PSY.get_bus(d))
        for d in PSY.get_components(PSY.StaticInjection, sys_UC) if (typeof(d) <: PSY.Generator) || (typeof(d) <: PSY.Storage)
    )
    capacity_mapping = Dict(
        PSY.get_name(d) => get_capacity(d)
        for d in PSY.get_components(PSY.StaticInjection, sys_UC) if (typeof(d) <: PSY.Generator) || (typeof(d) <: PSY.Storage)
    )
#     reg_capacity_dict = Dict(
#         PSY.get_name(d) => get_capacity(d) for d in PSY.get_components(PSY.Generator, sys_UC)
#     )
    res_mapping = Dict(
        PSY.get_name(d) => PSY.get_name.(PSY.get_services(d))
        for d in PSY.get_components(PSY.StaticInjection, sys_UC) if (typeof(d) <: PSY.Generator) || (typeof(d) <: PSY.Storage)
    )
    results_dir = sim_results.results_folder
    training_data, reg_training_data, cap_price, cap_accepted_bid = calculate_revenue(
        res_ed,
        category_dict,
        capacity_dict,
        capacity_mapping,
        bus_mapping,
        res_mapping,
        reg_capacity_dict,
        optimizer,
    )
    CSV.write(results_dir * "/training_data.csv", training_data)
    CSV.write(results_dir * "/reg_training_data.csv", reg_training_data)
    CSV.write(results_dir * "/Capacity_market_price.csv", Dict("price" => cap_price))
    CSV.write(results_dir * "/Capacity_market_accepted_bids.csv", cap_accepted_bid)
    return
end

function create_continuous_simulation(
    file_path::AbstractString,
    days::Int64,
    pruned_unit::Dict{Type{<:PSY.Component}, Array{AbstractString}},
    device_list::Dict,
    time_series_directory::AbstractString,
    rts_dir = nothing,
    load_multiplier = 1.0;
    kwargs...,
)

    rts_dir = get_rts_data(; rts_dir = rts_dir)
    rawsys = read_rts_data(rts_dir)
    simulation_name = get(kwargs, :simulation_name, "surrogate_epec")
    optimizer = get(kwargs, :optimizer, Cbc_optimizer)
    sys = PSY.System(
        rawsys;
        forecast_resolution = Dates.Hour(1),
        time_series_directory = time_series_directory,
    )
    add_copies!(sys, device_list)
    prune_system_devices!(sys, pruned_unit)
    template = create_continuous_template()
    stage = create_stage(
        template,
        sys,
        optimizer;
        constraint_duals = [
            Symbol("nodal_balance_active__PowerSystems.Bus"),
            Symbol("requirement__PowerSystems.VariableReserve_PowerSystems.ReserveDown"),
            Symbol("requirement__PowerSystems.VariableReserve_PowerSystems.ReserveUp"),
        ],
    )
    stages_definition = Dict("ED" => stage)
    sequence = PSI.SimulationSequence(
        step_resolution = Dates.Hour(24),
        order = Dict(1 => "ED"),
        horizons = Dict("ED" => 24),
        intervals = Dict("ED" => (Dates.Hour(24), PSI.Consecutive())),
        ini_cond_chronology = PSI.IntraStageChronology(),
    )
    sim = PSI.Simulation(
        name = simulation_name,
        steps = days,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
        initial_time = Dates.DateTime("2020-01-01T00:00:00"),
    )
    PSI.build!(sim)
    sim_results = PSI.execute!(sim;)
    res_ed = PSI.load_simulation_results(sim_results, "ED")
    PSI.write_to_CSV(res_ed)
    category_dict, capacity_dict, reg_capacity_dict = build_training_list(sys)
    bus_mapping = Dict(
        PSY.get_name(d) => PSY.get_name(PSY.get_bus(d))
        for d in PSY.get_components(PSY.Generator, sys)
    )
    capacity_mapping = Dict(
        PSY.get_name(d) => get_capacity(d) for d in PSY.get_components(PSY.Generator, sys)
    )
#     reg_capacity_dict = Dict(
#         PSY.get_name(d) => get_capacity(d) for d in PSY.get_components(PSY.Generator, sys)
#     )
    res_mapping = Dict(
        PSY.get_name(d) => PSY.get_name.(PSY.get_services(d))
        for d in PSY.get_components(PSY.Generator, sys)
    )
    results_dir = sim_results.results_folder
    training_data, reg_training_data, cap_price, cap_accepted_bid = calculate_revenue(
        res_ed,
        category_dict,
        capacity_dict,
        capacity_mapping,
        bus_mapping,
        res_mapping,
        reg_capacity_dict,
        optimizer,
    )
    CSV.write(results_dir * "/training_data.csv", training_data)
    CSV.write(results_dir * "/reg_training_data.csv", reg_training_data)
    CSV.write(results_dir * "/Capacity_market_price.csv", Dict("price" => cap_price))
    CSV.write(results_dir * "/Capacity_market_accepted_bids.csv", cap_accepted_bid)
    return
end
