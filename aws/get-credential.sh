#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --pure
#! nix-shell --keep AWS_PROFILE
#! nix-shell -p awscli2 aws-vault
#! nix-shell -p jq fzf xclip

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
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
$script_name consists of 2 parts:
  1. Let user choose a secret by name.
  2. Get the secret and copy it to your clipboard.


Usage and Examples
---------

- Choose and copy an aws secret to your clipboard:
    $script_name -p <aws_profile>


$(_generate_usage options)
USAGE
)

# Put your script logic here
run() (

    secret_name="$(aws secretsmanager list-secrets "${params[@]}" | jq -r '.SecretList | .[].Name' | fzf)"
    aws secretsmanager "${params[@]}" get-secret-value --version-stage AWSCURRENT --secret-id "$secret_name" | jq -r '.SecretString | fromjson | .password' | xclip
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

self $@
