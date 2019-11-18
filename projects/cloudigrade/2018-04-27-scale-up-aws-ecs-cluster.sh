# 176 scale up cluster demo

#----------

# DEMO 01
# scheduled task runs, but it aborts because the cluster is already scaled up

#----------

# INITIAL PREP
# expose rabbitmq locally
make oc-forward-ports

# scale up the cluster to 1
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --min-size 1 \
    --max-size 1 \
    --desired-capacity 1

asciinema rec

cloudigrade

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# check the current scale
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --query 'AutoScalingGroups[*].[MinSize,MaxSize,DesiredCapacity,Instances[*].InstanceId]'

# because the scale is nonzero, attempting to scale it up should promptly exit with some info logs

export SCALE_UP_INSPECTION_CLUSTER_SCHEDULE=10  # reduce schedule to every 10 seconds for testing

PYTHONPATH=cloudigrade celery -l info -A config worker -B --beat --scheduler django_celery_beat.schedulers:DatabaseScheduler

#----------

# DEMO 02
# scheduled task runs, but it aborts because there are no messages on the queue

# INITIAL PREP
# expose rabbitmq locally
make oc-forward-ports

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# scale down the cluster to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --min-size 0 \
    --max-size 0 \
    --desired-capacity 0

oc login

# --------

asciinema rec

cloudigrade

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# check the current scale
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --query 'AutoScalingGroups[*].[MinSize,MaxSize,DesiredCapacity,Instances[*].InstanceId]'


# verify task is recorded by the scheduler
# psql -U postgres -h 127.0.0.1 -p 5432 -x -c 'select * from django_celery_beat_periodictask'


# check the queue
oc get pods
oc rsh -c rabbitmq
rabbitmqadmin list queues
rabbitmqadmin delete queue name=ready_volumes
quit

oc rsh -c rabbitmq
rabbitmqadmin list queues


# because the queue is empty, attempting to scale the cluster should promptly exit with some info logs

export SCALE_UP_INSPECTION_CLUSTER_SCHEDULE=10  # reduce schedule to every 10 seconds for testing

PYTHONPATH=cloudigrade celery -l info -A config worker -B --beat --scheduler django_celery_beat.schedulers:DatabaseScheduler


#----------

# DEMO 03
# scheduled task runs, and it does things normally for 1 message

# INITIAL PREP
# expose rabbitmq locally
make oc-forward-ports

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# scale down the cluster to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --min-size 0 \
    --max-size 0 \
    --desired-capacity 0

oc login

# --------

asciinema rec

cloudigrade

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# check the current scale AGAIN
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --query 'AutoScalingGroups[*].[MinSize,MaxSize,DesiredCapacity,Instances[*].InstanceId]'

# check the queue
oc get pods
oc rsh -c rabbitmq
rabbitmqadmin list queues
rabbitmqadmin delete queue name=ready_volumes
quit

# we need to enqueue a message
python cloudigrade/manage.py shell -c "from account.tasks import enqueue_ready_volume; enqueue_ready_volume('import-ami-05c88748fa241d139', 'vol-027078f6ae277654f', 'us-east-1')"

# check the queue again
oc rsh -c rabbitmq
rabbitmqadmin list queues

# the task to scale the cluster should actually scale it up!

export SCALE_UP_INSPECTION_CLUSTER_SCHEDULE=10  # reduce schedule to every 10 seconds for testing

PYTHONPATH=cloudigrade celery -l info -A config worker -B --beat --scheduler django_celery_beat.schedulers:DatabaseScheduler

# check the queue to verify the message was consumed
oc rsh -c rabbitmq
rabbitmqadmin list queues



# check current scale
# check, empty, and put a message on the queue
# run the task

# --------------

# Demo 4
# too many queued items


# INITIAL PREP
# expose rabbitmq locally
make oc-forward-ports

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# scale down the cluster to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --min-size 0 \
    --max-size 0 \
    --desired-capacity 0

oc login

# obliterate the ready_volumes queue
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin delete queue name=ready_volumes
# check the queue
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin list queues
# we need to enqueue a bunch of messages
python cloudigrade/manage.py shell -c "from account.tasks import enqueue_ready_volume; [enqueue_ready_volume('import-ami-05c88748fa241d139', 'vol-027078f6ae277654f', 'us-east-1') for _ in range(50)]"


# --------

asciinema rec

cloudigrade

export HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME="EC2ContainerService-inspectigrade-test-bws-us-east-1b-EcsInstanceAsg-JG9NX9WHX6NU"

# check the current scale
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $HOUNDIGRADE_AWS_AUTOSCALING_GROUP_NAME \
    --query 'AutoScalingGroups[*].[MinSize,MaxSize,DesiredCapacity,Instances[*].InstanceId]'

# check the queue
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin list queues

# the task to scale the cluster should scale up and only pull a few messages

export SCALE_UP_INSPECTION_CLUSTER_SCHEDULE=10  # reduce schedule to every 10 seconds for testing
export HOUNDIGRADE_AWS_VOLUME_BATCH_SIZE=5 # reduce the batch size to 5 for testing

PYTHONPATH=cloudigrade celery -l info -A config worker -B --beat --scheduler django_celery_beat.schedulers:DatabaseScheduler

# check the queue to verify that only 5 messages were consumed
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin list queues

