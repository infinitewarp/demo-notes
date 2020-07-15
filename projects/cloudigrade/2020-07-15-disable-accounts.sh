#!/usr/bin/env bash
# asciinema rec -i3 -c THIS_FILE
clear

# BEFORE RUNNING
# export GITLAB_API_TOKEN_PERSONAL
# oc login
# oc project cloudigrade-ci

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
export BRANCH_NAME="688-clount-cleanup"
export ARN="arn:aws:iam::273470430754:role/cloudigrade-role-review-743187646576"

export PROJECTID=7449616
export PIPELINEID=167113610

#############################

title 'disable accounts on cleanup'
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/688
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/764

Verify that cleaning up a review environment effectively disables any
cloud accounts that were active at the time of cleanup.
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
    --trail-name-list=review-688-clount-cleanup273470430754'

screen_break

#############################

header "
Create a source, endpoint, application, authentication,
and application_authentication.
"

p 'SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)'
export SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)
pe 'echo $SOURCEID'

p 'ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)'
export ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)
pe 'echo $ENDPOINTID'

p 'APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)'
export APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)
pe 'echo $APPLICATIONID'

p 'AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)'
export AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)
pe 'echo $AUTHENTICATIONID'

p 'APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v2.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq -r .id)'
export APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://ci.cloud.redhat.com/api/sources/v2.0/application_authentications \
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
    --trail-name-list=review-688-clount-cleanup273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=review-688-clount-cleanup273470430754 | jq | grep --color -E '"'"'.*IsLogging.*|$'"'"

screen_break

#############################

header "
Use the GitLab API to programatically run the 'Clean Up Review' job.
"

# Get the (hopefully only) manual job for our pipeline.
p 'http https://gitlab.com/api/v4/projects/$PROJECTID/pipelines/$PIPELINEID/jobs \
    PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL" scope[]==manual | \
    jq -C ".[] | {id, name, status, started_at, finished_at}"'
JOBINFO=$(http https://gitlab.com/api/v4/projects/$PROJECTID/pipelines/$PIPELINEID/jobs \
    PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL" scope[]==manual)
echo $JOBINFO | jq -C ".[] | {id, name, status, started_at, finished_at}"

# Save the Job ID.
export JOBID=$(echo $JOBINFO | jq ".[].id")
pe "JOBID=$JOBID"

# Play the job.
pe 'http post https://gitlab.com/api/v4/projects/$PROJECTID/jobs/$JOBID/play \
    PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL"'

# p 'http https://gitlab.com/api/v4/projects/7449616/pipelines/167007488/jobs \
#     PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL" | jq '"'"'.[] | select(.name=="Clean Up Review") | {id: .id, name: .name}'"'"
# JOBINFO=$(http https://gitlab.com/api/v4/projects/7449616/pipelines/167007488/jobs \
#     PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL")
# echo $JOBINFO | jq '.[] | select(.name=="Clean Up Review") | {id: .id, name: .name}'
# export JOBID=$(echo $JOBINFO | '.[] | select(.name=="Clean Up Review") | .id')
# p 'JOBID=$(echo $JOBINFO | jq ".[].id") && echo $JOBID'
# echo $JOBID
# pe 'http post https://gitlab.com/api/v4/projects/7449616/jobs/$JOBID/retry \
#     PRIVATE-TOKEN:"$GITLAB_API_TOKEN_PERSONAL"'

pe 'sleep 90  # give GitLab time to run the job'

screen_break

#############################

header "
Verify that the OpenShift deployment was actually destroyed.
"

pe "oc project cloudigrade-ci"
pe "oc get pods -l name=c-review-688-clount-cleanup-a"
pe 'http --auth $AUTH \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}"'


screen_break

###############################

header "
Verify that the AWS CloudTrail was disabled and the sources-api
application was updated with an 'unavailable' status.
"

pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-688-clount-cleanup273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=review-688-clount-cleanup273470430754 | jq | grep --color -E '"'"'.*IsLogging.*|$'"'"
pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/sources/v1.0/applications/$APPLICATIONID'


screen_break

#############################

header "
Delete the application_authentication, authentication, application,
endpoint, and source.
"

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

#############################

dunzo
