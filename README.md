# Configs.jl

## Opinionated tool for managing deployment configurations

Configurations are loaded by cascading overrides.  
These are defined in JSON files placed in a configurable folder location.

Further configurations can be added or overridden from your code.  
This allows for example, setting configurations from asynchronous sources.
```julia
Configs.set!("database.connection.port", 3900)
```


The syntax for accessing configurations is minimal:
```julia
password = Configs.get("database.credentials.password")
credentials = Configs.get("database.credentials")
username = credentials.username
password = credentials.password
```

Accessing non-existent configurations will throw an error, so:
```julia
if Configs.has("database.credentials.password")
    password = Configs.get("database.credentials.password")
end
```


**Immutability:**  
After the first call to ```Configs.get``` or ```Configs.has```, the configuration is immutable. Thus, you can not call ```set!``` after calling ```get``` or ```has```. It will throw an error.

Conversely stated, you must complete all your ```set!``` calls before accessing with ```get``` or ```has```.

## Installation
```bash
$> cd my/project/rootdir
$> julia --project=.
julia> ]
pkg> add Configs
```
## Usage
```bash
#This is optional. The default configs folder is expected to be at <my/project/rootdir>/configs.
#Will throw an error if no valid configs folder is found or provided
$> cd my/project/rootdir
$> mkdir configs
```
```julia
using Configs

#OPTIONAL custom init
Configs.init(; deployment_key="MY_ENV", configs_directory="relative_or_absolute/custom/configdirectory") 
# default deployment_key = "DEPLOYMENT"
# default configs_directory = "<project rootdirectory>/configs"

value = "item result from some asynchronous call"

Configs.set!("path.to.new", value)
Configs.set!("path.to.override", value)

newvalue = Configs.get("path.to.new")
overriddenvalue = Configs.get("path.to.override")

port = Configs.get("database.connection.port")
# OR
database = Configs.get("database")
port = database.connection.port

# After the first call to get, configs are immutable, so:

Configs.set!("database.connection.port", 8000) # Throws an error if called here
```
Alternatively, a custom init can be defined through ENV:
```bash
$> cd my/project/rootdir

$> DEPLOYMENT_KEY=MY_ENV CONFIGS_DIRECTORY=custom/configdirectory julia --project=. src/project.jl
```
```DEPLOYMENT_KEY``` defines which ```ENV``` key is used to state the deployment environment [development, staging, production, etc...]. The default is ```ENV["DEPLOYMENT"]```.
## JSON file definitions:

These provide cascading overrides in the order shown below: 

### [1] ```configs/default.json```
Define public configs. This is suitable for eg. storing in a public code repository.
```json
{
    "database": {
        "connection": {
            "url": "http://localhost",
            "port": 3600
        },
        "credentials": {
            "username": "guest",
            "password": "guestuserdefault"
        }
    },
    "otherstuff": {
        "defaultmessage": "Hello new user"
    }
}
```
### [2] ```configs/<deployment>.json```
Typically, would be:
- development.json
- staging.json
- production.json
- testing.json

Define semi private, deployment specific overrides. This would typically have a .gitignore exclusion, or be stored in a private repository only.


```json
{
    "database": {
        "connection": {
            "url": "https://secureserver.me/staging",
            "port": 3601
        },
        "credentials": {
            "username": "stagingadmin",
            "password": ""
        }
    }
}
```
The file is named in lowercase to correspond with any ```ENV["DEPLOYMENT"]``` found at runtime. Thus, running:
```bash
DEPLOYMENT=PrOdUcTiOn julia --project=. src/myproject.jl
```
would merge the configuration defined in ```production.json```

### [3] ```configs/custom-environment-variables.json```
Define private overides. This maps ENV variables to configuration variables.

```json
{
    "database": {
        "credentials": {
            "password": "DATABASE_PASSWORD"
        }
    }
}
```
Private variables are thus passed in explicitly by, for example, defining the environment variable in BASH.
```bash
DATABASE_PASSWORD=mysupersecretpasword julia --project=. src/myproject.jl
```
```julia
using Configs
password = Configs.get("database.credentials.password")
# password === "mysupersecretpasword"
```

## Footnote
This is a deployment methodology cloned from the excellent node.js [config](https://www.npmjs.com/package/config) package.