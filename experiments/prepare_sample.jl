using EMISApproximateEquilibrium
const SR = EMISApproximateEquilibrium
using Combinatorics
using PowerSystems
const PSY = PowerSystems

build = Dict{Type{<:PSY.Component}, Array{AbstractString}}()
build[PSY.ThermalStandard] =  repeat( ["118_CC_1", "101_CT_1", "313_CC_1", "207_CT_1", "101_STEAM_4"], 3);
build[PSY.HydroEnergyReservoir] = ["122_HYDRO_5"];
build[PSY.RenewableDispatch] = repeat(["309_WIND_1", "101_PV_4", "313_PV_1", "324_PV_3"], 3);
build[PSY.GenericBattery] = repeat(["313_STORAGE_1"], 1)
future_config_dict = Dict();
buildable_devices = Dict()
buildable_devices[PSY.ThermalStandard] =
    SR.all_combinations(build, PSY.ThermalStandard);
buildable_devices[PSY.RenewableDispatch] =
    SR.all_combinations(build, PSY.RenewableDispatch);
buildable_devices[PSY.HydroEnergyReservoir] =
    SR.all_combinations(build, PSY.HydroEnergyReservoir);
buildable_devices[PSY.GenericBattery] =
    SR.all_combinations(build, PSY.GenericBattery);

future = SR.combvec_samples(10000, 
    buildable_devices[PSY.ThermalStandard],
    buildable_devices[PSY.HydroEnergyReservoir],
    buildable_devices[PSY.RenewableDispatch],
    buildable_devices[PSY.GenericBattery],
)

build_no = 1
exp_name = "10k"
future_config_dict, sample_count = SR.update_config(future_config_dict, future, 1);
rm("./sample_configuration_$(exp_name)_$(build_no)/", force = true, recursive = true)
if !isdir(joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
    sample_configuration_dir = mkdir(joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
else
    sample_configuration_dir = (joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
end
SR.generate_configuration(sample_configuration_dir, future_config_dict)

include("./generate_jobs.jl")
generate_jobs(pwd(), "/home/sdalvi/work/RTS-GMLC", sample_count, build_no, exp_name)


#=
Jade commands to run
jade auto-config generic_command jobs.txt -c config.json
jade submit-jobs config.json \
    --output=output \
    --max-nodes=64 \
    --per-node-batch-size=1 \
    --hpc-config=hpc_config.toml
=# 
