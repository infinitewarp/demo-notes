#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

# BEFORE RUNNING
# oc login
# oc project cloudigrade-qa

# SETUP
DEMO_PROMPT='$ '  # force a simple-style PS1
# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

function screenBreak() {
    p
    clear
}

function dunzo() {
    sleep 1
    clear
    echo
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    sleep 5
    clear
    exit
}

function ecko() {
    echo "### $1"
}

clear
export AUTH="insights-qa:redhat"

# gotta go fast?
# NO_WAIT=(true)
# unset TYPE_SPEED


toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'handle sources 404s'
echo
ecko 'https://gitlab.com/cloudigrade/cloudigrade/-/issues/645'
ecko 'https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/708'
ecko
ecko 'If sources authentication or endpoint is missing during processing,'
ecko 'log a message and quietly return during cloud account creation.'
sleep 2

screenBreak

ecko
ecko 'Scale down the listener deployment to 0 replicas.'
ecko 'This is necessary because the listener processes messages'
ecko 'faster than we can create and delete sources objects.'
ecko
echo

sleep 1

pe 'oc scale dc c-l --replicas=0'
pe 'sleep 5'

sleep 2
clear

ecko
ecko 'Create a source, endpoint, application, and authentication.'
ecko 'Then quickly delete them all...'
ecko
echo

sleep 1

p 'SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources \
    name=test-source-15 source_type_id=2 | jq .id | cut -d\\" -f2)'
export SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources \
    name=test-source-15 source_type_id=2 | jq .id | cut -d\" -f2)
pe 'echo $SOURCEID'

p 'ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq .id | cut -d\\" -f2)'
export ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq .id | cut -d\" -f2)
pe 'echo $ENDPOINTID'

p 'APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq .id | cut -d\\" -f2)'
export APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq .id | cut -d\" -f2)
pe 'echo $APPLICATIONID'

p 'AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=arn:aws:iam::123456789012:role/bogus-role-for-test \
    authtype=cloud-meter-arn | jq .id | cut -d\\" -f2)'
export AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=arn:aws:iam::123456789012:role/bogus-role-for-test \
    authtype=cloud-meter-arn | jq .id | cut -d\" -f2)
pe 'echo $AUTHENTICATIONID'

pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications/$APPLICATIONID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints/$ENDPOINTID | head -n1'
pe 'http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources/$SOURCEID | head -n1'

sleep 2
clear

ecko
ecko 'Scale up the listener deployment to 1 replica.'
ecko 'Now it should process the authentication creation, but '
ecko 'it will get 404 when getting various sources-api objects.'
ecko
echo

sleep 1

pe 'oc scale dc c-l --replicas=1'
pe 'sleep 30'

sleep 2
clear

ecko
ecko 'Look in the worker logs for a message that indicates we stopped'
ecko 'processing the new authentication for cloud account creation.'
ecko
echo

p 'for POD in $(oc get pods -o jsonpath='"'"'{.items[?(.status.phase=="Running")].metadata.name}'"'"' -l name=c-w)
do
    oc logs $POD | grep "$AUTHENTICATIONID\|$ENDPOINTID" | grep "does not exist"
done'
for POD in $(oc get pods -o jsonpath='{.items[?(.status.phase=="Running")].metadata.name}' -l name=c-w)
do
    oc logs $POD | grep "$AUTHENTICATIONID\|$ENDPOINTID" | grep "does not exist"
done

sleep 2
p
sleep 1
clear

dunzo
sleep 3