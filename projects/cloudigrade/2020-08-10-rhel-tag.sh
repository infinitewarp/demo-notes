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

#############################

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
export AWS_PROFILE="dev01"

DEV07_AWS_ACCOUNT_ID="439727791560"
DEV07_ARN="arn:aws:iam::439727791560:role/brasmith-role-review-743187646576"
DEV01_AWS_ACCOUNT_ID="273470430754"
DEV01_ARN="arn:aws:iam::273470430754:role/cloudigrade-role-ci-qa-372779871274"

export AUTH="insights-qa:redhatqa"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"6089719","user":{"is_org_admin":true}}}' | base64)

export CUSTOMER_AWS_ACCOUNT_ID="${DEV01_AWS_ACCOUNT_ID}"
export ARN="${DEV01_ARN}"

# export BRANCH_NAME="682-inspection-problems"
export TRAIL_PREFIX_REVIEW="review-${BRANCH_NAME}"
export TRAIL_PREFIX_QA="test-"
export TRAIL_PREFIX="$TRAIL_PREFIX_QA"
export CUSTOMER_TRAIL_NAME="${TRAIL_PREFIX}${CUSTOMER_AWS_ACCOUNT_ID}"

export API_URL_BASE="https://qa.cloud.redhat.com/api"

export AMI_RHEL_TAGGED="ami-00ff566775b0b66e1"

#############################

title 'rhel by tag'
header "
This is just a quick sanity-check of cloudigrade's ability to
identify an image with RHEL via presence of our special tag.
"

screen_break

#############################

header "
Show some convenience variables used later in the script.
"

pe 'echo $API_URL_BASE'
pe 'echo $ARN'
pe 'echo $CUSTOMER_AWS_ACCOUNT_ID'
pe 'echo $CUSTOMER_TRAIL_NAME'

screen_break

#############################

header "
Find the images for all *running* (code 16) instances,
and check if any may be tagged for RHEL.

Specifically look for the tag name/value 'cloudigrade-rhel-present'.
"

pe 'aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=16 > \
    /tmp/aws-instances-running.json'
pe 'for AMI in $(
    jq -r ".Reservations[].Instances[].ImageId" /tmp/aws-instances-running.json
);
do
    echo "checking tags for found image $AMI";
    aws ec2 describe-images --image-ids $AMI | jq ".Images[].Tags";
done'

screen_break

#############################

header "
So, we're specifically looking for $AMI_RHEL_TAGGED.

Go through the usual account setup routine with sources-api,
and then later we'll look at cloudigrade's images to see if
that tag was correctly detected.
"

pe 'http --verify=no --auth $AUTH \
    $API_URL_BASE/cloudigrade/v2/accounts/ '
pe 'aws cloudtrail describe-trails'

pe 'http --verify=no --auth $AUTH --body \
    $API_URL_BASE/sources/v3.0/source_types \
    filter[name]==amazon \
    | tee /tmp/sources-sourcetypes.json && echo'
COMMAND='jq -r .data[0].id /tmp/sources-sourcetypes.json'
export SOURCETYPEID=$($COMMAND)
pe 'SOURCETYPEID=$('"$COMMAND"')'
pe 'echo $SOURCETYPEID'

pe 'http --verify=no --auth $AUTH --body \
    $API_URL_BASE/sources/v3.0/application_types \
    filter[name]==/insights/platform/cloud-meter \
    | tee /tmp/sources-applicationtypes.json && echo'
COMMAND='jq -r .data[0].id /tmp/sources-applicationtypes.json'
export APPLICATIONTYPEID=$($COMMAND)
pe 'APPLICATIONTYPEID=$('"$COMMAND"')'
pe 'echo $APPLICATIONTYPEID'

pe 'http --verify=no --auth $AUTH --body post \
    $API_URL_BASE/sources/v3.0/sources \
    name=sauce-420 source_type_id=2 \
    | tee /tmp/sources-source.json && echo'
COMMAND='jq -r .id /tmp/sources-source.json'
export SOURCEID=$($COMMAND)
pe 'SOURCEID=$('"$COMMAND"')'
pe 'echo $SOURCEID'

pe 'http --verify=no --auth $AUTH --body post \
    $API_URL_BASE/sources/v3.0/endpoints \
    role=aws default=true source_id=$SOURCEID \
    | tee /tmp/sources-endpoint.json && echo'
COMMAND='jq -r .id /tmp/sources-endpoint.json'
export ENDPOINTID=$($COMMAND)
pe 'ENDPOINTID=$('"$COMMAND"')'
pe 'echo $ENDPOINTID'

pe 'http --verify=no --auth $AUTH --body post \
    $API_URL_BASE/sources/v3.0/applications \
    application_type_id=$APPLICATIONTYPEID source_id=$SOURCEID \
    | tee /tmp/sources-application.json && echo'
COMMAND='jq -r .id /tmp/sources-application.json'
export APPLICATIONID=$($COMMAND)
pe 'APPLICATIONID=$('"$COMMAND"')'
pe 'echo $APPLICATIONID'

pe 'http --verify=no --auth $AUTH --body post \
    $API_URL_BASE/sources/v3.0/authentications \
    resource_type=Endpoint authtype=cloud-meter-arn \
    resource_id=$ENDPOINTID password=$ARN \
    | tee /tmp/sources-authentication.json && echo'
COMMAND='jq -r .id /tmp/sources-authentication.json'
export AUTHENTICATIONID=$($COMMAND)
pe 'AUTHENTICATIONID=$('"$COMMAND"')'
pe 'echo $AUTHENTICATIONID'

pe 'http --verify=no --auth $AUTH --body post \
    $API_URL_BASE/sources/v3.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | tee /tmp/sources-applicationauthentication.json && echo'
COMMAND='jq -r .id /tmp/sources-applicationauthentication.json'
export APPLICATIONAUTHENTICATIONID=$($COMMAND)
pe 'APPLICATIONAUTHENTICATIONID=$('"$COMMAND"')'
pe 'echo $APPLICATIONAUTHENTICATIONID'

screen_break

#############################

header "
Verify that the cloudigrade account and AWS CloudTrail were created.
"

pe 'sleep 30  # give kafka and the listener time to process'

pe 'http --verify=no --auth $AUTH \
    $API_URL_BASE/cloudigrade/v2/accounts/ \
    | tee /tmp/cloudigrade-accounts.json && echo'
pe 'cat /tmp/cloudigrade-accounts.json | jq -C | less -R'
pe 'aws cloudtrail describe-trails \
    --trail-name-list=${CUSTOMER_TRAIL_NAME}'
pe 'aws cloudtrail get-trail-status \
    --name=${CUSTOMER_TRAIL_NAME} \
    | jq | grep --color -E '"'"'.*IsLogging.*|$'"'"

screen_break

#############################

header "
Check the images cloudigrade discovered.
"

pe 'http --verify=no --auth $AUTH \
    $API_URL_BASE/cloudigrade/v2/images/ \
    | tee /tmp/cloudigrade-images.json && echo'
pe 'jq '"'"'.data[] | select(.content_object.ec2_ami_id | match("'"$AMI_RHEL_TAGGED"'"))'"'"'\
    /tmp/cloudigrade-images.json'
pe 'jq '"'"'.data[] | select(.content_object.ec2_ami_id | match("'"$AMI_RHEL_TAGGED"'"))'"'"'\
    /tmp/cloudigrade-images.json \
    | grep --color -E '"'"'.*(ec2_ami_id|rhel_detected).*|$'"'"

screen_break

#############################

header "
Delete the application_authentication, authentication, application,
endpoint, and source.
"

pe 'http --verify=no --auth $AUTH --headers delete \
    $API_URL_BASE/sources/v3.0/application_authentications/$APPLICATIONAUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    $API_URL_BASE/sources/v3.0/authentications/$AUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    $API_URL_BASE/sources/v3.0/applications/$APPLICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    $API_URL_BASE/sources/v3.0/endpoints/$ENDPOINTID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    $API_URL_BASE/sources/v3.0/sources/$SOURCEID | head -n1'

screen_break

#############################

header "
Verify the cloudigrade account and AWS CloudTrail were deleted.
"

pe 'sleep 30  # give kafka and the listener time to process'

pe 'http --verify=no --auth $AUTH \
    $API_URL_BASE/cloudigrade/v2/accounts/'
pe 'aws cloudtrail describe-trails'

screen_break

#############################

dunzo
