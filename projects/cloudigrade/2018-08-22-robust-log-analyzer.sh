#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear

<<PREREQ
cloudigrade
cd ../shiftigrade/
make oc-clean
make oc-up-all
make oc-forward-ports
export API_REPO_REF=412-multiuser-images
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

# export CUSTOMER_ACCOUNT="273470430754"
# export CUSTOMER_ARN="arn:aws:iam::$CUSTOMER_ACCOUNT:role/role-for-cloudigrade"
# export SECONDARY_ACCOUNT="528231032158"
# export SECONDARY_ARN="arn:aws:iam::$SECONDARY_ACCOUNT:role/role-for-cloudigrade"
export CLOUDTRAIL_EVENT_URL='https://sqs.us-east-1.amazonaws.com/977153484089/brasmith-analyzer-testing'
export SAMPLE_FILES_DIR="/Users/brasmith/projects/personal/demo-notes/sample-files/"
DATAOUT="/tmp/clouditestdata.txt"

export DJANGO_SETTINGS_MODULE=config.settings.local
source "$(brew --prefix)/bin/virtualenvwrapper.sh"
# source ~/projects/personal/demo-magic/demo-magic.sh -d -n
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

function create_user() {
    USERNAME=$1
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
    pe "oc rsh -c postgresql \
        \$(oc get pods -o jsonpath=\"{.items[*].metadata.name}\" -l name=postgresql) \\
        scl enable rh-postgresql96 -- psql -c \\
        \"update auth_user set is_superuser=false where username='$USERNAME'\" \\
        2>&1 >/dev/null"
}

function auth_token() {
    USERNAME=$1
    rm -rf /tmp/token
    p 'make oc-user-authenticate'
    expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | \
        grep -v 'spawn' | \
        tee >(grep 'Generated token' > /tmp/token)
}

function screenBreak() {
    p
    sleep 2
    clear
}

function dunzo() {
    sleep 1
    echo
    echo "🎉 🏆 🥇"
    echo
    sleep 5
    clear

}

function resetDb() {
    # https://youtu.be/jmVyUdHtxbU
    oc rsh -c postgresql \
        $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
        scl enable rh-postgresql96 -- psql -c \
        'drop schema public cascade; create schema public;' \
        2>&1 >/dev/null
    ./cloudigrade/manage.py migrate 2>&1 >/dev/null
}

function purgeSqs() {
    echo '### Purge any existing messages in SQS to ensure it is clean.'
    pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    aws sqs purge-queue --queue-url "${CLOUDTRAIL_EVENT_URL}"'
    echo '### sleep briefly to ensure messages are gone...'
    pe 'sleep 30'
}

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Robust Log Analyzer'

echo '### This demo show several specific cases in which the log analyzer'
echo '### better handles error conditions and "unhappy path" scenarios.'
sleep 2

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null
resetDb

export CLOUDTRAIL_EVENT_URL='https://sqs.us-east-1.amazonaws.com/977153484089/brasmith-analyzer-testing'

screenBreak
###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Unrecognized AWS account'

echo '### "no.such.account.json.gz" problematic event. In this case, the event'
echo '### references an AWS account ID that our backend does not know about.'
echo '### We start processing the log, but upon failing to load the account,'
echo '### our process aborts and leaves the message on the queue.'
echo

sleep 2

purgeSqs

echo
echo '### Review the file contents and upload it so S3.'
pe 'gunzip -c ${SAMPLE_FILES_DIR}/no.such.account.json.gz'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/no.such.account.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/no.such.account.json.gz'

pe 'ANALYZE_LOG_SCHEDULE=10 DJANGO_SETTINGS_MODULE=config.settings.local PYTHONPATH=cloudigrade \
    celery -l info -A config worker --beat -Q analyze_log'

screenBreak
###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Non-gzipped file'

echo '### "not_gzipped.json.gz" is not gzipped despite its claim to be.'
echo '### We start processing the log, but upon failing to un-gzip it,'
echo '### our process aborts and leaves the message on the queue.'
echo

sleep 2

purgeSqs

echo
echo '### Review the file contents and upload it so S3.'
pe 'cat ${SAMPLE_FILES_DIR}/not_gzipped.txt'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/not_gzipped.txt \
s3://brasmith-cloudigrade-s3/demo-files/not_gzipped.json.gz'

pe 'ANALYZE_LOG_SCHEDULE=10 DJANGO_SETTINGS_MODULE=config.settings.local PYTHONPATH=cloudigrade \
    celery -l info -A config worker --beat -Q analyze_log'

screenBreak
###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Malformed json'

echo '### "bad.json.gz" contains malformed JSON.'
echo '### We start processing the log, but upon failing to parse the json,'
echo '### our process aborts and leaves the message on the queue.'
echo

sleep 2

purgeSqs

echo
echo '### Review the file contents and upload it so S3.'
pe 'gunzip -c ${SAMPLE_FILES_DIR}/bad.json.gz'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/bad.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/bad.json.gz'

pe 'ANALYZE_LOG_SCHEDULE=10 DJANGO_SETTINGS_MODULE=config.settings.local PYTHONPATH=cloudigrade \
    celery -l info -A config worker --beat -Q analyze_log'

screenBreak
###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Terminated instance'

echo '### "terminated.json.gz" contains a "StartInstances" event for an instance,'
echo '### but the underlying instance has been terminated and erased from AWS.'
echo '### We process as much as we can, saving an incomplete instance and event'
echo '### without knowing full details, and we delete the message from the queue.'
echo

sleep 2

purgeSqs

echo '### Create a user and account in our system to be the owner of this instance.'
PYTHON_SCRIPT="/Users/brasmith/projects/personal/demo-notes/2018-08-22-robust-log-analyzer.py"
rm -rf $DATAOUT
DJANGO_SETTINGS_MODULE=config.settings.local \
    cat $PYTHON_SCRIPT | python cloudigrade/manage.py shell > $DATAOUT
cat $DATAOUT
sleep 2

echo
echo '### Review the file contents and upload it so S3.'
pe 'gunzip -c ${SAMPLE_FILES_DIR}/terminated.json.gz'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/terminated.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/terminated.json.gz'

pe 'ANALYZE_LOG_SCHEDULE=10 DJANGO_SETTINGS_MODULE=config.settings.local PYTHONPATH=cloudigrade \
    celery -l info -A config worker --beat -Q analyze_log'

screenBreak
###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    "Don't stop me now"

echo '### We put three files in S3 with the middle file having a known failure.'
echo '### The files before and after the failure should process successfully,'
echo "### and the failed file's message should be left on the queue."
echo

sleep 2

purgeSqs

echo
echo '### Upload the previously used "terminated" file as "file1".'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/terminated.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/file1.json.gz'
echo
sleep 1
echo '### Upload the previously used "bad.json.gz" file as "file2".'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/bad.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/file2.json.gz'
echo
sleep 1
echo '### Upload the previously used "terminated" file as "file3".'
pe 'AWS_PROFILE=cluster env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
aws s3 cp ${SAMPLE_FILES_DIR}/terminated.json.gz \
s3://brasmith-cloudigrade-s3/demo-files/file3.json.gz'
echo
sleep 5

pe 'ANALYZE_LOG_SCHEDULE=10 DJANGO_SETTINGS_MODULE=config.settings.local PYTHONPATH=cloudigrade \
    celery -l info -A config worker --beat -Q analyze_log'

dunzo
