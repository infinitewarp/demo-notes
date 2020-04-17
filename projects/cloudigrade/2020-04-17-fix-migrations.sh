#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

# SETUP
DEMO_PROMPT='$ '  # force a simple-style PS1
# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

function screenBreak() {
    sleep 3
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    AWS_PROFILE=dev01 aws cloudtrail delete-trail --name ci-273470430754 &>/dev/null
    sleep 5
    clear
    exit
}

function title() {
    toilet -f standard -d /usr/local/share/figlet/fonts/ -t "$1"
}

function header() {
    echo "$1" | sed -e 's/^/### /g'
    echo
    sleep 1
}

clear
export AUTH="insights-qa:redhat"

# gotta go fast?
# NO_WAIT=(true)
# unset TYPE_SPEED

title "fix migrations"

header "Go to a time *before* the most recent migration, reset and migrate
the database, and create 'bad' CloudAccounts that need to be deleted."

pe 'pwd'
# pe 'git log --pretty=oneline --abbrev-commit -n1 3ca571b'
pe 'git checkout a36369a'
pe 'psql -h localhost -U postgres -c "drop schema public cascade; create schema public;" \
    && ./cloudigrade/manage.py migrate \
    && ./cloudigrade/manage.py seed_review_data'

screenBreak

####

header "Give one of those CloudAccounts not-null values so that we can see
it is *not* deleted as part of the upcoming migration."
pe 'psql -U postgres -c "update api_cloudaccount set \
    platform_authentication_id=42, \
    platform_endpoint_id=69, \
    platform_source_id=420, \
    platform_application_id=1701 \
    where id in (select id from api_cloudaccount where name='"'"'user1clount1'"'"' limit 1)"'
pe 'psql -U postgres -c "select id, name, platform_authentication_id as auth, \
    platform_endpoint_id as endpoint, platform_source_id as source, platform_application_id as app \
    from api_cloudaccount order by id"'

screenBreak

####

header "Get the latest code and run the latest and greatest migrations."

pe 'git checkout 663-fix-migrations'
pe './cloudigrade/manage.py migrate'

screenBreak

####

header "Sanity-check the DB contents."

pe 'psql -U postgres -x -c "select * from api_cloudaccount"'
pe 'psql -U postgres -x -c "select * from api_awscloudaccount"'

pe 'psql -U postgres -x -c "select * from api_instance"'
pe 'psql -U postgres -x -c "select * from api_awsinstance"'

pe 'psql -U postgres -x -c "select * from api_instanceevent"'
pe 'psql -U postgres -x -c "select * from api_awsinstanceevent"'

pe 'psql -U postgres -x -c "select * from api_machineimage"'
pe 'psql -U postgres -x -c "select * from api_awsmachineimage"'

pe 'psql -U postgres -x -c "select * from api_run"'
pe 'psql -U postgres -x -c "select * from api_concurrentusage"'

screenBreak
dunzo