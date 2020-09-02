__precompile__()

module Configs
    include("utils.jl")
    using JSON, Memoize
    export  getconfig,
            setconfig!,
            hasconfig,
            initconfig

    configs = nothing
    const configs_defaultorder = [
        "default.json",
        "custom-environment-variables.json"
    ]

    function initconfig(;deployment_key = "DEPLOYMENT", configs_directory = "configs")::NamedTuple
        global configs = Dict{String, Any}()
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
        (; configs_directory = configs_directory, deployment_key = deployment_key, configs_order = configs_order)
    end

    @memoize Dict{Tuple{String}, Any} function getconfig(path::String = "")
        global configs
        configs === nothing && initconfig()
        configs isa Dict && (configs = makeimmutable(configs))
        path === "" && return configs
        epath = Meta.parse("configs.$path")
        try
            eval(epath)
        catch err
            throw(Configserror("no such config: " * path))
        end
    end

    function setconfig!(path::String, value::String)
        try
            value = JSON.parse(value)
        catch err
        end
        value = pathtodict(path, value)
        setconfig!(value)
    end
    function setconfig!(path::String, value)
        value = pathtodict(path, value)
        setconfig!(value)
    end
    function setconfig!(path::String, value::Union{Tuple, AbstractArray, NamedTuple, Dict})
        value = json(value) |> JSON.parse
        value = pathtodict(path, value)
        setconfig!(value)
    end
    function setconfig!(value::Dict)
        configs === nothing && initconfig()
        configs isa NamedTuple && throw(Configserror("""config is immutable. Please set all values before calling "get" """))
        override!(configs, value)
    end

    function hasconfig(path::String)::Bool
        path === "" && throw(Configserror("a path is required to query a config"))
        configs === nothing && initconfig()
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
    end
end
