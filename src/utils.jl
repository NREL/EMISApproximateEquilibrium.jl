function prune_system_devices!(
    sys::PSY.System,
    prune_dict::Dict{Type{<:PSY.Component}, Array{AbstractString}},
)
    for (type, device_names) in prune_dict
        for name in device_names
            device = PSY.get_components_by_name(supertype(type), sys, name)
            if !isempty(device)
                PSY.remove_component!(sys, device[1])
            end
        end
    end
    return
end

function get_rts_data(; kwargs...)
    dir = get(kwargs, :rts_dir, nothing)
    if isnothing(dir)
        if PSY.UtilsData.os == PSY.UtilsData.Windows
            rts_tempdir = download("https://github.com/GridMod/RTS-GMLC/archive/master.zip")
        else
            rts_tempdir =
                download("https://github.com/GridMod/RTS-GMLC/archive/master.tar.gz")
        end

        PSY.UtilsData.unzip(PSY.UtilsData.os, rts_tempdir, dirname(rts_tempdir))
        rts_dir = joinpath(dirname(rts_tempdir), "RTS-GMLC-master")
        return rts_dir
    else
        return dir
    end
end

function read_rts_data(rts_dir)
    rts_src_dir = joinpath(rts_dir, "RTS_Data", "SourceData")
    rts_siip_dir = joinpath(rts_dir, "RTS_Data", "FormattedData", "SIIP")

    rawsys = PSY.PowerSystemTableData(
        rts_src_dir,
        100.0,
        joinpath(rts_siip_dir, "user_descriptors.yaml"),
        timeseries_metadata_file = joinpath(rts_siip_dir, "timeseries_pointers.json"),
        generator_mapping_file = joinpath(rts_siip_dir, "generator_mapping.yaml"),
    )
    return rawsys
end

function make_tempdir(n::Int64)
    if n > 1
        outdir = [mktempdir() for ix in n]
    else
        outdir = [mktempdir()]
    end
    return outdir
end

function filter_devices(sys::PSY.System, ::Type{T}, f::Function) where {T <: PSY.Component}
    components = PSY.get_components(T, sys)
    filtered_list = filter(x -> f(x), components)
    names = PSY.get_name.(filtered_list)
    return names
end

function combvec(set_a...)
    return vec(collect(Iterators.product(set_a...)))
end

function combvec_samples(no_samples::Int, set_a...)
    set = combvec(set_a...)
    return rand(set, no_samples)
end

function uniform_sample(dict, key, size)
    data = dict[key]
    devices = length(data)
    samples = Array{AbstractString}[]
    for i in 1:devices
        for comb in collect(Combinatorics.combinations(data, i))
            push!(samples, vcat(repeat(data, size - 1), comb))
        end
    end
    return samples
end

function all_combinations(dict, key)
    data = dict[key]
    devices = length(data)
    samples = collect(Combinatorics.combinations(data))
    return samples
end

function calculate_revenue(
    results_cont,
    category_mapping,
    capacity_dict,
    capacity_mapping,
    bus_mapping,
    res_mapping,
    reg_capacity_dict,
    optimizer,
)
    nodal_prices =
        results_cont.dual_values[Symbol("dual_nodal_balance_active__PowerSystems.Bus")]
    reserve_up_prices =
        results_cont.dual_values[Symbol("dual_requirement__PowerSystems.VariableReserve_PowerSystems.ReserveUp")]
    reserve_dw_prices =
        results_cont.dual_values[Symbol("dual_requirement__PowerSystems.VariableReserve_PowerSystems.ReserveDown")]
    dispatch = hcat(
        results_cont.variable_values[Symbol("P__PowerSystems.ThermalStandard")],
        results_cont.variable_values[Symbol("P__PowerSystems.HydroEnergyReservoir")],
        results_cont.variable_values[Symbol("P__PowerSystems.RenewableDispatch")],
        results_cont.variable_values[Symbol("Pout__PowerSystems.GenericBattery")],
    )
    dispatch_rs_up = hcat(
        results_cont.variable_values[Symbol("Reg_Up_R1__PowerSystems.VariableReserve_PowerSystems.ReserveUp")],
        results_cont.variable_values[Symbol("Reg_Up_R2__PowerSystems.VariableReserve_PowerSystems.ReserveUp")],
        results_cont.variable_values[Symbol("Reg_Up_R3__PowerSystems.VariableReserve_PowerSystems.ReserveUp")],
    )
    charge = results_cont.variable_values[Symbol("Pin__PowerSystems.GenericBattery")]
    dispatch_rs_dn = hcat(
        results_cont.variable_values[Symbol("Reg_Down_R1__PowerSystems.VariableReserve_PowerSystems.ReserveDown")],
        results_cont.variable_values[Symbol("Reg_Down_R2__PowerSystems.VariableReserve_PowerSystems.ReserveDown")],
        results_cont.variable_values[Symbol("Reg_Down_R3__PowerSystems.VariableReserve_PowerSystems.ReserveDown")],
    )
    variable_cost = results_cont.variable_values[:PWL_cost_vars]
    training_data = DataFrames.DataFrame(Category = [], Revenue = [], Capacity = [])
    reg_training_data =
        DataFrames.DataFrame(Category = [], Bus = [], Revenue = [], Capacity = [])
    capex_market_bids = Vector{Vector{Union{String, Float64}}}()
    for (cat, devices) in category_mapping
        rev = Dict("Cabell" => 0.0, "Abel" => 0.0, "Bach" => 0.0)
        for d in devices
            _var_cost = 0.0
            if cat in [:ST, :CT, :CC]
                for ix in 1:4
                    _var_cost = +variable_cost[:, Symbol((d, ix))]
                end
            end
            _dispatch = dispatch[:, Symbol(d)]
            _price = abs.(nodal_prices[:, Symbol(bus_mapping[d])])
            _res_revenue = 0.0
            for res_name in res_mapping[d]
                if occursin("Reg_Up", res_name)
                    _rs_price = abs.(reserve_up_prices[:, Symbol(res_name)])
                    _res_revenue += sum(_rs_price .* dispatch_rs_up[:, Symbol(d)])
                elseif occursin("Reg_Down", res_name)
                    _rs_price = abs.(reserve_dw_prices[:, Symbol(res_name)])
                    _res_revenue += sum(_rs_price .* dispatch_rs_dn[:, Symbol(d)])
                end
            end
            if cat == :BA
                _charge = charge[:, Symbol(d)]
                rev[bus_mapping[d]] +=
                    sum(_dispatch .* _price) + _res_revenue - sum(_var_cost) -
                    sum(_charge .* _price)
                _revenue = max(
                    0,
                    capacity_mapping[d] * capex_cost[cat] - sum(_dispatch .* _price) -
                    sum(_charge .* _price) + _res_revenue - sum(_var_cost),
                )
            else
                _revenue = max(
                    0,
                    capacity_mapping[d] * capex_cost[cat] - sum(_dispatch .* _price) +
                    _res_revenue - sum(_var_cost),
                )
                rev[bus_mapping[d]] +=
                    sum(_dispatch .* _price) + _res_revenue - sum(_var_cost)
            end
            push!(
                capex_market_bids,
                [d, capacity_mapping[d] * 100.0, _revenue, derating_factors[cat]],
            )
        end
        push!(training_data, (cat, sum(values(rev)), capacity_dict[cat]))
        for bus in keys(rev)
            push!(reg_training_data, (cat, bus, rev[bus], reg_capacity_dict[cat, bus]))
        end
    end
    capacity_demand_curve = create_capacity_demand_curve("./capacity_mkt_param.csv", 8191.0)
    cap_price, cap_accepted_bid =
        capacity_market_clearing(capacity_demand_curve, capex_market_bids, optimizer)
    for row in eachrow(training_data)
        _rev = 0.0
        for d in category_mapping[row.Category]
            _rev = _rev + cap_accepted_bid[d] * 100.0 * cap_price
        end
        row.Revenue = row.Revenue + _rev
    end
    return training_data, reg_training_data, cap_price, cap_accepted_bid
end
