#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/3ef47c337ccf41d5e10c2ffa16f10b3f2768ae41/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
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

# Configure your parameters here
inputs_str=$(cat <<INPUTSTR
# delimiter is the first character in your table to split the variables.
# here, it is '|', because it is the first character in the column name row,
# which is starting with ' | id | tpe | ... '
# -  | named  | -         | -     | -                | false    | 1     | <-- default values |
| id | tpe    | param     | short | value            | required | arity | desc               |
# -------------------------------------------------------------------------------------- #
| p  |        | --profile | -p    | ${AWS_PROFILE:-} | true     |       | aws profile        |
| e  |        | --email   | -e    |                  | true     |       | cognite user email |
INPUTSTR
)

# Define your usage and help message here
usage=$(cat <<-USAGE
Get the sub id and e-mail of a cognito user by providing an e-mail.
More precisely, it is checked whether the e-mail starts with --email.


Usage and Examples
---------

- Return the sub of a user with the email "me@example.com":
    $(cook::name) --profile <aws_profile> --email me@example.com
USAGE
)

# Put your script logic here
run() (
    local profile="$(cook::get_str p)"
    local email="$(cook::get_values_str e)"

    local user_pool="$(aws cognito-idp list-user-pools $profile --max-results 60 | jq -r '.UserPools | .[] | [.Name, .Id] | @tsv' | fzf | cut -f2)"

    aws cognito-idp list-users $profile --user-pool-id "$user_pool" --attributes-to-get "sub" "email" | jq -r ".Users | .[] | .Attributes | select(.[].Value | startswith(\"$email\")) | map(.Value) | @tsv"
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

