# unset AWS_SECRET_ACCESS_KEY AWS_PROFILE AWS_ACCESS_KEY_ID
# oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin purge queue name=copy_ami_snapshot

# see what's currently running in the customer's AWS account
AWS_PROFILE=customer aws ec2 describe-instances --query \
    'Reservations[*].Instances[*].[InstanceId,Platform,State.Name]'

cloudigrade
make oc-login-developer

# obliterate any existing data
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql)\
    scl enable rh-postgresql96 -- psql -c 'truncate account_account cascade;'


CUSTOMER1_AUTH="Authorization:Token 601a839f280d875809cd49bdd7998868d0af0e11"
CUSTOMER1_ARN="arn:aws:iam::518028203513:role/testing-customer-1"
# register the new cloud account. this takes a few seconds...
http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${CUSTOMER1_AUTH}" account_arn="${CUSTOMER1_ARN}" resourcetype=AwsAccount

# check that we found TWO new images and that ONE is windows
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c \
    'select ec2_ami_id,is_windows from account_awsmachineimage ami
    join account_machineimage mi on ami.machineimage_ptr_id = mi.id'



# look directly at the queue to see how many AMIs need inspection
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin list queues

# look at the raw messages on copy_ami_snapshot to verify which AMIs need inspection
oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) \
    rabbitmqadmin get queue=copy_ami_snapshot --format=pretty_json count=99 | \
    jq ".[].payload" | python -c \
    "import sys,json;[print(json.dumps(json.loads(json.loads(l)),indent=4)) for l in sys.stdin]"

# which one was that?
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -x -c \
    "select is_windows,ec2_ami_id from account_awsmachineimage ami
    join account_machineimage mi on ami.machineimage_ptr_id = mi.id
    where ec2_ami_id=''"


# oc rsh -c rabbitmq $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=rabbitmq) rabbitmqadmin get queue=copy_ami_snapshot | less -S




# check the celery worker to see what images it thinks need inspection
oc logs -f $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery) | less

# check that we found two new instances
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -x -c \
    'select * from account_awsinstance ai
    join account_instance i on ai.instance_ptr_id = i.id'



oc logs $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery) | grep
