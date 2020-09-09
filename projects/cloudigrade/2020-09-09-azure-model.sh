#!/usr/bin/env bash
# asciinema rec -y -i3 -c 'bash THIS_FILE'
clear

#############################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/helpers.sh"

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1 # slow
# source ~/projects/personal/demo-magic/demo-magic.sh -n # fast
DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED
# export SLEEP_SECS="1"

source ~/bin/cloudigrade.sh

#############################

function start_server() {
    header "starting cloudigrade server"
    ./cloudigrade/manage.py runserver &> /dev/null &
    p './cloudigrade/manage.py runserver &> /dev/null &'
    pe "sleep 2  # give the server a moment to start"
}

function kill_server() {
    header "stopping cloudigrade server"
    pe "ps auxww | grep -v grep | grep 'manage.py runserver' | awk '{print \$2}' | xargs -n1 kill"
}

export RH_ACCOUNT_NUMBER="74205"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"74205","user":{"is_org_admin":true}}}' | base64)
export API_URL_BASE="http://0.0.0.0:8000/api"

#############################

title 'azure basic models'
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/699/
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/786

Check the new Azure models for basic functionality.
"

export RH_ACCOUNT_NUMBER="74205"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"'"${RH_ACCOUNT_NUMBER}"'","user":{"is_org_admin":true}}}' | base64)

pe 'echo $RH_ACCOUNT_NUMBER'
pe 'echo $HTTP_X_RH_IDENTITY'
pe 'echo $HTTP_X_RH_IDENTITY | base64 -D | jq'

screen_break

############################

header "
Initialize clean cloudigrade DB with one user.
"

pe 'psql -h localhost -U postgres -c \
    "drop schema public cascade; create schema public;" && \
    ./cloudigrade/manage.py migrate && \
    ./cloudigrade/manage.py createsuperuser \
    --username "'"${RH_ACCOUNT_NUMBER}"'" \
    --email "'"${RH_ACCOUNT_NUMBER}@example.com"'" \
    --noinput'

screen_break

header "spawn pseudorandom test data for AWS and Azure activity in the new user"

export DATE_3_DAYS_AGO=$(gdate --date="3 day ago" "+%Y-%m-%d")
p 'DATE_3_DAYS_AGO=$(date --date="3 day ago" "+%Y-%m-%d") && echo $DATE_3_DAYS_AGO'
echo $DATE_5_DAYS_AGO

pe './cloudigrade/manage.py spawndata \
    --cloud_type aws \
    --account_count 1 --instance_count 5 \
    --image_count 3 --rhel_chance 0.7 --other_owner_chance 0 \
    --confirm 1 ${DATE_3_DAYS_AGO}'

pe './cloudigrade/manage.py spawndata \
    --cloud_type azure \
    --account_count 1 --instance_count 5 \
    --image_count 3 --rhel_chance 0.7 --other_owner_chance 0 \
    --confirm 1 ${DATE_3_DAYS_AGO}'

screen_break

############################

start_server
screen_break

############################

header "
Fetch the AWS and Azure data from the HTTP API.
"

ecko "get all the cloud accounts"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} > /tmp/accounts.json'
echo

ecko "look for the AWS cloud account"
pe 'jq ".data[] | select(.cloud_type | contains(\"aws\"))" /tmp/accounts.json'
echo

ecko "look for the Azure cloud account"
pe 'jq ".data[] | select(.cloud_type | contains(\"azure\"))" /tmp/accounts.json'
echo

ecko "save that account id for use later"
export AZURE_ACCOUNT_ID=$(jq -r ".data[] | select(.cloud_type | contains(\"azure\")) | .account_id" /tmp/accounts.json)
p 'export AZURE_ACCOUNT_ID=$(jq -r ".data[] | select(.cloud_type | contains(\"azure\")) | .account_id" /tmp/accounts.json) && echo $AZURE_ACCOUNT_ID'
echo $AZURE_ACCOUNT_ID

ecko "get all the images"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/images/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} > /tmp/images.json'
echo

ecko "look for the AWS images"
pe 'jq -C "[.data[] | select(.cloud_type | contains(\"aws\"))]" /tmp/images.json | less -R'
echo

ecko "look for the Azure images"
pe 'jq -C "[.data[] | select(.cloud_type | contains(\"azure\"))]" /tmp/images.json | less -R'
echo

ecko "get all the instances"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/instances/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} > /tmp/instances.json'
echo

ecko "look for the AWS instances"
pe 'jq -C "[.data[] | select(.cloud_type | contains(\"aws\"))]" /tmp/instances.json | less -R'
echo

ecko "look for the Azure instances"
pe 'jq -C "[.data[] | select(.cloud_type | contains(\"azure\"))]" /tmp/instances.json | less -R'
echo

screen_break

############################

header "
Create new Azure cloud account using (internal) legacy API.
"

export TENANT_ID=$(uuidgen)
p 'export TENANT_ID=$(uuidgen) && echo $TENANT_ID'
echo $TENANT_ID

export SUBSCRIPTION_ID=$(uuidgen)
p 'export SUBSCRIPTION_ID=$(uuidgen) && echo $SUBSCRIPTION_ID'
echo $SUBSCRIPTION_ID

pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} \
    cloud_type="azure" \
    tenant_id=${TENANT_ID} \
    subscription_id=${SUBSCRIPTION_ID} \
    platform_authentication_id="7113" \
    platform_application_id="5180" \
    platform_endpoint_id="3350" \
    platform_source_id="9052" \
    name="my super duper azure account" \
    | tee /tmp/newaccount.json | jq'
echo

export NEW_AZURE_ACCOUNT_ID=$(jq -r .account_id /tmp/newaccount.json)
p 'export NEW_AZURE_ACCOUNT_ID=$(jq -r .account_id /tmp/newaccount.json) && echo $NEW_AZURE_ACCOUNT_ID'
echo $NEW_AZURE_ACCOUNT_ID

pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/${NEW_AZURE_ACCOUNT_ID}/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}'

screen_break

############################

header "
Delete the Azure cloud accounts and verify cleanup.
"

pe 'http delete \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/${NEW_AZURE_ACCOUNT_ID}/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}'
pe 'http delete \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/${AZURE_ACCOUNT_ID}/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}'

ecko "look for azure cloud accounts"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} | \
    jq "[.data[] | select(.cloud_type | contains(\"azure\"))]"'
echo

ecko "look for azure instances"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/instances/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} | \
    jq "[.data[] | select(.cloud_type | contains(\"azure\"))]"'
echo

ecko "look for azure images"
pe 'http \
    http://0.0.0.0:8000/api/cloudigrade/v2/images/ \
    X-RH-IDENTITY:${HTTP_X_RH_IDENTITY} | \
    jq "[.data[] | select(.cloud_type | contains(\"azure\"))]"'
echo

screen_break

#############################

kill_server

screen_break

#############################

dunzo
