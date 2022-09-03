#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -p awscli2 aws-vault
#! nix-shell -p ssm-session-manager-plugin openssh
#! nix-shell -p fzf jq
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# add '#' for the 2 shebangs above after finishing development of the script.

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail
set -Eeuo pipefail

# source lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../script-cook/lib.sh"

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=(
    [p,arg]="--profile"  [p,value]="${AWS_PROFILE:-}" [p,short]="-p" [p,required]=true  [p,name]="aws profile"
    [i,arg]="--identity-file"                         [i,short]="-i" [i,required]=false [i,name]="instance connect private key"
    [n,arg]="--instance"                              [n,short]="-n" [n,required]=false [n,name]="instance id or instnace name"
    [k,arg]="--ssh-public-key"                        [k,short]="-k" [k,required]=false [k,name]="instance connect public key"
    [s,arg]="--ssh-args"                              [s,short]="-s" [s,required]=false [s,name]="ssh arguments"
)

# Define your usage and help message here
usage() (
    local script_name="${0##*/}"
    cat <<-USAGE
Interactively choose and connect to an arbitrary ec2 instance on aws.


Usage and Examples
---------

- Interactively choose an ssh key and an ec2 instance to connect and provide an aws profile and a ssh key:
    $script_name --profile <aws_profile>

- Interactively choose an ec2 instance to connect and provide an aws profile and a ssh key:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file>

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instnace name:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instance_name>

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instnace id:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instnace_id>


$(_generate_usage options)

USAGE
)

# Put your script logic here
run() (
    local avail_zone instance_id profile priv_key pub_key ssh_args

    profile="$(get_args_str p)"
    ssh_args="$(get_values_str s)"

    priv_key="$(find ~/.ssh -type f -not -iname "*.pub" | fzf -q "'${options[i,value]:-}" -1)"
    if [[ -z "${priv_key}" ]] && [[ -n "${options[i,value]}" ]]; then
        priv_key="${options[i,value]}"
    fi

    if [[ -n "${options[k,value]:-}" ]]; then
        pub_key="${options[k,value]}"
    elif [[ -z "${options[k,value]:-}" ]] && [[ -f "${priv_key}.pub" ]]; then
        pub_key="${priv_key}.pub"
    else
        pub_key="$(find ~/.ssh -type f -iname "*.pub" | fzf)"
    fi

    instance_id="$(aws $profile ec2 describe-instances --filter Name=instance-state-name,Values=running | jq -r '.Reservations[].Instances[] | [ .InstanceId, (.Tags[] | select(.Key == "Name") | .Value) ] | @tsv' | fzf -q "'${options[n,value]:-}" -1 | cut -f1)"

    avail_zone="$(aws $profile ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)"

    if [ -n "$instance_id" ]; then
        local prox_cmd="$(cat <<CMD
sh -c "aws $profile ec2-instance-connect send-ssh-public-key --instance-id %h --instance-os-user %r --ssh-public-key 'file://${pub_key}' --availability-zone '$avail_zone' && aws $profile ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
CMD
        )"

        ssh -l ec2-user -i "${priv_key}" -o ProxyCommand="$prox_cmd" $instance_id $ssh_args
    fi
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
