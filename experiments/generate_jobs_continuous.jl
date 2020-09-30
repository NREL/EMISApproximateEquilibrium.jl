using Mustache

template = """
{{#jobs}} 
julia --project experiments/execute_continuous.jl  {{{arg}}}
{{/jobs}}
"""

function generate_jobs_continuous(directory, data_dir, no_samples, build_no, exp_name)
    items = Dict()
    jobs = Vector{Dict}()
    for ix in 1:no_samples
        args = """ --build "$(data_dir)" "/tmp/scratch/" "/home/sdalvi/work/Surrogate/sample_configuration_$(exp_name)_$(build_no)/" $ix $build_no $exp_name """
        push!(jobs, Dict("arg" => args))
    end
    items["jobs"] = jobs
    filename = joinpath(directory, "jobs.txt")
    open(filename, "w") do io
        write(io, Mustache.render(template, items))
    end
    println("Wrote $filename")
    return
end
