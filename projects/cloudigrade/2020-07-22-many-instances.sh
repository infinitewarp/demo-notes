#!/usr/bin/env bash
# asciinema rec -i3 -c THIS_FILE
clear

#############################

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/helpers.sh"

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1
# source ~/projects/personal/demo-magic/demo-magic.sh -n
DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED
# export SLEEP_SECS="1"

#############################

export AUTH="insights-qa:redhatqa"
export HTTP_X_RH_IDENTITY=$(echo '{"identity":{"account_number":"6089719","user":{"is_org_admin":true}}}' | base64)
export ARN="arn:aws:iam::273470430754:role/cloudigrade-role-ci-qa-372779871274"

#############################

title 'multiple instances'
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/708

Trying to reproduce the issue where starting multiple instances at
the same time using a specific EC2 image would appear in cloudigrade
with an error status.
"

screen_break

#############################

header "
Verify that no cloud accounts exist yet.
Also verify no CloudTrail exists yet for the AWS account we will use.
"

pe 'http --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails'

screen_break

#############################

header "
Verify that no instances are running in my AWS account.
"

pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=0 # pending'
pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=16 # running'
pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=32 # shutting down'
# pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
#     --filters Name=instance-state-code,Values=48 # terminated'
pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=64 # stopping'
pe 'AWS_PROFILE=dev01 aws ec2 describe-instances \
    --filters Name=instance-state-code,Values=80 # stopped'

screen_break

#############################

header "
Create many instances via Python boto3 with the command Parag gave us.

See description in https://gitlab.com/cloudigrade/cloudigrade/-/issues/708

I only reformatted the command slightly for readability and so that I
wouldn't have to reveal my credentials in this recording. Otherwise, this
should be functionally identical to Parag's instruction, using the same
image ID, requested count of instances, and boto3 resource function.
"

source ~/Library/Caches/pypoetry/virtualenvs/cloudigrade-1DDoCAbr-py3.8/bin/activate

pe 'pygmentize -O style=monokai ${SCRIPT_DIR}/2020-07-22-many-instances-create.py'
pe 'AWS_PROFILE=dev01 python ${SCRIPT_DIR}/2020-07-22-many-instances-create.py'

deactivate

pe 'sleep 10  # give them a few seconds to start up, just in case'

screen_break

#############################

header "
Create a source, endpoint, application, authentication,
and application_authentication.
"

pe 'TZ=GMT date "+%Y-%m-%d %H:%M:%S"'

p 'SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)'
export SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources \
    name=sauce-420 source_type_id=2 | jq -r .id)
pe 'echo $SOURCEID'

p 'ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)'
export ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq -r .id)
pe 'echo $ENDPOINTID'

p 'APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)'
export APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq -r .id)
pe 'echo $APPLICATIONID'

p 'AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)'
export AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN \
    authtype=cloud-meter-arn | jq -r .id)
pe 'echo $AUTHENTICATIONID'

p 'APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v2.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq -r .id)'
export APPLICATIONAUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v2.0/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID \
    | jq -r .id)
pe 'echo $APPLICATIONAUTHENTICATIONID'

screen_break

#############################

header "
Verify that a CloudAccount was created in our service
and that its AWS CloudTrail exists and is enabled.
"

pe 'sleep 30  # wait for our listener to process the sources create messages'

pe 'TZ=GMT date "+%Y-%m-%d %H:%M:%S"'
pe 'http --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails'

screen_break

#############################

header "
Check the state of images immediately after the initial cloud account setup.
"

pe 'TZ=GMT date "+%Y-%m-%d %H:%M:%S"'
pe 'http -phb --pretty=all --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/images/ \
    | pv -qlL15'

screen_break

#############################

header "
Per Parag's instructions, wait 10 minutes and check the images API.
"

pe 'sleep 600  # wait 10 minutes'
pe 'TZ=GMT date "+%Y-%m-%d %H:%M:%S"'
pe 'http -phb --pretty=all --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/images/ \
    | pv -qlL15'

screen_break

#############################

header "
Delete the application_authentication, authentication, application,
endpoint, and source.
"

pe 'TZ=GMT date "+%Y-%m-%d %H:%M:%S"'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v2.0/application_authentications/$APPLICATIONAUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications/$APPLICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints/$ENDPOINTID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources/$SOURCEID | head -n1'

screen_break

#############################

header "
Verify that the CloudAccount was deleted and the corresponding
AWS CloudTrail was also deleted.
"

pe 'sleep 180  # wait for our listener to process the sources delete messages'

pe 'http --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'http --verify=no --auth $AUTH \
    https://qa.cloud.redhat.com/api/cloudigrade/v2/images/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails'


screen_break

#############################

header "
Terminate the EC2 instances we started earlier.
"

source ~/Library/Caches/pypoetry/virtualenvs/cloudigrade-1DDoCAbr-py3.8/bin/activate

pe 'pygmentize -O style=monokai ${SCRIPT_DIR}/2020-07-22-many-instances-destroy.py'
pe 'AWS_PROFILE=dev01 python ${SCRIPT_DIR}/2020-07-22-many-instances-destroy.py'

deactivate

pe 'sleep 10  # just to give them some time to terminate before quitting here'

screen_break

#############################

dunzo
