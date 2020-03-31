#!/usr/bin/env bash
# asciinema rec -i2 -c THIS_FILE

# BEFORE RUNNING
# oc login
# oc project cloudigrade-ci

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

title "inspection scale-down"
header "
https://gitlab.com/cloudigrade/cloudigrade/-/issues/653
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/717

When run_inspection_cluster runs as part of image inspection, we need to
scale down the cluster if we find no matching images in our DB. This can happen
if an account using a pending-inspection image is deleted while the inspection
process is preparing (e.g. while we are waiting to copy AWS AMIs).
"

screenBreak

####

header "Capture the current time for reference, and then manually
trigger the run_inspection_cluster with a message containing an
AMI ID unknown to cloudigrade."

CMD='date -u +"%Y-%m-%dT%H:%M:%SZ"'
p 'STARTTIME=$('"$CMD"')'
export STARTTIME=$(eval "$CMD")
pe 'echo $STARTTIME'

pe "oc rsh -c cloudigrade-api $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-api  | awk '{print $1}') ./manage.py shell"

# from api.clouds.aws.tasks import run_inspection_cluster
# messages = [{"ami_id": "potato"}]
# run_inspection_cluster(messages)

screenBreak

####

header "Look in the worker logs for a message since we started that
indicates the scale_down_cluster task was called and handled."

pe 'for POD in $(oc get pods -o jsonpath='"'"'{.items[?(.status.phase=="Running")].metadata.name}'"'"' -l name=cloudigrade-worker)
do
    oc logs $POD --since-time="$STARTTIME" | grep -E "(Received task.*scale_down_cluster)|(scale_down_cluster.*succeeded)" | cut -d "|" -f 1,5
done'

screenBreak
dunzo