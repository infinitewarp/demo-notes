#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

export ARN="arn:aws:iam::273470430754:role/role-for-cloudigrade-977153484089"
export ACCOUNT=100001
export HTTP_X_RH_IDENTITY=`echo '{
    "identity": {
        "account_number": "'"$ACCOUNT"'",
        "user": {
            "is_org_admin": true
        }
    }
}' | base64`


# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED

function screen_break() {
    sleep 3
    clear
}

function dunzo() {
    echo
    chafa --symbols solid+space -s 115 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    sleep 5
    clear
    exit
}

function title() {
    toilet -f standard -d /usr/local/share/figlet/fonts/ -t "$1"
}

function header() {
    tput setaf 245
    echo "$1" | sed -e 's/^/### /g'
    tput sgr0
    echo
    sleep 2
}

function reinit_db() {
    pe 'dropdb -U postgres postgres && createdb -U postgres postgres && \
./cloudigrade/manage.py migrate && \
./cloudigrade/manage.py seed_review_data'
}

function start_server() {
    header "starting cloudigrade server"
    ./cloudigrade/manage.py runserver &> /dev/null &
    p './cloudigrade/manage.py runserver &> /dev/null &'
    pe "sleep 2  # give the server a moment to start"
}

function kill_server() {
    header "stopping cloudigrade server"
    pe "ps auxww | grep -v grep | grep 'manage.py runserver' | awk '{print \$2}' | xargs -n1 kill"
}

clear

####


title "clear orphaned tasks"
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/686
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/735

To test the migration that deletes orphaned tasks, this script switches to a
point in the code history before the new migration, registers a cloud account
with a specific ARN, deletes that cloud account, and registers another cloud
account with the same ARN. With the old code, the second cloud account should
not be associated with a periodic task, and the task created for the first
account should have been orphaned.

Switching to the latest code and running migrations should delete that orphaned
task. Also, deleting and recreating the account multiple times with the same
ARN should now correctly link it to its task.

This migration does *not* create new tasks for orphaned cloud accounts. That
will be the responsibility of another periodic cleanup task.
"

# pe 'echo $ARN'
# pe 'echo $ACCOUNT'
pe 'echo $HTTP_X_RH_IDENTITY'

screen_break

################

header "Use previous version of code to set up the data."
pe 'git checkout master'
reinit_db
screen_break

################

start_server
screen_break

################

header "Create a new AwsCloudAccount, delete it, and create it again.
This should result in the second AwsCloudAccount *not* being linked
to the existing PeriodicTask."

pe 'http localhost:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}" \
    cloud_type="aws" \
    account_arn="$ARN" \
    name="yet another account" \
    platform_authentication_id="4000" \
    platform_application_id="3000" \
    platform_endpoint_id="2000" \
    platform_source_id="1000"'

pe 'http delete localhost:8000/api/cloudigrade/v2/accounts/6/ X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}"'

pe 'http localhost:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}" \
    cloud_type="aws" \
    account_arn="$ARN" \
    name="yet another account" \
    platform_authentication_id="4000" \
    platform_application_id="3000" \
    platform_endpoint_id="2000" \
    platform_source_id="1000"'

header "Observe that the PeriodicTask exists, but the new AwsCloudAccount does not know about it."

pe 'psql -U postgres -x -c "select id, created_at, verify_task_id from api_awscloudaccount where account_arn='"'"'$ARN'"'"'"'
pe 'psql -U postgres -x -c "select id, task from django_celery_beat_periodictask where kwargs like '"'%"'$ARN'"%'"'"'

screen_break

################

header "Switch to the latest code and run migrations.
This should result in the orphaned task being deleted."

kill_server
pe 'git checkout 686-verify-task'
pe './cloudigrade/manage.py migrate'
echo
start_server

pe 'psql -U postgres -x -c "select id, task from django_celery_beat_periodictask where kwargs like '"'%"'$ARN'"%'"'"'

screen_break

########

header "Now, verify that new AwsCloudAccounts with the same ARN no longer orphan
their respective PeriodicTasks. Delete the account we just created. Then create,
delete, and create it again with the same ARN. Verify that the final account is
correctly linked to the task."

pe 'http delete localhost:8000/api/cloudigrade/v2/accounts/7/ X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}"'

pe 'http localhost:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}" \
    cloud_type="aws" \
    account_arn="$ARN" \
    name="yet another account" \
    platform_authentication_id="4000" \
    platform_application_id="3000" \
    platform_endpoint_id="2000" \
    platform_source_id="1000"'

pe 'http delete localhost:8000/api/cloudigrade/v2/accounts/8/ X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}"'

pe 'http localhost:8000/api/cloudigrade/v2/accounts/ \
    X-RH-IDENTITY:"${HTTP_X_RH_IDENTITY}" \
    cloud_type="aws" \
    account_arn="$ARN" \
    name="yet another account" \
    platform_authentication_id="4000" \
    platform_application_id="3000" \
    platform_endpoint_id="2000" \
    platform_source_id="1000"'

header "Observe that the new AwsCloudAccount references the correct PeriodicTask."

pe 'psql -U postgres -x -c "select id, created_at, verify_task_id from api_awscloudaccount where account_arn='"'"'$ARN'"'"'"'
pe 'psql -U postgres -x -c "select id, task from django_celery_beat_periodictask where kwargs like '"'%"'$ARN'"%'"'"'


kill_server
clear
dunzo
