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
export API_REPO_REF=420-report-images
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

export CUSTOMER_ACCOUNT="273470430754"
export CUSTOMER_ARN="arn:aws:iam::$CUSTOMER_ACCOUNT:role/role-for-cloudigrade"
export DJANGO_SETTINGS_MODULE=config.settings.local
source "$(brew --prefix)/bin/virtualenvwrapper.sh"
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

    oc rsh -c cloudigrade-api \
        $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api) \
        scl enable rh-postgresql96 rh-python36 -- \
        python manage.py migrate \
        2>&1 >/dev/null
}

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Image Activity Summary'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/420'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/438'
echo
echo '### Create a user, register a cloud account (with 2 running instances) for'
echo '### that user, and query the image activity summary report to see some data.'

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null
resetDb

screenBreak
###############

echo '### Authenticate'

USERNAME="customer@example.com"
create_user $USERNAME
auth_token $USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"
p "CUSTOMER_ARN="$CUSTOMER_ARN

screenBreak
###############

echo '### Register the cloud account for the user.'

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${USER_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="best 🤖☁️💕 account ever"'

screenBreak
##############

echo '### Get accounts activity report for this user.'

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-08-01T00:00:00" \
    end=="2018-09-01T00:00:00"'

screenBreak
##############

echo '### Get images activity report for this user.'
echo '### We expect some nulls and falses on the objects listed here because we'
echo '### have not waited long enough for the inspection to complete.'

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-08-01T00:00:00" \
    end=="2018-09-01T00:00:00" \
    account_id==1'

dunzo
