#!/usr/bin/env bash
# asciinema rec -y -i3 -c 'bash THIS_FILE'
clear

# IMPORTANT STEPS BEFORE RUNNING!
# 1. Ensure that the cluster is actually scaled down.
# aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names EC2ContainerService-brasmith-houndigrade-us-east-1-EcsInstanceAsg-1V8LKC9ASQFR8 > /tmp/scaling.json
# jq '.AutoScalingGroups[] | {MinSize,MaxSize,DesiredCapacity}' /tmp/scaling.json
# 2. Scale it down if necessary! Then wait a minute to be safe.
# echo "from api.clouds.aws.tasks import scale_down_cluster; scale_down_cluster()" | ./cloudigrade/manage.py shell
# 3. source ~/bin/cloudigrade.sh

#############################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/helpers.sh"

# -d disabled simulated typing
# -n no wait netween commands
# -w1 max wait for 1 second between commands
source ~/projects/personal/demo-magic/demo-magic.sh -w1 # slow
# source ~/projects/personal/demo-magic/demo-magic.sh -n # fast
DEMO_PROMPT='\[$(tput bold)$(tput setaf 2)\]$\[$(tput sgr0)\] '

# gotta go fast? uncomment these:
# NO_WAIT=(true)
# unset TYPE_SPEED
# export SLEEP_SECS="1"

#############################

# make sure some external env vars make it into our commands
export AWS_NAME_PREFIX
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
export AWS_SQS_ACCESS_KEY_ID AWS_SQS_SECRET_ACCESS_KEY AWS_SQS_REGION AWS_SQS_URL QUEUE_CONNECTION_URL
export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME HOUNDIGRADE_ECS_CLUSTER_NAME HOUNDIGRADE_AWS_AVAILABILITY_ZONE
export CLOUDTRAIL_EVENT_URL

function check_cluster_scale() {
    sleep "${SLEEP_SECS}"; header "check current cluster scale"
    pe 'aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME > /tmp/autoscaling.json'
    pe "jq '.AutoScalingGroups[] | {MinSize,MaxSize,DesiredCapacity,Instances}' /tmp/autoscaling.json"
    echo
}

function check_cluster_instance_launch_time() {
    check_cluster_scale
    sleep "${SLEEP_SECS}"; header "check each instance's current state and launch time"
    pe "jq -r '.AutoScalingGroups[].Instances[].InstanceId' /tmp/autoscaling.json | tee /tmp/instanceids.txt"
    pe 'for INSTANCEID in $(cat /tmp/instanceids.txt); do
    aws ec2 describe-instances --filter --instance-ids $INSTANCEID > /tmp/describe-$INSTANCEID.json;
    jq ".Reservations[].Instances[] | {InstanceId,State,LaunchTime}" /tmp/describe-$INSTANCEID.json;
done'
    echo
}

function current_utc_time() {
    sleep "${SLEEP_SECS}"; header "check the current time in UTC"
    pe 'gdate -u "+%Y-%m-%dT%H:%M:%S%z"'
    echo
}

function set_cluster_scale() {
    SCALE=$1
    sleep "${SLEEP_SECS}"; header "manually set cluster scale to $SCALE"
    pe 'aws autoscaling --region=$AWS_DEFAULT_REGION update-auto-scaling-group \
    --auto-scaling-group-name $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    '"--min-size $SCALE --max-size $SCALE --desired-capacity $SCALE"
    echo
}

function scale_up_cluster() {
    set_cluster_scale 1
    pe 'sleep 60'
    echo
}

function scale_down_cluster() {
    set_cluster_scale 0
    pe 'sleep 60'
    echo
}

function python_scale_up_inspection_cluster() {
    sleep "${SLEEP_SECS}"; header "run cloudigrade code to *attempt* scaling up the cluster
and search for logs from inspection.py that may be relevant"
    pe 'echo "from api.clouds.aws.tasks import scale_up_inspection_cluster as s; s()" | \
    ./cloudigrade/manage.py shell 2>&1 | \
    grep inspection.py | \
    cut -d'" '|' -f 1,2,5-99"
    echo
}

#############################

title 'cluster instance age'
header "
https://gitlab.com/cloudigrade/cloudigrade/-/merge_requests/785
https://gitlab.com/cloudigrade/cloudigrade/-/issues/714

Check the age of the ECS cluster's EC2 instances, and alert when
any of them have existed for longer than a configured age limit.

There are no actual image messages given for the cluster to inspect.
So, this just quietly returns after checking the state of the cluster
for each of these demo test cases.
"

p 'export DJANGO_CONSOLE_LOG_LEVEL=DEBUG'
export DJANGO_CONSOLE_LOG_LEVEL=DEBUG
p 'export CLOUDIGRADE_LOG_LEVEL=DEBUG'
export CLOUDIGRADE_LOG_LEVEL=DEBUG

screen_break

#############################

header "
No extra logs when no instances.

In this case, the cluster is scaled down to 0 and has no EC2 instances.
We should expect no interesting additional log messages related to the
presence or age of the cluster's instances to be logged.
"

check_cluster_scale

python_scale_up_inspection_cluster
sleep "${SLEEP_SECS}"; header "note no mention of instances"

screen_break

#############################

header "
INFO and DEBUG logs when instance exists but is young.

In this case, the cluster is scaled up to 1 and has an EC2 instance.
However, the age of the instance is younger than the configured limit.
So, we should expect only an INFO log message about that instance and
a DEBUG log message indicating that its age is under our limit.
"

scale_up_cluster

check_cluster_instance_launch_time
current_utc_time

sleep "${SLEEP_SECS}"; header "set an arbitrarily large age limit"
p 'export INSPECTION_CLUSTER_INSTANCE_AGE_LIMIT=3600'
export INSPECTION_CLUSTER_INSTANCE_AGE_LIMIT=3600
echo

python_scale_up_inspection_cluster
sleep "${SLEEP_SECS}"; header "note those last two log messages regarding the instance"

screen_break

#############################

header "
INFO and ERROR logs when instance exists but too old.

In this case, the cluster is scaled up to 1 and has an EC2 instance.
However, the age of the instance is now older than the configured limit.
So, we should expect only an INFO log message about that instance and
an ERROR log message indicating that its age exceeds our limit.
"

check_cluster_instance_launch_time
current_utc_time

sleep "${SLEEP_SECS}"; header "set an arbitrarily small age limit"
p 'export INSPECTION_CLUSTER_INSTANCE_AGE_LIMIT=30'
export INSPECTION_CLUSTER_INSTANCE_AGE_LIMIT=30
echo

python_scale_up_inspection_cluster
sleep "${SLEEP_SECS}"; header "note those last two log messages regarding the instance"

screen_break

#############################

dunzo
