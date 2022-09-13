#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell -I nixpkgs=https://github.com/GRBurst/nixpkgs/archive/d40c3d5836d74e0f6249b572a1da2f1b05a6b549/script-cook.tar.gz
#! nix-shell -p script-cook awscli2 aws-vault
#! nix-shell -p ssm-session-manager-plugin openssh
#! nix-shell -p fzf jq mktemp
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
    [p,param]="--profile"        [p,short]="-p" [p,required]=true  [p,value]="${AWS_PROFILE:-}" [p,desc]="aws profile"
    [i,param]="--identity-file"  [i,short]="-i" [i,required]=false                              [i,desc]="instance connect private key"
    [n,param]="--instance"       [n,short]="-n" [n,required]=false                              [n,desc]="instance id or instance name"
    [k,param]="--ssh-public-key" [k,short]="-k" [k,required]=false                              [k,desc]="instance connect public key"
    [s,param]="--ssh-args"       [s,short]="-s" [s,required]=false                              [s,desc]="ssh arguments"
    [g,param]="--no-key-gen"     [g,short]="-g" [g,required]=false [g,tpe]="bool"               [g,desc]="don't generate one-time key"
)

# Define your usage and help message here
usage=$(cat <<-USAGE
Interactively choose and connect to an arbitrary ec2 instance on aws.


Usage and Examples
---------

- Interactively choose an ssh key and an ec2 instance to connect and provide an aws profile and a ssh key:
    $(cook::name) --profile <aws_profile>

- Interactively choose an ec2 instance to connect and provide an aws profile and generate a one-time key:
    $(cook::name) --profile <aws_profile> --gen-key

- Interactively choose an ec2 instance to connect and provide an aws profile and a ssh key:
    $(cook::name) --profile <aws_profile> --identity-file ~/.ssh/<identity_file>

- Interactively choose an ec2 instance to connect, provide an aws profile and a ssh key and forward port 8000 to localhost 58000:
    $(cook::name) --profile <aws_profile> --identity-file ~/.ssh/<identity_file> --ssh-args "-L 58000:localhost:8000"

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instance name:
    $(cook::name) --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instance_name>

- Connect directly to an ec2 instance and provide an aws profile, a ssh key and the instance id:
    $(cook::name) --profile <aws_profile> --identity-file ~/.ssh/<identity_file> -n <instnace_id>
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
        if [[ -z "${priv_key:-}" ]]; then
            return
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

    if [[ "${inputs[g,value]:-}" == "true" ]]; then
        priv_key="$(find ~/.ssh -type f -not -iname "*.pub" | fzf -q "'${inputs[i,value]:-}" -1)"
        if [[ -z "${priv_key}" ]] && [[ -n "${inputs[i,value]}" ]]; then
            priv_key="${inputs[i,value]}"
        fi

        if [[ -n "${inputs[k,value]:-}" ]]; then
            pub_key="${inputs[k,value]}"
        elif [[ -z "${inputs[k,value]:-}" ]] && [[ -f "${priv_key}.pub" ]]; then
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

    instance_id="$(aws $profile ec2 describe-instances --filter Name=instance-state-name,Values=running | jq -r '.Reservations[].Instances[] | [ .InstanceId, (.Tags[] | select(.Key == "Name") | .Value) ] | @tsv' | fzf -q "'${inputs[n,value]:-}" -1 | cut -f1)"

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

readonly usage inputs_str

# We are passing the whole data to cook::run, where
# 1. run is your function defined above
# 2. inputs (array) or inputs_str (string) are the possible inputs you defined
# 3. params is the resulting array containing all inputs provided
# 4. usage is your usage string and will be enriched + printed on help
# 5. $@ is the non-checked input for the script
cook::run run inputs params "${inputs_str:-}" "${usage:-}" "$@"

