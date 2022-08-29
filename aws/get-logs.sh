#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --keep AWS_PROFILE
#! nix-shell -p awscli2 aws-vault
#! nix-shell -p awslogs fzf

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail
set -Eeuo pipefail

# cd to script location
cd "$(dirname "${BASH_SOURCE[0]}")"

source ./script-cook/lib.sh


# Configure your parameters here. The provided 
declare -A get_logs_options=(
    [p,arg]="--profile" [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,name]="aws profile"
    [s,arg]="--start"                                [s,short]="-s" [s,required]=false [s,name]="start position"
)
# This will contain the resulting parameters of your command
declare -a get_logs_params

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE

Choose an aws log group and watch the logs.


Usage and Examples
-----

- Choose aws log group and the logs:
    $script_name


$(_generate_usage get_logs_options)

USAGE
)

# Put your script logic here
run() (
    # Use all the parameter with the defined array get_logs_params
    local -a p_params
    get_args p_params "p"
    echo "all ${get_logs_params[@]}"
    echo "p ${p_params[@]}"

    local group=$(awslogs groups "${p_params[@]}" | fzf)
    if [[ -n "$group" ]]; then
        echo "awslogs get --watch $group --no-group --no-stream ${get_logs_params[@]}"
        awslogs get --watch $group --no-group --no-stream "${get_logs_params[@]}"
    fi
)


# This is the base frame and it shouldn't be necessary to touch it
self() (
    declare -a args=( "$@" )
    if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
    elif (check_requirements get_logs_options args); then

        process_args get_logs_options args get_logs_params || _print_debug "Couldn't process args, terminated with $?"

        run
    else
        _print_debug "Requirements not met"
    fi

)

self "$@"
