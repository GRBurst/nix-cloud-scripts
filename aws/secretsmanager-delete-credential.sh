#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/d40c3d5836d74e0f6249b572a1da2f1b05a6b549/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE
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
inputs=(
    [p,param]="--profile" [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,desc]="aws profile"
    [a,param]="--additional-args"                      [a,short]="-a" [a,required]=false [a,desc]="additional delete args"
)

# Define your usage and help message here
usage=$(cat <<-USAGE
$(cook::name) consists of 2 parts:
  1. Let user choose a secret by name.
  2. Deletes the secret in aws.


Usage and Examples
---------

- Choose and delete an aws secret:
    $(cook::name) -p <aws_profile>

- Choose and delete an aws secret with additional parameters:
    $(cook::name) -p <aws_profile> -a "--force-delete-without-recovery"
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

readonly usage inputs_str

# We are passing the whole data to cook::run, where
# 1. run is your function defined above
# 2. inputs (array) or inputs_str (string) are the possible inputs you defined
# 3. params is the resulting array containing all inputs provided
# 4. usage is your usage string and will be enriched + printed on help
# 5. $@ is the non-checked input for the script
cook::run run inputs params "${inputs_str:-}" "${usage:-}" "$@"

