#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/537d3a7f0bde23e62852a9bdfedf9744dd7f6aff/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p ssm-session-manager-plugin openssh
#! nix-shell -p fzf jq mktemp
##! nix-shell --pure
##! nix-shell --keep AWS_PROFILE --keep DEBUG
# add '#' for the 2 shebangs above after finishing development of the script.

set -Eeuo pipefail

source script-cook.sh

# This will contain the resulting parameters of your command
declare -a params


############################################
########## BEGIN OF CUSTOMISATION ##########
############################################

# Configure your parameters here
declare -A options=(
    [p,arg]="--profile"        [p,short]="-p" [p,required]=true  [p,value]="${AWS_PROFILE:-}" [p,desc]="aws profile"
    [i,arg]="--identity-file"  [i,short]="-i" [i,required]=false                              [i,desc]="instance connect private key"
    [n,arg]="--instance"       [n,short]="-n" [n,required]=false                              [n,desc]="instance id or instance name"
    [k,arg]="--ssh-public-key" [k,short]="-k" [k,required]=false                              [k,desc]="instance connect public key"
    [s,arg]="--ssh-args"       [s,short]="-s" [s,required]=false                              [s,desc]="ssh arguments"
    [g,arg]="--no-key-gen"     [g,short]="-g" [g,required]=false [g,tpe]="bool"               [g,desc]="don't generate one-time key"
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

- Interactively choose an ec2 instance to connect and provide an aws profile and generate a one-time key:
    $script_name --profile <aws_profile> --gen-key

- Interactively choose an ec2 instance to connect and provide an aws profile and a ssh key:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file>

- Interactively choose an ec2 instance to connect, provide an aws profile and a ssh key and forward port 8000 to localhost 58000:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file> --ssh-args "-L 58000:localhost:8000"

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instance name:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instance_name>

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instance id:
    $script_name --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instnace_id>


$(cook::usage options)

USAGE
)

# Put your script logic here
run() (
    local avail_zone instance_id profile priv_key pub_key ssh_args tmpdir

    profile="$(cook::get_str p)"
    ssh_args="$(cook::get_values_str s)"
    tmpdir="$(mktemp -d)"

    trap cleanup SIGINT SIGTERM EXIT
    cleanup() (
        echo "cleaning up $tmpdir"
        local tmp_check="$(dirname $(mktemp -u))"
        local tmpdir_check="$(dirname $tmpdir)"
        if [[ "$tmp_check" != "$tmpdir_check" ]]; then 
            echo "Keys in $tmpdir are in an unusual directory. Please remove manually."
            return 1
        fi
        if [[ -f "$tmpdir/$priv_key" ]]; then
            rm "$tmpdir/$priv_key"
        fi
        if [[ -f "$tmpdir/$pub_key" ]]; then
            rm "$tmpdir/$pub_key"
        fi
        if [[ -d "$tmpdir" ]]; then
            rm -r "$tmpdir"
        fi
    )

    if [[ "${options[g,value]:-}" == "true" ]]; then
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
    else
        echo "Generating one-time ssh key"
        priv_key="$tmpdir/aws_instance_connect"
        pub_key="${priv_key}.pub"
        ssh-keygen -q -C "$(whoami) tmp instance connect key" -f "$priv_key" -N "" -t ed25519 
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
    elif (cook::check options args); then

        cook::process options args params

        run
    fi

)

self "$@"
