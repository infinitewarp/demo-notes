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
    'Cloud Accounts: Name Filter'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/419'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/428'
echo
echo '### Generate a bunch of activity data, authenticate as regular and super'
echo '### users, and run various queries as each user to check filter behaviors.'

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


PYTHON_SCRIPT=$(echo $0 | sed 's/\.sh$/\.py/')
rm -rf $DATAOUT
DJANGO_SETTINGS_MODULE=config.settings.local \
    cat $PYTHON_SCRIPT | python cloudigrade/manage.py shell > $DATAOUT
cat $DATAOUT

screenBreak
###############

echo '### Get authentication tokens for a regular user and a super user.'
sleep 1

USER_USERNAME=$(grep '^user:id=1' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
auth_token $USER_USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"

SUPER_USERNAME=$(grep '^user:id=2' $DATAOUT | cut -d ";" -f 2 | cut -d = -f 2)
auth_token $SUPER_USERNAME
SUPER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "SUPER_TOKEN=$SUPER_TOKEN"

screenBreak
###############

echo '### Get all accounts for the regular user.'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

screenBreak
###############

echo '### Get accounts for the regular user filtered by name "eat tofu".'
echo '### This should include the account named "greatest account ever" because it'
echo '### contains the word "eat", but no account names contain the word "tofu".'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="eat tofu"'

screenBreak
###############

echo '### Get accounts for the regular user filtered by name "eat NOT".'
echo '### This should include the account named "greatest account ever" because it'
echo '### contains the word "eat", and it should also include the account named '
echo '### "just another account" because it contains the word "NOT" (case insensitive).'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="eat NOT"'

screenBreak
###############

echo '### Get accounts for the regular user filtered by name "spaghetti".'
echo '### This should return nothing because no accounts belonging to the regular'
echo '### user have a name that contains the word "spaghetti".'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="spaghetti"'

screenBreak
###############

echo '### Get all accounts for the super user.'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'

screenBreak
###############

echo '### Get accounts for the super user filtered by name "spaghetti".'
echo '### There is only one account, and its name contains "spaghetti".'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="spaghetti"'

screenBreak
###############

echo '### Get accounts for the super user filtered by name "eat".'
echo '### This should return nothing because no accounts belonging to the super'
echo '### user have a name that contains the word "eat".'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="eat"'

screenBreak
###############

echo '### As the super user, get all accounts for the regular user.'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    user_id==1'

screenBreak
###############

echo '### As the super user, get accounts for the regular user filtered by name "eat tofu".'
echo '### This should behave like the earlier query as the regular user and return'
echo '### the one account named "greatest account ever".'
sleep 1

pe 'http http://localhost:8080/api/v1/report/accounts/ \
    Authorization:"Token ${SUPER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    name_pattern=="eat tofu" \
    user_id==1'

dunzo
