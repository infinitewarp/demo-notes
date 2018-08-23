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

# export BASE_URL="http://cloudigrade.127.0.0.1.nip.io"
export BASE_URL="http://127.0.0.1:8000"

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -n
# source ~/projects/personal/demo-magic/demo-magic.sh -d -w1
DATAOUT="/tmp/clouditestdata.txt"

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
    sleep 1
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

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null
resetDb

PYTHON_SCRIPT="/Users/brasmith/projects/personal/demo-notes/2018-08-23-end-date-truncation.py"
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

echo '### Get image activity for past period'
echo '### Should have three images:'
echo '### - 1 named image (plain) with 3600 sec of activity'
echo '### - 1 named image (with RHEL) with 7200 sec of activity'
echo '### - 1 unnamed image (with OCP) with 3600 sec of activity'

pe 'http ${BASE_URL}/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-01T00:00:00" \
    end=="2018-02-01T00:00:00" \
    account_id==1'

screenBreak
###############

echo '### Get image activity for this whole month'
echo '### Should have three images:'
echo '### - 1 named image (plain) with XXX sec of activity'
echo '### - 1 named image (with RHEL) with YYY sec of activity'
echo '### - 1 unnamed image (with OCP) with ZZZ sec of activity'

pe 'http ${BASE_URL}/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-08-01T00:00:00" \
    end=="2018-09-01T00:00:00" \
    account_id==1'

screenBreak
###############

echo '### Get instances activity for this whole month.'

pe 'http ${BASE_URL}/api/v1/report/instances/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-08-01T00:00:00" \
    end=="2018-09-01T00:00:00"'
