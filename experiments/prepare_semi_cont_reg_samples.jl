using EMISApproximateEquilibrium
const SR = EMISApproximateEquilibrium
using Combinatorics
using PowerSystems
const PSY = PowerSystems
using Random
using Distributions

seed = Random.seed!(1234)

build = Dict{PSY.PrimeMovers.PrimeMover, Distributions.Distribution}()
build[PSY.PrimeMovers.CT] = Uniform(0.08, 10.0)
build[PSY.PrimeMovers.ST] =  Uniform(0.3, 20.0)
build[PSY.PrimeMovers.CC] =  Uniform(1.0, 18.0)
build[PSY.PrimeMovers.WT] =  Uniform(0.0, 15.0)
build[PSY.PrimeMovers.PVe] =  Uniform(0.0, 10.0)
build[PSY.PrimeMovers.BA] = Uniform(0.5, 15.0)
build[PSY.PrimeMovers.HY] = Uniform(0.3, 10.0)

build_no = 1
exp_name = "Reg_SC_30K"
sample_count = 30000
samples = SR.continuous_sampling_regional(build, sample_count)
rm("./sample_configuration_$(exp_name)_$(build_no)/", force = true, recursive = true)
if !isdir(joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
    sample_configuration_dir = mkdir(joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
else
    sample_configuration_dir = (joinpath(pwd(), "sample_configuration_$(exp_name)_$(build_no)"))
end
SR.generate_continuos_configuration(sample_configuration_dir, samples)
include("./generate_jobs.jl")
generate_jobs(pwd(), "/home/sdalvi/work/RTS-GMLC", sample_count, build_no, exp_name)

