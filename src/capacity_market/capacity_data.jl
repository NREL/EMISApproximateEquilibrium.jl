function makecapacitydemand(capmarket::CapacityMarket)
    breakpoints =  getproperty(capmarket, :breakpoints)
    pricepoints =  getproperty(capmarket, :pricepoints)
    num_segments = length(breakpoints) - 1
    segment_size = zeros(num_segments) 
    segment_grad = zeros(num_segments)  
         for segment in 1:num_segments
            segment_size[segment] = breakpoints[segment + 1] - breakpoints[segment]
            segment_grad[segment] = (pricepoints[segment + 1] - pricepoints[segment]) /  segment_size[segment]
         end

    return segment_size, segment_grad, pricepoints
 end

 function read_data(file_name::String) 
    projectdata = DataFrames.DataFrame(CSV.File(file_name; 
                        truestrings=["T", "TRUE", "true"], 
                        falsestrings=["F", "FALSE", "false"]));
    return projectdata
end
