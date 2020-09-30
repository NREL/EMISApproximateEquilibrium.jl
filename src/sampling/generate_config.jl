import Mustache

template = """
#=
This file is auto-generated. Do not edit.
=#
module Input

import PowerSystems
const PSY = PowerSystems
import EMISApproximateEquilibrium
const SR = EMISApproximateEquilibrium
 
devices_added = SR.ConfigDataContainer()
{{#types}}
devices_added[PSY.{{type}}] = {{{config}}}
{{/types}}
devices_deleted  = SR.ConfigDataContainer()

devices_deleted[PSY.ThermalStandard] = [
    "115_STEAM_1",
    "115_STEAM_2",
    "315_STEAM_1",
    "315_STEAM_2",
    "315_STEAM_3",
    "315_STEAM_4",
    "315_STEAM_5",
    "107_CC_1",
    "113_CT_1",
    "113_CT_2",
    "113_CT_3",
    "113_CT_4",
    "207_CT_2",
    "213_CC_3",
    "213_CT_1",
    "213_CT_2",
    "307_CT_2",
    "313_CC_1",
    "315_CT_6",
    "315_CT_7",
    "315_CT_8",
    "318_CC_1",
    "323_CC_1",
    "323_CC_2",
    "218_CC_1",
    "118_CC_1",
    "101_CT_1",
    "101_CT_2",
    "102_CT_1",
    "102_CT_2",
    "201_CT_1",
    "201_CT_2",
    "202_CT_1",
    "202_CT_2",
    "301_CT_1",
    "301_CT_2",
    "302_CT_1",
    "302_CT_2",
    "207_CT_1",
    "307_CT_1",
    "101_STEAM_4",
    "214_SYNC_COND_1",
    "114_SYNC_COND_1",
]
devices_deleted[PSY.RenewableFix] = [
    "308_RTPV_1",
    "313_RTPV_1",
    "313_RTPV_2",
    "313_RTPV_3",
    "313_RTPV_4",
    "313_RTPV_5",
    "313_RTPV_6",
    "313_RTPV_7",
    "313_RTPV_8",
    "313_RTPV_9",
    "313_RTPV_10",
    "313_RTPV_11",
    "313_RTPV_12",
    "320_RTPV_1",
    "320_RTPV_2",
    "320_RTPV_3",
    "313_RTPV_13",
    "320_RTPV_4",
    "320_RTPV_5",
    "118_RTPV_1",
    "118_RTPV_2",
    "118_RTPV_3",
    "118_RTPV_4",
    "118_RTPV_5",
    "118_RTPV_6",
    "320_RTPV_6",
    "118_RTPV_7",
    "118_RTPV_8",
    "118_RTPV_9",
    "118_RTPV_10",
    "213_RTPV_1",
]

devices_deleted[PSY.RenewableDispatch] = ["309_WIND_1", "212_CSP_1", "317_WIND_1", "122_WIND_1",
"313_PV_1", "314_PV_3","313_PV_2", "312_PV_1", "319_PV_1","215_PV_1", "212_CSP_1"]
devices_deleted[PSY.GenericBattery] = ["313_STORAGE_1"]
devices_deleted[PSY.HydroDispatch] = [
    "122_HYDRO_5",
    "122_HYDRO_6",
    "201_HYDRO_4",
    "215_HYDRO_3",
    "222_HYDRO_3",
    "222_HYDRO_4",
    "222_HYDRO_5",
    "222_HYDRO_6",
]
end
"""

function generate_configuration(directory, future_config_dict)
    for (id, config) in future_config_dict
        item = Dict()
        params = Vector{Dict}()
        for (type, devices) in config
            if !isempty(devices)
                tmptype = Dict("type" => type, "config" => devices)
                push!(params, tmptype)
            end
        end
        item["types"] = params
        filename = joinpath(directory, "sample_configuration_$(id).jl")
        open(filename, "w") do io
            write(io, Mustache.render(template, item))
        end
        println("Wrote $filename")
    end
    return
end
