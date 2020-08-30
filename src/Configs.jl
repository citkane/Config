__precompile__()

module Configs
    include("utils.jl")
    using JSON   
    export  get,
            set,
            init

    configs = nothing
    const configs_defaultorder = [
        "default.json",
        "custom-environment-variables.json"
    ]

    function resetconfigs!()
        global configs = nothing
    end

    function init(; deployment_key = "DEPLOYMENT", configs_directory = joinpath(pwd(), "configs") |> normpath)::NamedTuple
        global configs = Dict()
        configs_order = copy(configs_defaultorder)
        configs_directory = parseenvkey("CONFIGS_DIRECTORY", configs_directory)
        deployment_key = parseenvkey("DEPLOYMENT_KEY", deployment_key)
        configs_files = getfiles(configs_directory)
        deployment = parseenvkey(deployment_key, false)
        deployment != false && insert!(configs_order, 2, lowercase(deployment) * ".json")

        filter!((file)-> file in configs_files, configs_order)
        for file in configs_order
            open(joinpath(configs_directory, file), "r") do filepath
                file_content = String(read(filepath))
                newtree = JSON.parse(file_content)
                if file === "custom-environment-variables.json"
                    parsecustomenv!(newtree)
                end
                override!(configs, newtree)               
            end
        end
        (; configs_directory, deployment_key, configs_order)
    end

    function get(path::String = "")
        global configs
        configs === nothing && init()
        configs isa Dict && (configs = immutable(configs))
        path === "" && return configs
        subpaths = split(path, ".")
        ref = configs
        for subpath in subpaths
            subpath = Symbol(subpath)
            if ref isa NamedTuple && haskey(ref, subpath)
                ref = ref[subpath]
            else
                throw(Configserror("no such config: " * path))
            end
        end
        return ref
    end

    function set!(path::String, value)
        path === "" && throw(Configserror("a path is required to set a config"))
        configs === nothing && init()
        configs isa NamedTuple && throw(Configserror("""config is immutable. Please set all values before calling "get" """))
        subpaths = split(path, ".")
        ref = configs
        for i in eachindex(subpaths)
            subpath = Symbol(subpaths[i])
            length(subpaths) === i && return (ref[subpath] = value)
            haskey(ref, subpath) && !(ref[subpath] isa Dict) && (ref[subpath] = Dict())
            !haskey(ref, subpath) && (ref[subpath] = Dict())
            ref = ref[subpath]            
        end
    end

    function has(path::String)::Bool
        path === "" && throw(Configserror("a path is required to query a config"))
        configs === nothing && init()
        subpaths = split(path, ".")
        ref = configs
        for i in eachindex(subpaths)
            subpath = Symbol(subpaths[i])            
            if haskey(ref, subpath)
                length(subpaths) === i && return true
                ref = ref[subpath]
            else
                return false
            end    
        end
        true
    end
end