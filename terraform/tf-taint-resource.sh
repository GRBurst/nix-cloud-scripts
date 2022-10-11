#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/3ef47c337ccf41d5e10c2ffa16f10b3f2768ae41/script-cook.tar.gz
#! nix-shell -p script-cook terraform aws-vault
#! nix-shell -p fzf
#! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# remove one # for the 2 shebangs above during devlopment of the script.

set -Eeuo pipefail
declare -r VERSION="1.0.0"

declare -r script_path="$(dirname "${BASH_SOURCE[0]}")"
# This is for compatibility to run it without a nix-shell
if command -v script-cook.sh &> /dev/null; then
    source script-cook.sh
else
    source "$script_path/../script-cook/bin/script-cook.sh"
fi

declare -A inputs  # Define your inputs below
declare inputs_str # Alternatively define them in a string matrix
declare usage      # Define your usage + examples below
declare -a params  # Holds all input parameter


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your inputs, parameters and arguments here.
inputs=()

# Define your usage and help message here.
# The script will append a generated parameter help message based on your inputs.
# This will be printed if the `--help` or `-h` flag is used.
usage=$(cat <<-USAGE
Choose an instance interactively and taint it.

Usage and Examples
---------

- Run:
    $(cook::name)
USAGE
)

# Put your script logic here
run() (
    terraform taint $(terraform state list | fzf)
)


############################################
########### END OF CUSTOMISATION ###########
############################################

readonly usage inputs_str

# We are passing the whole data to cook::run, where
# 1. run is your function defined above
# 2. inputs (array) or inputs_str (string) are the possible inputs you defined
# 3. params is the resulting array containing all inputs provided
# 4. usage is your usage string and will be enriched + printed on help
# 5. $@ is the non-checked input for the script
cook::run run inputs params "${inputs_str:-}" "${usage:-}" "$@"
