#Capacity Market Clearing Module

# Capacity demand curve creator
function create_capacity_demand_curve(
    input_file::String,
    system_peak_load::Float64,
)

# Gather parameter data                                    
capacity_demand_params = read_data(input_file)[1, :]
fpr = capacity_demand_params["Forecast Pool Req"] #Forecast Pool Req
rel_req = system_peak_load * fpr  # Reliability Requirement
irm = capacity_demand_params["IRM"] # Installed Reserve Margin
irm_perc_points = parse.(Float64, split(capacity_demand_params["IRM perc points"], ";")) #Installed Reserve Margin percentage points

net_CONE = capacity_demand_params["Net CONE per day"] * 365  # Net CONE
net_CONE_perc_points = parse.(Float64, split(capacity_demand_params["Net CONE perc points"], ";")) #Net CONE percentage points    

@assert length(net_CONE_perc_points) == length(irm_perc_points)

gross_CONE_value = capacity_demand_params["Gross CONE per day"] * 365   # Gross CONE
gross_CONE_points = zeros(length(net_CONE_perc_points))
gross_CONE_points[1] = gross_CONE_value

max_clear = capacity_demand_params["Max Clear"]

# Construct demand curve
demand_curve_break_points = zeros(length(net_CONE_perc_points) + 2)
demand_curve_price_points = zeros(length(net_CONE_perc_points) + 2)

demand_curve_break_points[1] = 0.0
demand_curve_price_points[1] = net_CONE*net_CONE_perc_points[1]

demand_curve_break_points[end] = rel_req * max_clear
demand_curve_price_points[end] = 0.0

# Demand curve points based on PJM capacity market
for i in 1:(length(net_CONE_perc_points))
demand_curve_break_points[i + 1] = rel_req * ( 1 + irm + irm_perc_points[i]) / ( 1 + irm)
demand_curve_price_points[i + 1] = max(net_CONE * net_CONE_perc_points[i], gross_CONE_points[i])
end

capacity_demand_curve = CapacityMarket(demand_curve_break_points, demand_curve_price_points)
return capacity_demand_curve
end

"""
#Construct VRR Curve
VRR_curve_points = [[(rel_req*(1+irm+irm_perc_points[i])/(1+irm)+ee_add_back), 
max(net_CONE*net_CONE_perc_points[i],gross_CONE[i])] for i =1:length(irm_perc_points)];
pushfirst!(VRR_curve_points,[0, max(net_CONE*net_CONE_perc_points[1],gross_CONE[1])])
push!(VRR_curve_points,[rel_req+25000, 0])
"""
function capacity_market_clearing(
    demand_curve::CapacityMarket,
    supply_curve::Vector{Vector{Union{String, Float64}}},
    optimizer::JuMP.MOI.OptimizerWithAttributes,
)

"""
Each Element of the Supply Curve:
[1] - Project Name
[2] - Project Size
[3] - Project Capacity Bid
[4] - Project Derating Factor
"""

demand_segmentsize, demand_segmentgrad, demand_pricepoints = makecapacitydemand(demand_curve)

#Number of segments of capacity supply and demand curves
n_demand_seg = length(demand_segmentsize);
n_supply_seg = length(supply_curve);

#----------Capacity Market Clearing Problem---------------------------------------------------------------------------------
cap_mkt = JuMP.Model(optimizer);

#Define the variables
JuMP.@variables(cap_mkt, begin
Q_supply[s=1:n_supply_seg] >= 0 # Quantity of cleared capacity supply offers
Q_demand[d=1:n_demand_seg] >= 0 # Quantity of cleared capacity demand from the demand curve           
end)

#Functions----------------------------------------------------------------------------------------

#Cost of procuring capacity supply for each segment
supply_cost(Q_seg, s) = supply_curve[s][3] * Q_seg;

#Welfare from meeting the capacity resource requirement for each segment
demand_welfare(Q_seg, d) = demand_pricepoints[d] * Q_seg + 0.5 * demand_segmentgrad[d] * (Q_seg^2);        

#Expressions---------------------------------------------------------------------------------------

#Totoal Cost of procuring capacity supply
JuMP.@expression(cap_mkt, total_supply_cost, sum(supply_cost(Q_supply[s], s) for s = 1:n_supply_seg))

#Total Welfare from meeting the capacity resource requirement
JuMP.@expression(cap_mkt, total_dem_welfare, sum(demand_welfare(Q_demand[d], d) for d = 1:n_demand_seg))   

#Constraints--------------------------------------------------------------------------------------

#Cleared capacity supply limit for each segment
JuMP.@constraint(cap_mkt, [s=1:n_supply_seg], Q_supply[s] <= supply_curve[s][2])

#Cleared demand limit for each segment
JuMP.@constraint(cap_mkt, [d=1:n_demand_seg], Q_demand[d] <= demand_segmentsize[d])

#Total cleared capacity supply should meet the total cleared demand
JuMP.@constraint(cap_mkt, mkt_clear, sum(Q_supply[s] * supply_curve[s][4] for s in 1:n_supply_seg) == sum(Q_demand))

#Define Objective Function - Social Welfare Maxmization
JuMP.@objective(cap_mkt, Max, total_dem_welfare - total_supply_cost)

println("Actual Capacity Market Clearing:")
JuMP.optimize!(cap_mkt)
println(JuMP.termination_status(cap_mkt))
println(JuMP.objective_value(cap_mkt))

#Capacity Market Clearing Price is the shadow variable of the capacity balance constraint
cap_price = JuMP.dual(mkt_clear)
cap_accepted_bid = Dict(supply_curve[s][1] => JuMP.value.(Q_supply[s]) / supply_curve[s][2]  for s in 1:n_supply_seg)
#------------------------------------------------------------------------------------------------
return cap_price, cap_accepted_bid

end
