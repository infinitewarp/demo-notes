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
Create a CloudAccount via the internal HTTP API.

We're doing this instead of using sources-api because sources-api is
currently sending incorrect messages to its 'delete' Kafka topics.
"

pe 'http --auth $AUTH post \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}" \
    cloud_type=aws account_arn="${ARN}" name="best-account-ever" \
    platform_application_id=42 \
    platform_authentication_id=67 \
    platform_endpoint_id=420 \
    platform_source_id=1701'

screen_break

#############################

header "
Verify that the AWS CloudTrail was created and enabled.
"

pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-687-delete-trails273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=review-687-delete-trails273470430754 | jq | grep --color -E '"'"'.*IsLogging.*|$'"'"

screen_break

#############################

header "
Delete the CloudAccount we just created
"

pe 'http --auth $AUTH delete \
    review.ci.cloudigra.de/api/cloudigrade/v2/accounts/14/ \
    "X-RH-IDENTITY:${HTTP_X_RH_IDENTITY}" X-4Scale-Branch:"${BRANCH_NAME}"'

screen_break

#############################

header "
Verify that the corresponding AWS CloudTrail was also deleted.
"

pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=review-687-delete-trails273470430754'

screen_break

#############################

dunzo
