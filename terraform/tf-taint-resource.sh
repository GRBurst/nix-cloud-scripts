#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/fda2fcd73eac81495810b3748745283b6c1266ef/script-cook.tar.gz
#! nix-shell -p script-cook terraform aws-vault
#! nix-shell -p fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# remove one # for the 2 shebangs above during devlopment of the script.

set -Eeuo pipefail

source script-cook.sh

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=()

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
Choose an instance interactively and taint it.


Usage and Examples
---------

- Run:
    $script_name


$(cook::usage options)
USAGE
)

# Put your script logic here
run() (

    terraform taint $(terraform state list | fzf)
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
