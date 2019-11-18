#!/usr/bin/env bash
#
# asciinema rec -c ~/projects/personal/demo-notes/2018-06-05-sqs-everywhere.sh

clear

<<PREREQ
make oc-clean
make oc-up-all
oc process cloudigrade-persistent-template \
    -p NAMESPACE=myproject \
    -p AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    -p AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    -p AWS_SQS_ACCESS_KEY_ID=${AWS_SQS_ACCESS_KEY_ID} \
    -p AWS_SQS_SECRET_ACCESS_KEY=${AWS_SQS_SECRET_ACCESS_KEY} \
    -p AWS_SQS_QUEUE_NAME_PREFIX=${AWS_SQS_QUEUE_NAME_PREFIX} \
    -p DJANGO_ALLOWED_HOSTS=* \
    -p DJANGO_DATABASE_HOST=postgresql.myproject.svc | oc replace -f - ; \
    sleep 1; \
    make oc-build-and-push-cloudigrade
PREREQ

export CUSTOMER_ARN="arn:aws:iam::273470430754:role/role-for-cloudigrade"

toilet -f standard -d /usr/local/share/figlet/fonts/ -t 'SQS Demo Setup'
echo '### https://github.com/cloudigrade/cloudigrade/issues/296'
echo '### https://github.com/cloudigrade/cloudigrade/pull/312'
echo '### https://github.com/cloudigrade/houndigrade/pull/12'

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

##########
# here we go...

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null

# initial user setup
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c 'truncate auth_user cascade;' 2>&1 >/dev/null

USERNAME=customer1
p "make oc-user"
expect -c "spawn make oc-user
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect \"?ddress:\"
        send \"\r\"
        expect \"?ssword:\"
        send \"$USERNAME\r\"
        expect \"?ssword \(again\):\"
        send \"$USERNAME\r\"
        expect eof" 2>&1 | grep -v "spawn"

rm -rf /tmp/token
p 'make oc-user-authenticate'
expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | grep -v 'spawn' | tee >(grep 'Generated token' > /tmp/token)
CLOUDIGRADE_TOKEN=$(cat /tmp/token | cut -d ' ' -f 3)
p "CLOUDIGRADE_TOKEN=$CLOUDIGRADE_TOKEN"
p "CUSTOMER_ARN="$CUSTOMER_ARN

p
sleep 5
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Purge the queues'
echo '### Manually scale down Celery replicas so we can reliably look at the queues.'
echo '### Purge any existing messages in my Amazon SQS queues.'
echo '### Then try to fetch a message to verify nothing is returned.'
sleep 5


p 'sleep 15'
echo '### oc scale --replicas 0 dc/cloudigrade-celery'
echo '### Normally that command would work, but our version of OpenShift is broken.'
echo '### See also: https://bugzilla.redhat.com/show_bug.cgi?id=1543357'
echo '### Instead, please wait here a few seconds while I manually click buttons in the UI...'
open 'https://127.0.0.1:8443/console/project/myproject/overview'
sleep 15

unset QUEUES_JSON
p 'AWS_PROFILE=cluster aws sqs list-queues --queue-name-prefix="${USER}-"'
QUEUES_JSON=$(AWS_PROFILE=cluster aws sqs list-queues --queue-name-prefix="${USER}-")

echo $QUEUES_JSON | jq
for URL in $(echo $QUEUES_JSON | jq -M . | grep "${USER}" | cut -d '"' -f 2); do
    pe "AWS_PROFILE=cluster aws sqs purge-queue --queue-url $URL"
    pe "AWS_PROFILE=cluster aws sqs receive-message --queue-url $URL"
done
unset QUEUES_JSON

p
sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Farewell, RabbitMQ.'
echo '### Verify RabbitMQ is no longer running in local OpenShift cluster.'
echo '### Register an account (which finds new instances and AMIs) to put task messages on SQS.'
echo '### Check that the SQS queue received a task message from cloudigrade.'

sleep 5

pe "oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq | wc -l"

pe 'http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}"'

QUEUE_NAME=$(AWS_PROFILE=cluster aws sqs list-queues --queue-name-prefix="${USER}-copy_ami_snapshot" | jq -M '.["QueueUrls"][0]' | cut -d'"' -f2)
MESSAGE_CONTENT=$(AWS_PROFILE=cluster aws sqs receive-message --queue-url="${QUEUE_NAME}")

p "AWS_PROFILE=cluster aws sqs receive-message --queue-url=\"${QUEUE_NAME}\""
echo $MESSAGE_CONTENT | python -m json.tool

BASE64_ENCODED=$(echo $MESSAGE_CONTENT | jq -M '.["Messages"][0]["Body"]' | cut -d'"' -f2)

pe "echo \"$BASE64_ENCODED\" | base64 -D | python -m json.tool"

p
sleep 5
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Check on Celery'
echo '### Manually scale up Celery replicas so it starts processing messages.'
echo '### Watch things happen in the Celery logs.'

sleep 5

p 'sleep 15'
echo '### oc scale --replicas 1 dc/cloudigrade-celery'
echo '### Normally that command would work, but our version of OpenShift is broken.'
echo '### See also: https://bugzilla.redhat.com/show_bug.cgi?id=1543357'
echo '### Instead, please wait here a few seconds while I manually click buttons in the UI...'
open 'https://127.0.0.1:8443/console/project/myproject/overview'
sleep 15

pe "oc logs $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery)"

p
sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Run houndigrade'
echo '### Verify no results exist yet in SQS.'
echo '### Manually run houndigrade with the local test volume.'
echo '### Check SQS to find the posted results message.'
echo '### Parse the actual results data from the message.'

sleep 5

pe 'cd ../houndigrade'
git checkout -- docker/*

QUEUE_URL=$(AWS_PROFILE=cluster aws sqs list-queues --queue-name-prefix="${USER}-inspection_results" | jq -M '.["QueueUrls"][0]')
pe "AWS_PROFILE=cluster aws sqs purge-queue --queue-url $QUEUE_URL"


pe 'docker-compose up'

QUEUE_NAME=$(echo $QUEUE_URL | cut -d'"' -f2)
MESSAGE_CONTENT=$(AWS_PROFILE=cluster aws sqs receive-message --queue-url="${QUEUE_NAME}")

p "MESSAGE_CONTENT=\$(AWS_PROFILE=cluster aws sqs receive-message --queue-url=\"${QUEUE_NAME}\")"
pe "echo \$MESSAGE_CONTENT | wc"
pe "echo \$MESSAGE_CONTENT | jq -M '.[\"Messages\"][0][\"Body\"]' | cut -d'\"' -f2 | base64 -D | jq -M '.[\"body\"]' | cut -d'\"' -f2 | base64 -D | jq -M '.[\"facts\"]' | python -m json.tool"

sleep 5

echo
echo "🎉  🎉  🎉  🎉"
echo

sleep 5
clear
