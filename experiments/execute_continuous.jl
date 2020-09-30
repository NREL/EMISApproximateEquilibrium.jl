using ArgParse
using EMISApproximateEquilibrium
const SR = EMISApproximateEquilibrium

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--build"
        help = "an flag to indicate is Simulation will be adding/building or removing devices to the system"
        action = :store_true
        "data_dir"
        help = "directory where the System data is stored"
        required = true
        "output_dir"
        help = "directory to store PowerSimulation Result"
        required = true
        "sample_dir"
        help = "directory where sample configuration infromation is stored"
        required = true
        "sample_no"
        help = "the sample or configuration number "
        required = true
        "build_no"
        help = "the build number "
        required = true
        "exp_name"
        help = "the experiment name "
        required = true
        "--load_growth"
        help = "mulitpler for load growth"
        arg_type = Float64
        default = 1.0
    end

    return parse_args(s)
end

function main()
    # parse command line args
    parsed_args = parse_commandline()
    args_dict = Dict()
    for (arg, val) in parsed_args
        args_dict[arg] = val
    end

    outdir = joinpath(
        args_dict["output_dir"],
        "sample_configuration_$(args_dict["exp_name"])_$(args_dict["build_no"])_$(args_dict["sample_no"])",
    )
    if !isdir(outdir)
        file_path = mkdir(outdir)
    end
    data_dir = args_dict["data_dir"]
    load_growth = args_dict["load_growth"]
    devices_added = []
    devices_deleted = []
    include(joinpath(
        args_dict["sample_dir"],
        "sample_configuration_$(args_dict["sample_no"]).jl",)
    )
    devices_added = Input.devices_added
    devices_deleted = Input.devices_deleted
    SR.create_continuous_simulation(
        outdir,
        364,
        devices_deleted,
        devices_added,
        "/tmp/scratch",
        data_dir,
        load_growth;
        simulation_name = "sample_$(args_dict["exp_name"])_$(args_dict["build_no"])_$(args_dict["sample_no"])",
    )
    training_dir =  joinpath("/home/sdalvi/work/scratch",
        "sample_configuration_$(args_dict["exp_name"])_$(args_dict["build_no"])_$(args_dict["sample_no"])/")
    if !isdir(training_dir)
        file_path = mkdir(training_dir)
    end
    src_dir = joinpath(outdir, "sample_$(args_dict["exp_name"])_$(args_dict["build_no"])_$(args_dict["sample_no"])/1/results/")
    run(`rsync -azp $src_dir $training_dir`)
end

main()

