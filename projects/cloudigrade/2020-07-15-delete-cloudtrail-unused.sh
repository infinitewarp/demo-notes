#!/usr/bin/env bash
# asciinema rec -i3 -c THIS_FILE
clear

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED
# export SLEEP_SECS="1"

#############################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/helpers.sh"

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1
DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

#############################

export AUTH="insights-qa:redhatqa"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"6089719","user":{"is_org_admin":true}}}' | base64)
export BRANCH_NAME="687-delete-trails"
export ARN="arn:aws:iam::273470430754:role/cloudigrade-role-review-743187646576"

#############################

title 'delete cloudtrail'
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/687
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/765

Verify that when disabling/deleting a cloud account,
we now delete its AWS CloudTrail instead of disabling it.
"

screen_break

#############################

header "
Verify that no cloud accounts exist yet.
Also verify no CloudTrail exists yet for the AWS account we will use.
"

pe 'http --auth $AUTH \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}"'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-687-delete-trails273470430754'

screen_break

#############################

header "
Create a source, endpoint, application, authentication,
and application_authentication.
"

p 'SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)'
export SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)
pe 'echo $SOURCEID'

p 'ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)'
export ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)
pe 'echo $ENDPOINTID'

p 'APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)'
export APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)
pe 'echo $APPLICATIONID'

p 'AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)'
export AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)
pe 'echo $AUTHENTICATIONID'

p 'APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq -r .id)'
export APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v3.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq -r .id)
pe 'echo $APPLICATIONAUTHENTICATIONID'

screen_break

#############################

header "
Verify that a CloudAccount was created in our service
and that its AWS CloudTrail exists and is enabled.
"

pe 'sleep 10  # wait for our listener to process the new sources messages'

pe 'http --auth $AUTH \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}"'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-687-delete-trails273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=review-687-delete-trails273470430754 | jq | grep --color -E '"'"'.*IsLogging.*|$'"'"

screen_break

#############################

header "
Delete the application_authentication, authentication, application,
endpoint, and source.
"

pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v3.0/application_authentications/$APPLICATIONAUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v3.0/authentications/$AUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v3.0/applications/$APPLICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v3.0/endpoints/$ENDPOINTID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://ci.cloud.redhat.com/api/sources/v3.0/sources/$SOURCEID | head -n1'

screen_break

#############################


#############################

header "
Verify that the CloudAccount was deleted and the corresponding
AWS CloudTrail was also deleted.
"

pe 'sleep 60  # wait for our listener to process the new sources messages'

pe 'http --auth $AUTH \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}"'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-687-delete-trails273470430754'


screen_break

#############################

dunzo
