#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED

function screen_break() {
    sleep 3
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    sleep 5
    clear
    exit
}

function title() {
    toilet -f standard -d /usr/local/share/figlet/fonts/ -t "$1"
}

function header() {
    tput setaf 245
    echo "$1" | sed -e 's/^/### /g'
    tput sgr0
    echo
    sleep 2
}

export AUTH="insights-qa:redhatqa"
export ACCOUNT_ID="6089719"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"'"${ACCOUNT_ID}"'","user":{"is_org_admin":true}}}' | base64)
export ARN="arn:aws:iam::273470430754:role/role-for-cloudigrade-743187646576-review"

clear
##############################################

title "image architecture"
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/684
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/741

Add a MachineImage.architecture field to our model and populate it when we
describe the AWS AMI upon first discovery.
"

screen_break
##############################################

header "Verify no account or images exist yet in cloudigrade."

pe 'http review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:684-arch'
pe 'http review.ci.cloudigra.de/api/cloudigrade/v2/images/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:684-arch'

screen_break
##############################################

header "Create various sources-api objects to trigger cloudigrade account setup."

p 'SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/sources \
    name=test-source-15 source_type_id=2 | jq .id | cut -d\\" -f2)'
export SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/sources \
    name=test-source-15 source_type_id=2 | jq .id | cut -d\" -f2)
pe 'echo $SOURCEID'

p 'ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq .id | cut -d\\" -f2)'
export ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq .id | cut -d\" -f2)
pe 'echo $ENDPOINTID'

p 'APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq .id | cut -d\\" -f2)'
export APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq .id | cut -d\" -f2)
pe 'echo $APPLICATIONID'

p 'AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq .id | cut -d\\" -f2)'
export AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq .id | cut -d\" -f2)
pe 'echo $AUTHENTICATIONID'

p 'APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v2.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq .id | cut -d\\" -f2)'
export APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v2.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq .id | cut -d\" -f2)
pe 'echo $APPLICATIONAUTHENTICATIONID'

screen_break
##############################################

header "Wait for messages to process, and check cloudigrade for initial findings."

pe 'sleep 30'
pe 'http review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:684-arch \
    | jq -C ".data[]" | less -RS'
pe 'http review.ci.cloudigra.de/api/cloudigrade/v2/images/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:684-arch \
    | jq -C ".data[]" | less -RS'

screen_break
##############################################

header "Delete the various sources-api objects we created."

pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v2.0/application_authentications/$APPLICATIONAUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications/$APPLICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v1.0/endpoints/$ENDPOINTID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v1.0/sources/$SOURCEID | head -n1'

screen_break
##############################################

dunzo
