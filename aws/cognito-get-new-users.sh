#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/d40c3d5836d74e0f6249b572a1da2f1b05a6b549/script-cook.tar.gz
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
inputs=(
    [p,param]="--profile" [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,desc]="aws profile"
    [d,param]="--days"                                 [d,short]="-d" [d,required]=false [d,desc]="days"
)

# Define your usage and help message here
usage=$(cat <<-USAGE
Return up to 60 emails that have registered in last x days.
The first parameters determines the number of days to look back and defaults to 1 week (7 days).
Uses unix date (which has to be installed explicitly if you are a mac user).


Usage and Examples
---------

- Return a list of emails that have registered in the last 7 days (default):
    $(cook::name) -p <aws_profile>

- Return a list of emails that have registered in the last 14 days:
    $(cook::name) --profile <aws_profile> --days 14
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

readonly usage inputs_str

# We are passing the whole data to cook::run, where
# 1. run is your function defined above
# 2. inputs (array) or inputs_str (string) are the possible inputs you defined
# 3. params is the resulting array containing all inputs provided
# 4. usage is your usage string and will be enriched + printed on help
# 5. $@ is the non-checked input for the script
cook::run run inputs params "${inputs_str:-}" "${usage:-}" "$@"

