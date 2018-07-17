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

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Daily Instance Usage Report, part 2'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/355'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/416'
echo
echo '### Generate data for the same instance starting and stopping three'
echo '### times on the same day, and verify it only contributes once to the'
echo '### instance counter.'

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

rm -rf $DATAOUT
DJANGO_SETTINGS_MODULE=config.settings.local \
    cat /Users/brasmith/projects/personal/demo-notes/2018-07-17-daily-usage-report.py | \
    python cloudigrade/manage.py shell > $DATAOUT
cat $DATAOUT

p
sleep 5
clear

USER1_USERNAME=$(grep '^user_1\.id' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
auth_token $USER1_USERNAME
USER1_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER1_TOKEN=$USER1_TOKEN"

p
sleep 5
clear

###############

echo '### Report over the active day. Should have 1 RHEL instance on 2018-01-11'
echo '### with 3 hours (10800) seconds: 1 hour for each of the 3 times it ran.'
sleep 2
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER1_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

p

sleep 1
echo
echo "🎉 🏆 🥇"
echo
sleep 5
clear
