#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/refs/heads/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p jq fzf
##! nix-shell --keep AWS_PROFILE
##! nix-shell --pure
# add '#' for the 2 shebangs above after finishing development of the script.

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail
set -Eeuo pipefail

source lib.sh

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=(
    [p,arg]="--profile"     [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,name]="aws profile"
    [t,arg]="--table-name"                               [t,short]="-t" [t,required]=false [t,name]="dynamodb db for terraform state lock"
    [f,arg]="--name-filter"                              [f,short]="-f" [f,required]=false [f,name]="name filter"
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
$script_name consists of 2 parts:
  1. Let user choose a secret by name.
  2. Deletes the secret in aws.


Usage and Examples
---------

- Choose and delete an aws secret:
    $script_name -p <aws_profile>

- Choose and delete an aws secret with additional parameters:
    $script_name -p <aws_profile> -a "--force-delete-without-recovery"


$(_generate_usage options)
USAGE
)

# Put your script logic here
run() (

    local table_name table filten_str aws_profile
    local -a db_entries

    aws_profile="$(get_args_str p)"
    table_name="${options[t,value]}"
    filter_str="${options[f,value]}"
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
            exit
            ;;
    esac

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
