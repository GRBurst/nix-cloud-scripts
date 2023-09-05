#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/63efdba0508a4625915cfe0683b45381549cafd5/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell --keep AWS_PROFILE --keep DEBUG
#! nix-shell --pure
# add '#' for the 2 shebangs above after finishing development of the script.

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
# The value can be provided by an environment variable.
#   -> In our case: [p,value]="AWS_PROFILE"
inputs_str=$(cat <<INPUTSTR
# delimiter is the first character in your table to split the variables.
# here, it is '|', because it is the first character in the column name row,
# which is starting with ' | id | tpe | ... '
# -  | named | -         | -     | -                | false    | 1     | <-- default values |
| id | tpe   | param     | short | value            | required | arity | desc               |
# ----------------------------------------------------------------------------------- #
| p |        | --profile | -p    | ${AWS_PROFILE:-} | true     |       | aws profile        |
INPUTSTR
)

# Define your usage and help message here.
# The script will append a generated parameter help message based on your inputs.
# This will be printed if the `--help` or `-h` flag is used.
usage=$(cat <<-USAGE
Template for AWS scripts.
Please have a look at template.sh as well.


Usage and Examples
---------

- Print information about aws script call:
    $(cook::name) -p ${AWS_PROFILE:-<aws_profile>}
USAGE
)

# Put your script logic here
run() (
    # Use all the parameter with the defined array params
    # aws sts get-caller-identity "${params[@]}"

    # Or access a dedicated variable array by using get_args yourself
    # local -a p_params
    # get_args p_params "p"
    # aws sts get-caller-identity "${p_params[@]}"

    # Or access a dedicated arg string (don't quote subshell)
    aws sts get-caller-identity $(cook::get_str p)

    # Or store the arg string in a variable before
    # local p="$(get_args_str p)"
    # aws sts get-caller-identity $p
)


###########################################
########## END OF CUSTOMISATION ###########
###########################################

readonly usage inputs_str

# We are passing the whole data to cook::run, where
# 1. run is your function defined above
# 2. inputs (array) or inputs_str (string) are the possible inputs you defined
# 3. params is the resulting array containing all inputs provided
# 4. usage is your usage string and will be enriched + printed on help
# 5. $@ is the non-checked input for the script
cook::run run inputs params "${inputs_str:-}" "${usage:-}" "$@"
