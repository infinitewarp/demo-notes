AUTH="Authorization:Token 7089e7fa0401c603871e34a4c20c87418cb4b560"
AID="518028203513" ARN="arn:aws:iam::${AID}:role/grant_cloudi_to_372779871274"
clear

# register account with running instance
http post localhost:8081/api/v1/account/ "${AUTH}" account_arn="${ARN}" resourcetype=AwsAccount

clear

# run task worker
PYTHONPATH=cloudigrade celery -A config worker -l info -Q copy_ami_snapshot,create_volume

AWS_PROFILE=redhat aws ec2 describe-volumes \
    --filters Name=volume-id,Values=vol-004e903ad84110b94
