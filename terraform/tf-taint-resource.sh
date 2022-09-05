#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/refs/heads/script-cook.tar.gz
#! nix-shell -p script-cook terraform aws-vault
#! nix-shell -p fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# remove one # for the 2 shebangs above during devlopment of the script.

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail
set -Eeuo pipefail

source lib.sh

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


$(_generate_usage options)
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
    elif (check_requirements options args); then

        process_args options args params || _print_debug "Couldn't process args, terminated with $?"

        run
    else
        _print_debug "Requirements not met"
    fi

)

self "$@"
