#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

# BEFORE RUNNING
# oc login
# oc project cloudigrade-ci

# SETUP
DEMO_PROMPT='$ '  # force a simple-style PS1
# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

function screenBreak() {
    sleep 3
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    AWS_PROFILE=dev01 aws cloudtrail delete-trail --name ci-273470430754 &>/dev/null
    sleep 5
    clear
    exit
}

function ecko() {
    echo "### $1"
}

clear
export AUTH="insights-qa:redhat"
export ARN="arn:aws:iam::273470430754:role/cloudigrade-role-ci"
export ARN_BAD="arn:aws:iam::123456789012:role/this-role-is-potatoes"

# gotta go fast?
# NO_WAIT=(true)
# unset TYPE_SPEED

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'enable/disable accounts'
echo
ecko 'https://gitlab.com/cloudigrade/cloudigrade/-/issues/646'
ecko 'https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/713'
ecko
ecko 'Verify creating and destroying cloud accounts via sources did not regress.'
ecko 'Verify that programatically disabling and enabling cloud accounts applies'
ecko 'changes in our service and in AWS as expected.'

screenBreak


##########
ecko
ecko 'Verify that no cloud accounts exist yet.'
ecko 'Also verify no CloudTrail exists yet for the AWS account we will use.'
ecko
echo

sleep 1

pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=ci-273470430754'

screenBreak


##########
ecko
ecko 'Create a source, endpoint, application, authentication,'
ecko 'and application_authentication.'
ecko
echo

sleep 1

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

screenBreak


##########
ecko
ecko 'Verify that a CloudAccount was created in our service'
ecko 'and that its AWS CloudTrail exists and is enabled.'
ecko
echo

sleep 1

pe 'sleep 10  # wait for our listener to process the new sources messages'
pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=ci-273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=ci-273470430754 | jq ".IsLogging"'

screenBreak


##########
ecko
ecko 'Use the Python REPL to programatically disable the CloudAccount'
ecko 'since we do not have an API available to do that.'
ecko
echo

sleep 1

p "oc rsh -c cloudigrade-api $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api  | awk '{print $1}') ./manage.py shell"
oc rsh -c cloudigrade-api $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api  | awk '{print $1}') ./manage.py shell
# from api.models import CloudAccount
# for account in CloudAccount.objects.all():
#     account.disable()

screenBreak


##########
ecko
ecko 'Verify that the CloudAccount was disabled in our service'
ecko 'and that its AWS CloudTrail is also disabled.'
ecko
echo

sleep 1

pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=ci-273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=ci-273470430754 | jq ".IsLogging"'

screenBreak


##########
ecko
ecko 'Use the Python REPL to programatically enable the CloudAccount'
ecko 'since we do not have an API available to do that.'
ecko
echo

sleep 1

p "oc rsh -c cloudigrade-api $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api  | awk '{print $1}') ./manage.py shell"
oc rsh -c cloudigrade-api $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api  | awk '{print $1}') ./manage.py shell
# from api.models import CloudAccount
# for account in CloudAccount.objects.all():
#     account.enable()

screenBreak


##########
ecko
ecko 'Verify that the CloudAccount was enabled in our service'
ecko 'and that its AWS CloudTrail is also enabled.'
ecko
echo

sleep 1

pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=ci-273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=ci-273470430754 | jq ".IsLogging"'

screenBreak


##########
ecko
ecko 'Delete the application_authentication, authentication, application,'
ecko 'endpoint, and source.'
ecko
echo

sleep 1

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

screenBreak

##########
ecko
ecko 'Verify that our CloudAccount has been deleted'
ecko 'and that its AWS CloudTrail exists but has been disabled.'
ecko
echo

sleep 1

pe 'sleep 10  # wait for our listener to process the new sources messages'
pe 'http --verify=no --auth $AUTH \
    https://ci.cloud.redhat.com/api/cloudigrade/v2/accounts/'
pe 'AWS_PROFILE=dev01 aws cloudtrail describe-trails \
    --trail-name-list=ci-273470430754'
pe 'AWS_PROFILE=dev01 aws cloudtrail get-trail-status \
    --name=ci-273470430754 | jq ".IsLogging"'

screenBreak
dunzo
