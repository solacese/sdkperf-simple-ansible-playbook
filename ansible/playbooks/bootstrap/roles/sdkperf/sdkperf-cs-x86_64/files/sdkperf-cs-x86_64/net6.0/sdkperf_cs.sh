#!/bin/bash

# Environment variables
echo '---------------------------------------------'
echo " SOL_TOOL_PATH=$SOL_TOOL_PATH" # if not defined, we use location of script (this will be the most common usage).
echo " SOL_TOOL_VERSION=$SOL_TOOL_VERSION" 
echo " SOL_TOOL_PLATFORM=$SOL_TOOL_PLATFORM" # if not defined, linux/amd64 is default for docker.
echo " SOL_TOOL_PLATFORM_TAG=$SOL_TOOL_PLATFORM_TAG" # if not defined, default of bullseye-slim is used
echo " SOL_TOOL_SDK_VERSION=$SOL_TOOL_SDK_VERSION" # if not defined, 6.0 will be prepended to the tag
echo " SOL_WANT_ADDITIONAL_MOUNTED_DIRS=$SOL_WANT_ADDITIONAL_MOUNTED_DIRS" # if 1, user's current directory and home directory will be mounted in addition to defaults
echo " SOL_TOOL_WANT_LOCAL=$SOL_TOOL_WANT_LOCAL" 
echo " SOL_TOOL_WANT_PUBSUBTOOL=$SOL_TOOL_WANT_PUBSUBTOOL" 
echo " SOL_TOOL_EXPOSE_PORT=$SOL_TOOL_EXPOSE_PORT" 
echo " SOL_TOOL_ENV_FILE=$SOL_TOOL_ENV_FILE" 
echo " SOL_TOOL_WANT_KRB=$SOL_TOOL_WANT_KRB" 
echo " SOL_TOOL_DEBUG=$SOL_TOOL_DEBUG" 
echo '---------------------------------------------'

TOOL_OPTS_ARG=$* # Grabbing all arguments
if [[ "${TOOL_OPTS_ARG}" == *-h* ]]; then
    echo '---------------------------------------------'
    echo 'sdkperf_cs.sh Help and example values'
    echo " SOL_TOOL_PATH - The path to the tools from which to run/build"
    echo " (Eg. SOL_TOOL_PATH=/home/public/RND/loads/pubSubTools-cs/10.9.0)"
    echo " SOL_TOOL_VERSION - Used with SOL_TOOL_PATH to specify the exact version to test, otherwise uses current pointer" 
    echo " (Eg. SOL_TOOL_VERSION=10.9.0)"
    echo " SOL_TOOL_PLATFORM - Platform to run on for docker container, and deciding runtime folder"
    echo " (Eg. SOL_TOOL_PLATFORM=linux/amd64)"
    echo " SOL_TOOL_PLATFORM_TAG - Platform tag to be used with SOL_TOOL_PLATFORM"
    echo " (Eg. SOL_TOOL_PLATFORM_TAG=alpine)"
    echo " SOL_TOOL_SDK_VERSION - Dotnet version to be used in the container. If using SOL_TOOL_WANT_LOCAL then full dotnet version path is required"
    echo " (Eg. SOL_TOOL_SDK_VERSION=6.0)" # NOTE - Maybe add an example of a full dotnet version path here
    echo " SOL_WANT_ADDITIONAL_MOUNTED_DIRS - User's current directory and home directory will be mounted in addition to defaults (Needed when passing in topic files etc.)"
    echo " (Eg. SOL_WANT_ADDITIONAL_MOUNTED_DIRS=1)"
    echo " SOL_TOOL_WANT_LOCAL - Launch the tool using a local dotnet version, without creating a docker container" 
    echo " (Eg. SOL_TOOL_WANT_LOCAL=1)"
    echo " SOL_TOOL_WANT_PUBSUBTOOL - Launch pubSubTools instead of sdkperf_cs (Used by AFW)" 
    echo " (Eg. SOL_TOOL_WANT_PUBSUBTOOL=1)"
    echo " SOL_TOOL_EXPOSE_PORT - Port to expose for pubSubTool" 
    echo " (Eg. SOL_TOOL_EXPOSE_PORT=900)"
    echo " SOL_TOOL_DEBUG - Enable set -x to see what this bash script is doing (Cleared via set +x on cleanup)" 
    echo " (Eg. SOL_TOOL_DEBUG=1)"
    echo '---------------------------------------------'
fi

if [ -n "${SOL_TOOL_DEBUG}" ]; then
    set -x
fi

### Get the current absolute value of this script ### 
script_path="${BASH_SOURCE[0]}"
script_dir="$(dirname "$(readlink -f "$script_path")")" # Assumption: /home/public/RND/loads/pubSubTools-cs/branch/version
######

### Exit trap support ###
function cleanup {
    # Cleaning up any directories or created images should be done here
    if [ -n "${SOL_TOOL_DEBUG}" ]; then
        set +x
    fi
}
trap cleanup EXIT
######

# Containerization will always be used unless specified not to by SOL_TOOL_WANT_LOCAL
want_docker=true
# Detect if docker is present
docker --version > /dev/null 2>&1; # This ensures output is not printed.
if [[ $? == "127" ]]; then
    echo " ERROR: Docker must be installed in order to use a platform override, using local .NET version instead"
    want_docker=false
fi

if [ -n "${SOL_TOOL_WANT_LOCAL}" ]; then
    want_docker=false
fi

want_tty=true
if [ -n "${SOL_TOOL_WANT_PUBSUBTOOL}" ]; then
    want_tty=false
fi

### Setup/validation for docker container ###
if $want_docker; then     
    # Currently setting Dotnet version to 6.0 every run since we only support 6.0, and docker container would default to dotnet8.0 without this override.
    SOL_TOOL_SDK_VERSION="6.0"
    
    # Check for MacOS
    if [[ "$SOL_TOOL_PLATFORM" == *"darwin"* ]]; then
        echo " ERROR: No dotnet image for darwin. Cannot run in container... exiting"
        exit 1 
    fi
    
    # Unless otherwise specified, use linux/amd64 as the default platform
    if [ -z "${SOL_TOOL_PLATFORM}" ]; then 
        SOL_TOOL_PLATFORM=linux/amd64
    fi

    # Note: Possibly need to account for alpine as a default as well, need to see how AFW will be interacting with this.
    if [ -z "${SOL_TOOL_PLATFORM_TAG}" ]; then 
        SOL_TOOL_PLATFORM_TAG=bullseye-slim # default tag (supports linux/amd64 and linux/arm64/v8)
    fi

    if [ -n "${SOL_TOOL_SDK_VERSION}" ]; then 
        SOL_TOOL_PLATFORM_TAG="${SOL_TOOL_SDK_VERSION}-${SOL_TOOL_PLATFORM_TAG}" # sdk version specified, need to prepend tag name
    fi
fi
#####

### Determining the runtime folder name based on platform type ### 
if [ -n  "$SOL_TOOL_PLATFORM" ]; then
        platform_type=${SOL_TOOL_PLATFORM/\//-} # substitutes / with a - (e.g., linux/amd64 -> linux-amd64) 
        runtime_foldername=${platform_type/amd/x} # substitutes 'amd' with a 'x' (e.g., linux-amd64 -> linux-x64)
        runtime_foldername=${runtime_foldername/darwin/osx} # substitutes 'darwin' with 'osx' (e.g., darwin-x64 -> osx-x64)

        if [[ "$SOL_TOOL_PLATFORM_TAG" == *"alpine"* ]]; then
            runtime_foldername="linux-musl-x64"
            if [[ "$SOL_TOOL_PLATFORM" == *"arm64"* ]]; then
                echo " WARNING: can not run an amd64 binary on an arm64 host."
                exit 1
            fi
        fi
else 
    # Detect the platform the user is running
    if [[ "$OSTYPE" == "darwin"* ]]; then
        runtime_foldername="osx-x64"
        if [[ "$(uname -m)" == "arm64" ]]; then
            runtime_foldername="osx-arm64"      
        fi
    elif [[ "$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)" == "\"alpine\"" ]]; then
        runtime_foldername="linux-musl-x64"
    else 
        runtime_foldername="linux-x64"     
    fi
fi
######

#### Get tool path ###
# The assumption is that location of the script is within a 'loads/pubSubTools-cs' directory for a particular tool version.
# By default, we will use the location of the script to identify the desired tool version.
# SOL_TOOL_PATH and SOL_TOOL_VERSION can be used to override this behaviour to request some other specific version.
# These environment variables will be required when calling this script when it is NOT located inside the 'release' directory of a tool in 'loads/pubSubTools-cs'.
tool_version="$(basename $script_dir)" 
tool_path="$(dirname "$(readlink -f "$script_dir")")" # up to and including tool branch

if [ -n "${SOL_TOOL_PATH}" ]; then
    tool_path=$SOL_TOOL_PATH
    tool_version=current
    if [ -n "${SOL_TOOL_VERSION}" ]; then
        tool_version=$SOL_TOOL_VERSION
    fi
    tool_version=$(basename "$(readlink -f $tool_path/$tool_version)") # Dereferencing links (if any) to get version name
fi
if [ ! -d "$tool_path/$tool_version" ]; then
    echo " ERROR: Failed to find tool path ($tool_path/$tool_version), check mounts and environment variables."
    exit 1
fi
echo " Tool version: ${tool_version}" 
echo " Tool path: ${tool_path}"
echo '---------------------------------------------' 
#####

### Get Working Directory, Runtime Folder Path, and Executable File ###
# NOTE - Logic can be added here to add net8.0 as an option when it comes.
# Setting tool version name for directory specification (ie. net6.0 or net8.0)
tool_dotnet_version="net6.0"
if [ -n "${SOL_TOOL_SDK_VERSION}" ]; then
    if [[ "$SOL_TOOL_SDK_VERSION" == *"6.0"* ]]; then
        tool_dotnet_version="net6.0"
    # elif [[ "$SOL_TOOL_SDK_VERSION" == *"8.0"* ]]; then
    #     tool_dotnet_version="net8.0"
    else
        tool_dotnet_version="net6.0"
    fi
fi

# Working directory is the directory containing the binary file that needs to be executed as well as the runtimes folder.
# Regular case should be: /home/public/RND/loads/pubSubTools-cs/{branch}/{version}/release/tools/sdkperf_cs/$tool_dotnet_version
# For PubSubTool: /home/public/RND/loads/pubSubTools-cs/{branch}/{version}/internal/tools/csPubSub/$tool_dotnet_version
working_dir=$tool_path/$tool_version/release/tools/sdkperf_cs/$tool_dotnet_version
binary_filename=sdkperf_cs.dll # File is located in the working directory
runtime_dir_path=runtimes/$runtime_foldername/native # Folder is located in the working directory, ie. $working_dir/$runtime_dir_path

if [ -n "${SOL_TOOL_WANT_PUBSUBTOOL}" ]; then
    working_dir=$tool_path/$tool_version/internal/tools/csPubSub/$tool_dotnet_version
    binary_filename=csPubSub.dll
fi

# Note: we may want to search in other directories for the binary filepath and runtime folder (e.g., dist, or beside the script itself)
if [ ! -d "${working_dir}" ]; then
    echo " ERROR: Failed to find specified working directory ($working_dir)."
    exit 1
fi
if [ ! -d "${working_dir}/${runtime_dir_path}" ]; then
    echo " ERROR: Failed to find specified runtime folder ($working_dir/$runtime_dir_path)."
    exit 1
fi
if [ ! -f "${working_dir}/${binary_filename}" ]; then
    echo " ERROR: Failed to find specified binary file ($working_dir/$binary_filename)."
    exit 1
fi

echo " Tool's Dotnet version: ${tool_dotnet_version}" 
echo " Full working directory: ${working_dir}"
echo " Binary file: ${binary_filename}"
echo " Runtime folder: ${runtime_foldername}"
echo '---------------------------------------------' 
######

### Run sdkperf-cs ###
if $want_docker; then 
    echo " Starting docker container..."
    echo " Dotnet image: dotnet:${SOL_TOOL_PLATFORM_TAG}"

    # The MacOS systems do not support network host mode, also we mount the home directory higher than root
    root_prefix=""
    home_prefix=""
    private_prefix=""
    network_type="--network host"
    timeZone=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        root_prefix="/var"
        home_prefix="/System/Volumes/Data"
        private_prefix="/private"
        network_type=""
        timeZone=$(systemsetup -gettimezone | awk '{print $3}')
    else
        timeZone=$(timedatectl | grep "Time zone" | awk '{print $3}')
    fi

    # Docker container does not inherit environment vars from the host so we have to pass
    # in the one we want to set for sdkperf_cs/pubSubTools_cs 
    env_file=""
    if [ -n "${SOL_TOOL_ENV_FILE}" ]; then
        env_file="--env-file ${SOL_TOOL_ENV_FILE}"
    fi

    # When we don't run in host mode we have to expose the port running pubSubTools_cs
    exposed_ports=""
    if [ -n "$SOL_TOOL_EXPOSE_PORT" ]; then
        exposed_ports="-p ${SOL_TOOL_EXPOSE_PORT}:${SOL_TOOL_EXPOSE_PORT}"
    fi

    # Mounting binary file and /home/public directory (read-only)
    mounted_volumes="-v ${home_prefix}/home/public:/home/public:ro -v ${private_prefix}/tmp:/tmp"
    if [ "$SOL_WANT_ADDITIONAL_MOUNTED_DIRS" == 1 ]; then
        # Adding mount for current directory and home directory (read-only)
        mounted_volumes="$mounted_volumes -v $PWD:$PWD --env HOME=$HOME -v $HOME:$HOME:ro" # Removing -w $PWD since dynamic build now needs to set the working directory.
    fi

    krb_config=""
    if [ -n "$SOL_TOOL_WANT_KRB" ]; then
        krb_config="-v ${private_prefix}/etc/krb5.conf:/etc/krb5.conf -v ${root_prefix}/root:/root"
    fi

    terminal_config=""
    if $want_tty; then
        terminal_config="-it"
    fi

    # Default alpine image does not include certain libs so install them before cs run
    build_base=""
    if [[ "$SOL_TOOL_PLATFORM_TAG" == *alpine* ]]; then
        build_base="apk add build-base krb5 krb5-libs &> /dev/null && "
    fi

    cmd="${build_base}dotnet /working_dir/$binary_filename ${TOOL_OPTS_ARG}"

    echo " Platform: $SOL_TOOL_PLATFORM"
    echo " Command: $cmd"
    echo " Final Docker Run Command:"
    echo "     docker run $terminal_config --rm $network_type $exposed_ports $env_file -e TZ=${timeZone} --platform $SOL_TOOL_PLATFORM -v ${working_dir}:/working_dir ${mounted_volumes} -w /working_dir ${krb_config} mcr.microsoft.com/dotnet/sdk:$SOL_TOOL_PLATFORM_TAG /bin/sh -c \"$cmd\""
    echo '---------------------------------------------'

    docker run $terminal_config --rm $network_type $exposed_ports $env_file -e TZ=${timeZone} --platform "$SOL_TOOL_PLATFORM" -v ${working_dir}:/working_dir ${mounted_volumes} -w /working_dir ${krb_config} mcr.microsoft.com/dotnet/sdk:"$SOL_TOOL_PLATFORM_TAG" /bin/sh -c "$cmd"


# SOL_TOOL_WANT_LOCAL can be used to use an already installed dotnet version (or one from perfhostshare) and run outside of docker
else
    # Figure out which dotnet we will be using
    # NOTE - Once tool_dotnet_version is updated to be net8.0 by default, update the following to use dotnet-8.0 by default as well.
    echo "Detecting dotnet version and path to use..."
    if [ -n "$SOL_TOOL_SDK_VERSION" ] && [ -d "$SOL_TOOL_SDK_VERSION" ]; then
        dotnet_exec="${SOL_TOOL_SDK_VERSION}"  
    else
        echo " Local dotnet version path either not provided or not valid, dotnet-6.0 from perfHostShare being used."
        if [ -d "/home/public/RND/repository/perfHostShare/dotnet-6.0" ]; then
            dotnet_exec="/home/public/RND/repository/perfHostShare/dotnet-6.0"
        else
            echo " Missing dotnet runtime from perfHostShare" 
            exit 1
        fi
    fi
    
    echo "DOTNET_PATH: ${dotnet_exec}"

    export LD_LIBRARY_PATH=$working_dir/$runtime_dir_path:$LD_LIBRARY_PATH
    if [[ "$runtime_foldername" == *"osx"* ]]; then
        export DYLD_LIBRARY_PATH=$working_dir/$runtime_dir_path:$DYLD_LIBRARY_PATH
    fi
    
    echo "Running sdkperf_cs from $working_dir"
    exec "$dotnet_exec/dotnet" "$working_dir/$binary_filename" "$@"
    
fi
######