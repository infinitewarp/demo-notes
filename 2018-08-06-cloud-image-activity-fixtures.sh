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

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1
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
    sleep 3
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
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/432'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/430'
echo
echo '### Generate a bunch of activity data, authenticate as regular user,'
echo '### and query the API to see the image data under various filters.'

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null
resetDb

# exit

PYTHON_SCRIPT="/Users/brasmith/projects/personal/demo-notes/2018-08-06-cloud-image-activity-fixtures.py"
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

echo '### Get accounts activity report for the regular user.'
echo '### - 1 account has 3 images active on 4 instances'
echo '### - 1 account has 0 images active on 0 instances'
sleep 1

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/accounts/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00"'


screenBreak
###############

echo '### Get active images for an account under the regular user.'
echo '### There should be 3 images active in this time period:'
echo '### - 1 named image (plain) with 1 instance of activity'
echo '### - 1 named image (with RHEL) with 2 instances of activity'
echo '### - 1 unnamed image (with OCP) with 1 instance of activity'
sleep 1

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    account_id==1'


screenBreak
###############

echo '### Get activity filtered to the past.'
echo '### There should be 0 images because the date filters predate the activity.'
sleep 1

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2017-01-10T00:00:00" \
    end=="2017-01-15T00:00:00" \
    account_id==1'


screenBreak
###############

echo '### Get activity filtered to different account.'
echo '### There should be 0 images because only the first account has activity'
echo '### during the requested time period.'
sleep 1

pe 'http http://cloudigrade.127.0.0.1.nip.io/api/v1/report/images/ \
    Authorization:"Token ${USER_TOKEN}" \
    start=="2018-01-10T00:00:00" \
    end=="2018-01-15T00:00:00" \
    account_id==2'

dunzo
