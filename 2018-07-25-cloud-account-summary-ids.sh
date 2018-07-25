#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear

<<PREREQ
make oc-clean
make oc-up-all
make oc-forward-ports
export API_REPO_REF=355-report-daily-instance-activity
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

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

DATAOUT="/tmp/clouditestdata.txt"

function screenBreak() {
    p
    sleep 5
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

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Cloud Account IDs'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/432'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/430'
echo
echo '### Generate a bunch of activity data, authenticate as regular user,'
echo '### and query the account summaries API to see the correct IDs.'

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null

# https://youtu.be/jmVyUdHtxbU
oc rsh -c postgresql \
    $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c \
    'drop schema public cascade; create schema public;' \
    2>&1 >/dev/null

DJANGO_SETTINGS_MODULE=config.settings.local \
    python cloudigrade/manage.py migrate \
    2>&1 >/dev/null


# Use the data generated for a previous demo since we don't need anything else.
PYTHON_SCRIPT="/Users/brasmith/projects/personal/demo-notes/2018-07-19-cloud-account-summary-filter-by-name.py"
rm -rf $DATAOUT
DJANGO_SETTINGS_MODULE=config.settings.local \
    cat $PYTHON_SCRIPT | python cloudigrade/manage.py shell > $DATAOUT
cat $DATAOUT

screenBreak
###############

echo '### Authenticate'

USER_USERNAME=$(grep '^user:id=1' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
auth_token $USER_USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"

screenBreak
###############

echo '### Get all active accounts for the regular user.'
echo '### Observe that the accounts have both `id` and `cloud_account_id` values.'

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

dunzo
