#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p awscli2 aws-vault
#! nix-shell -p awslogs fzf

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail
set -Eeuo pipefail

# cd to script location
cd "$(dirname "${BASH_SOURCE[0]}")"

source ../script-cook/lib.sh

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=(
    [p,arg]="--profile" [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,name]="aws profile"
    [s,arg]="--start"                                [s,short]="-s" [s,required]=false [s,name]="start position"
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
Choose an aws log group and watch the logs.


Usage and Examples
---------

- Choose aws log group and the logs and provide a profile:
    $script_name -p <aws_profile>


$(_generate_usage options)

USAGE
)

# Put your script logic here
run() (
    local profile="$(get_args_str p)"
    local group="$(awslogs groups $profile | fzf)"
    if [[ -n "$group" ]]; then
        awslogs get --watch "$group" --no-group --no-stream "${params[@]}"
    fi
)


############################################
########### END OF CUSTOMISATION ###########
############################################

# This is the base frame and it shouldn't be necessary to touch it
self() (
    declare -a args=( "$@" )
    if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
    elif (check_requirements options args); then

        process_args options args params || _print_debug "Couldn't process args, terminated with $?"

        run
    else
        _print_debug "Requirements not met"
    fi

)

self "$@"