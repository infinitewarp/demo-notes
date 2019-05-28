#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

<<PREREQ
cloudigrade
cd ../shiftigrade/
make oc-clean
make oc-up-db
make oc-forward-ports
PREREQ

clear

# SETUP
source $(which virtualenvwrapper.sh)
# source ~/projects/personal/demo-magic/demo-magic.sh -d -w1
source ~/projects/personal/demo-magic/demo-magic.sh -w1

function screenBreak() {
    # p
    sleep 2
    clear
}

function dunzo() {
    sleep 1
    clear
    echo
    chafa --symbols solid+space -s 140x35 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
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
    ./cloudigrade/manage.py migrate &>/dev/null
}

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Filter running since datetime'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/560'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/625'
echo
echo '### Optional filter for instances current running since given time.'
echo

p 'cloudigrade'
source ~/bin/cloudigrade.sh &>/dev/null
resetDb

echo
echo '###'
echo '### Use the seed_review_data command to give us some data to look at.'
echo '###'
echo
pe './cloudigrade/manage.py seed_review_data'
echo
sleep 2

echo '###'
echo '### Start the cloudigrade server locally in the background.'
echo '###'
echo
# resetting PYTHONPATH is necessary here because django's runserver command throws fits
# for some unobvious reason when inside a virtualenv inside demo-magic inside asciinema.
# too many onion layers, I suppose!
export PYTHONPATH=/Users/brasmith/.virtualenvs/cloudigrade-bLsR_uSj/lib/python3.7/site-packages
pe './cloudigrade/manage.py runserver localhost:8000 &>/dev/null &'
sleep 1

screenBreak
#########################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t "user 1 instances"
echo
echo '### "user1" has several instances in the seed data.'
echo '### Some of the instances have been powered on at some past time.'
echo '### However, none of the instances are "currently" running.'
echo
sleep 2

USER1_IDENTITY=$(echo '{"identity": {"user": {"email": "user1@example.com"}}}' | base64)

echo
echo '###'
echo '### List all user1 instances without filtering; it should be 4.'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER1_IDENTITY}" | jq ".meta"'
echo
sleep 2

echo '###'
echo '### List all user1 instances running since "this morning"; it should be 0.'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER1_IDENTITY}" running_since=="2019-05-28T00:00:00" | jq ".meta"'
sleep 2

screenBreak
#########################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t "user 2 instances"
echo
echo '### "user2" has several instances in the seed data.'
echo '### Seven instances have been powered on at some past time.'
echo '### Of those, four instances are "currently" running:'
echo '###'
echo '###   - 2 running since 2019-04-30'
echo '###   - 1 running since 2019-04-19'
echo '###   - 1 running since 2019-04-13'
echo
sleep 2

USER2_IDENTITY=$(echo '{"identity": {"user": {"email": "user2@example.com"}}}' | base64)

echo
echo '###'
echo '### List all user2 instances without filtering; it should be 7.'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" | jq ".meta"'
echo
sleep 2

echo '###'
echo '### List all user2 instances running since "this morning"; it should be 4.'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" running_since=="2019-05-28T00:00:00" | jq ".meta"'
echo
sleep 2

echo '###'
echo '### List all user2 instances running since 2019-05-01; it should be 4.'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" running_since=="2019-05-01T00:00:00" | jq ".meta"'
echo
sleep 2

echo '###'
echo '### List all user2 instances running since 2019-04-29; it should be 2.'
echo '### (because the instances that last started on 2019-04-30 are excluded)'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" running_since=="2019-04-29T00:00:00" | jq ".meta"'
sleep 2

echo
echo '###'
echo '### List all user2 instances running since 2019-04-18; it should be 1.'
echo '### (because the instance that last started on 2019-04-19 is excluded)'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" running_since=="2019-04-18T00:00:00" | jq ".meta"'
sleep 2

echo
echo '###'
echo '### List all user2 instances running since 2019-04-12; it should be 0.'
echo '### (because the instance that last started on 2019-04-13 is excluded)'
echo '###'
echo
pe 'http localhost:8000/v2/instances/ "X-RH-IDENTITY:${USER2_IDENTITY}" running_since=="2019-04-12T00:00:00" | jq ".meta"'
sleep 2

ps | grep 'manage.py runserver localhost:8000' | grep '/python' | awk '{print $1}' | xargs kill
dunzo
