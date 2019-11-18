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
export API_REPO_REF=498-serializers
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

export BASE_URL="http://cloudigrade.127.0.0.1.nip.io"
# export BASE_URL="http://127.0.0.1:8000"

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
# source ~/projects/personal/demo-magic/demo-magic.sh -d -n
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

SUPER_USERNAME="admin@example.com"


function make_user() {
    p 'cd ../shiftigrade'
    cd ../shiftigrade
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
    p 'cd ../cloudigrade'
    cd ../cloudigrade
}

function auth_token() {
    p 'cd ../shiftigrade'
    cd ../shiftigrade
    USERNAME=$1
    rm -rf /tmp/token
    p 'make oc-user-authenticate'
    expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | \
        grep -v 'spawn' | \
        tee >(grep 'Generated token' > /tmp/token)
    p 'cd ../cloudigrade'
    cd ../cloudigrade
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
        scl enable rh-python36 -- \
        python manage.py migrate \
        2>&1 >/dev/null
}


##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'REST ALL THE THINGS'

echo '### This demo shows that the REST API responses include all the latest properties.'
sleep 2

p 'cloudigrade'
source ~/bin/cloudigrade.sh
cd ../shiftigrade
make oc-login-developer 2>&1 >/dev/null
cd ../cloudigrade
resetDb
make_user $SUPER_USERNAME


SPAWNDATA_CMD="./cloudigrade/manage.py spawndata 1 '$(date -v1d -v -1m +%Y-%m-%d)' --image_count 10 --instance_count 100 --rhel_chance 1.0"
p "$SPAWNDATA_CMD"
expect -c "spawn $SPAWNDATA_CMD
    expect \"?proceed:\"
    send \"YES\r\"
    expect eof" 2>&1 | grep -v "spawn"

screenBreak
###############

echo '### Authenticate'

auth_token $SUPER_USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"

screenBreak
###############

echo '### Get an account'
sleep 1

pe 'http ${BASE_URL}/api/v1/account/1/ \
    Authorization:"Token ${USER_TOKEN}"'

screenBreak
###############

echo '### Get an image'
sleep 1

pe 'http ${BASE_URL}/api/v1/image/1/ \
    Authorization:"Token ${USER_TOKEN}"'

screenBreak
###############

echo '### Get an instance'
sleep 1

pe 'http ${BASE_URL}/api/v1/instance/1/ \
    Authorization:"Token ${USER_TOKEN}"'

screenBreak
###############

echo '### Get an event'
sleep 1

pe 'http ${BASE_URL}/api/v1/event/1/ \
    Authorization:"Token ${USER_TOKEN}"'

dunzo
