#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/fda2fcd73eac81495810b3748745283b6c1266ef/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf xclip
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


$(cook::usage options)
USAGE
)

# Put your script logic here
run() (

    local secret_name
    secret_name="$(aws secretsmanager list-secrets "${params[@]}" | jq -r '.SecretList | .[].Name' | fzf)"
    aws secretsmanager "${params[@]}" get-secret-value --version-stage AWSCURRENT --secret-id "$secret_name" | jq -r '.SecretString | fromjson | .password' | xclip -selection clipboard
    echo "Copied credential to clipboard"
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
