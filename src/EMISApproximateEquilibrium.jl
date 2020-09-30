isdefined(Base, :__precompile__) && __precompile__()

"""
Module for constructing self-contained investment system objects.
"""

module EMISApproximateEquilibrium

#################################################################################
# Exports

export CapacityMarket
export capacity_market_clearing
export create_capacity_demand_curve
export makecapacitydemand

export read_data
export make_copy
export set_uuid!
export set_device_name!
export prune_system_devices!
export add_copies!
export get_rts_data
export make_tempdir
export filter_devices
export ConfigDataContainer
export update_config
export combvec
export uniform_sample

export create_uc_template
export create_ed_template
export create_stage
export create_sequence
export create_simulation
export get_capacity
export calculate_revenue
export build_training_list


export all_combinations
export combvec_samples

export capex_cost
export derating_factors

export generate_continuos_configuration
export generate_regional_semi_discrete_configuration
export generate_configuration

### Continuous builds
export make_continuous_device
export add_continous_copies!
export ContinuousBuildContainer
export update_continuous_samples
export continuous_sampling
export create_continuous_simulation
export create_continuous_template
export make_continuous_ct
export make_continuous_cc
export make_continuous_st
export make_continuous_wt
export make_continuous_pv
export _make_device
export check_service

### Semi-discrete builds
export _make_device_semi_discrete
export make_semi_discrete_hy
export add_device_hy
export make_semi_discrete_bat
export add_device_bat
export make_semi_discrete_pv
export make_semi_discrete_wt
export add_device_renewable
export make_semi_discrete_st
export add_device_st
export make_semi_discrete_cc
export add_device_cc
export make_semi_discrete_ct
export add_device_ct


### Regional builds
export continuous_sampling_regional
export update_continuous_reg_samples
export _make_device_semi_discrete_regional
export make_semi_discrete_regional_hy
export make_semi_discrete_regional_bat
export make_semi_discrete_regional_pv
export make_semi_discrete_regional_wt
export make_semi_discrete_regional_st
export make_semi_discrete_regional_cc
export make_semi_discrete_regional_ct
export ContinuousRegionalBuildContainer



#################################################################################
# Imports

import PowerSystems
import PowerSimulations
import InfrastructureSystems
import JuMP
import Dates
import Random
import UUIDs
import DataFrames
import CSV
import Distributions
const PSY = PowerSystems
const PSI = PowerSimulations
const IS = InfrastructureSystems

import GLPK
import Cbc
import Combinatorics
import ArgParse
import Mustache

Random.seed!(1234)

const Glpk_optimizer =
    JuMP.optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.MSG_ON)
const Cbc_optimizer =
    JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.5)
#################################################################################
# Includes

include("capacity_market/include.jl")
include("definations.jl")
include("utils.jl")
include("devices/continous_devices.jl")
include("devices/semi-discrete_devices.jl")
include("simulation.jl")
include("sampling/generate_config.jl")
include("sampling/generate_continuous_config.jl")
include("sampling/generate_regional_semi_discrete_config.jl")

end # module
