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
    'Daily Instance Usage Report'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/355'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/416'
echo
echo '### Generate a bunch of data and then request report results as each of'
echo '### the users with various optional filters applied.'

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

echo '### Generating test data for demo in cloudigrade...'
echo '### This generated data includes a mix of events for instances backed by'
echo '### 1 plain image, 1 RHEL image, 1 OCP image, and 1 RHEL+OCP image.'
echo "### All events belong to user_1's account_1 and user_1's account_2."
echo '### Some events are before, during, and after the requested report times.'
echo '### user_2 has no data of its own, and user_super has no data of its own.'
echo '### Feel free to pause playback if you want to check the actual times and'
echo '### do some arithmetic to double-check the values in the report results!'
echo

rm -rf $DATAOUT
DJANGO_SETTINGS_MODULE=config.settings.local \
    cat /Users/brasmith/projects/personal/demo-notes/2018-07-16-daily-usage-report.py | \
    python cloudigrade/manage.py shell > $DATAOUT
cat $DATAOUT

p
sleep 5
clear

echo '### Remember part of one of the account names for later use in a filter,'
echo '### and then authenticate each user to save the tokens for API requests.'
echo

ACCOUNT1_NAME=$(grep '^account_1\.id' $DATAOUT | cut -d ";" -f 3 | cut -d = -f 2)
ACCOUNT1_NAME_WORD1_PART=$(echo $ACCOUNT1_NAME | cut -d " " -f 1 | cut -c 2-99 )
ACCOUNT1_NAME_WORD3_PART=$(echo $ACCOUNT1_NAME | cut -d " " -f 3 | cut -c 2-99)
ACCOUNT_NAME_FILTER_PATTERN="$ACCOUNT1_NAME_WORD1_PART $ACCOUNT1_NAME_WORD3_PART"
p "ACCOUNT1_NAME=\"$ACCOUNT1_NAME\""
p 'ACCOUNT_NAME_FILTER_PATTERN="$(echo $ACCOUNT1_NAME | cut -d " " -f 1 | cut -c 2-99 ) $(echo $ACCOUNT1_NAME | cut -d " " -f 1 | cut -c 2-99 )"'
pe 'echo $ACCOUNT_NAME_FILTER_PATTERN'

USER1_ID=$(grep '^user_1\.id' $DATAOUT | cut -d ";" -f 1 | cut -d = -f 2)
USER1_USERNAME=$(grep '^user_1\.id' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
USER2_USERNAME=$(grep '^user_2\.id' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
USER_SUPER_USERNAME=$(grep '^user_super\.id' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)

auth_token $USER1_USERNAME
USER1_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"

auth_token $USER2_USERNAME
USER2_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"

auth_token $USER_SUPER_USERNAME
USER_SUPER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"

p "USER1_ID=$USER1_ID"
p "USER1_TOKEN=$USER1_TOKEN"
p "USER2_TOKEN=$USER2_TOKEN"
p "USER_SUPER_TOKEN=$USER_SUPER_TOKEN"

p
sleep 5
clear

###############

echo '### Report as user_1. This should get all the generated data.'
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER1_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

p
sleep 5
clear

echo '### Report as user_1 again, but with the partial account name filter.'
echo '### This should result in smaller numbers than the previous response.'
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER1_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="$ACCOUNT_NAME_FILTER_PATTERN"'

p
sleep 5
clear

echo '### Report as user_2 who has no data.'
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER2_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

p
sleep 5
clear

echo '### Report as user_2 attempting to get user_1 data.'
echo '### Filter should be ignored because user_2 is not super.'
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER2_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    user_id=="$USER1_ID"'

p
sleep 5
clear

echo '### Report as superuser attempting to get user_1 data.'
echo "### Should get user_1 data because superuser is super."
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER_SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    user_id=="$USER1_ID"'

p
sleep 5
clear

echo '### Report as superuser attempting to get user_1 data with name filter.'
echo "### Should get match same result from user_1's earlier filtered request."
sleep 1
pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/instances/ \
    Authorization:"Token ${USER_SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    user_id=="$USER1_ID" \
    name_pattern=="$ACCOUNT_NAME_FILTER_PATTERN"'

p

sleep 1
echo
echo "🎉 🏆 🥇"
echo
sleep 5
clear
