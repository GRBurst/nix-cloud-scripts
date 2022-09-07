#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/537d3a7f0bde23e62852a9bdfedf9744dd7f6aff/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE
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
    [a,arg]="--additional-args"                      [a,short]="-a" [a,required]=false [a,desc]="additional delete args"
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
$script_name consists of 2 parts:
  1. Let user choose a secret by name.
  2. Deletes the secret in aws.


Usage and Examples
---------

- Choose and delete an aws secret:
    $script_name -p <aws_profile>

- Choose and delete an aws secret with additional parameters:
    $script_name -p <aws_profile> -a "--force-delete-without-recovery"


$(cook::usage options)
USAGE
)

# Put your script logic here
run() (
    local secret_name
    secret_name="$(aws secretsmanager list-secrets $(cook::get_str p) | jq -r '.SecretList | .[].Name' | fzf -1)"
    aws secretsmanager $(cook::get_str p) delete-secret --secret-id "$secret_name" $(cook::get_values_str a)
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
