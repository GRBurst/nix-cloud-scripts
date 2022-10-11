#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/3ef47c337ccf41d5e10c2ffa16f10b3f2768ae41/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
##! nix-shell --keep AWS_PROFILE
##! nix-shell --pure
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
    [p,param]="--profile"     [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,desc]="aws profile"
    [t,param]="--table-name"                               [t,short]="-t" [t,required]=false [t,desc]="dynamodb db for terraform state lock"
    [f,param]="--name-filter"                              [f,short]="-f" [f,required]=false [f,desc]="name filter"
)

# Define your usage and help message here
usage=$(cat <<-USAGE
$(cook::name) helps you to cleanup terraform state lock in dynamodb.
When the entries are represented, you can choose to delete all or confirm one at a time.
By default, you will be prompted to choose a dynamodb table containing the word 'terraform' if no table is provided.
To narrow the deletions down, you can provide a filter for state locks.

Usage and Examples
---------

- Get a prompt over all state locks and choose which to delete:
    $(cook::name) -p <aws_profile>

- Specify a different state lock table:
    $(cook::name) -p <aws_profile> -t <my-terraform-state-lock-table>

- Narrow down state lock results to those which contain a particular name:
    $(cook::name) -p <aws_profile> -f <state-lock-name-part>
USAGE
)

# Put your script logic here
run() (

    local table_name table filten_str aws_profile
    local -a db_entries

    aws_profile="$(cook::get_str p)"
    table_name="${inputs[t,value]:-}"
    filter_str="${inputs[f,value]:-}"
    table=$(aws $aws_profile dynamodb list-tables | jq -r ".TableNames | .[]" | grep -i ${table_name:-terraform} | fzf -1)
    db_entries=( $(aws $aws_profile dynamodb scan --table-name $table --expression-attribute-names '{"#name": "LockID"}' --expression-attribute-values "{\":value\":{\"S\":\"$filter_str\"}}" --filter-expression 'contains(#name, :value)' | jq -r '.Items | .[].LockID.S') )

    echo "The following entries would be deleted:"
    for entry in "${db_entries[@]}"; do
        echo "  $entry"
    done

    read -n 1 -r -p "Delete entries (y)es / (n)o / (a)ll? " ayn
    case "$ayn" in
        [Aa]* )
            printf '\n%s\n' "Deleting all entries..."
            for entry in "${db_entries[@]}"; do
                aws $aws_profile dynamodb delete-item \
                    --table-name $table \
                    --key "{ \"LockID\": {\"S\":\"$entry\"} }"
            done
            printf '\n%s\n' "Deletion finished"
            ;;
        [Yy]* )
            printf '\n%s\n' "Delete interactively..."
            for entry in "${db_entries[@]}"; do
                read -n 1 -r -p "Delete entries $entry? (y)es / (n)o" yn
                printf '\n  Deleting %s\n' "$entry"
                case "$yn" in
                    [Yy]* )
                        aws $aws_profile dynamodb delete-item \
                            --table-name $table \
                            --key "{ \"LockID\": {\"S\":\"$entry\"} }"
                        ;&
                    * )
                        continue
                esac
            done
            printf '\n%s\n' "Deletion finished"
            ;;
        * )
            printf '\n%s\n' "Nothing deleted"
            exit
            ;;
    esac

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

