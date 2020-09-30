struct CapacityMarket # Assumes a piece-wise linear demand curve
    
    breakpoints::Vector{Float64}   # demand curve break points
    pricepoints::Vector{Float64}    # $/MW-year

    function CapacityMarket(b, p)
        @assert all(b .>= 0)
        @assert all(p .>= 0)
        @assert length(b) > 1
        @assert length(p) == length(b)
        new(b, p)
    end

end
