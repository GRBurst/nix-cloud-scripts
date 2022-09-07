#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/fda2fcd73eac81495810b3748745283b6c1266ef/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p awslogs fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# add '#' for the 2 shebangs above after finishing development of the script.

set -Eeuo pipefail

source script-cook.sh

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=(
    [p,arg]="--profile" [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,desc]="aws profile"
    [s,arg]="--start"                                [s,short]="-s" [s,required]=false [s,desc]="start position"
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


$(cook::usage options)

USAGE
)

# Put your script logic here
run() (
    local profile="$(cook::get_str p)"
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
    elif (cook::check options args); then

        cook::process options args params

        run
    fi

)

self "$@"
