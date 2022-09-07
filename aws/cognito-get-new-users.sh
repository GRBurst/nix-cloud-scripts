#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/fda2fcd73eac81495810b3748745283b6c1266ef/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
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
    [d,arg]="--days"                                 [d,short]="-d" [d,required]=false [d,desc]="days"
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
Return up to 60 emails that have registered in last x days.
The first parameters determines the number of days to look back and defaults to 1 week (7 days).
Uses unix date (which has to be installed explicitly if you are a mac user).


Usage and Examples
---------

- Return a list of emails that have registered in the last 7 days (default):
    $script_name -p <aws_profile>

- Return a list of emails that have registered in the last 14 days:
    $script_name --profile <aws_profile> --days 14


$(cook::usage options)
USAGE
)

# Put your script logic here
run() (
    local profile="$(cook::get_str p)"
    local days="$(cook::get_str d)"

    local user_pool="$(aws cognito-idp list-user-pools --max-results 60 $profile | jq -r '.UserPools | .[] | [.Name, .Id] | @tsv' | fzf | cut -f2)"
    local filter_date="$(date +%Y-%m-%d'T'%H:%M'Z' -d "${days:-7} days ago")"
    aws cognito-idp list-users --user-pool-id "$user_pool" --attributes-to-get "email" $profile | jq --arg date "$filter_date" '.Users | .[] | select( $date < .UserCreateDate) | .Attributes | .[].Value' | awk '{printf "%d: %s\n",NR,$0}'
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
