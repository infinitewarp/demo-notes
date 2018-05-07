# see what's currently running in the customer's AWS account
AWS_PROFILE=customer aws ec2 describe-instances --query \
 'Reservations[*].Instances[*].[InstanceId,State.Name,Platform]'

cloudigrade

# oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) scl enable rh-postgresql96 -- psql -c 'delete from account_awsinstanceevent; delete from account_instanceevent; delete from account_awsmachineimage; delete from account_machineimage; delete from account_awsinstance; delete from account_instance; delete from account_awsaccount; delete from account_account;'
# make oc-build-and-push-cloudigrade
# http post http://127.0.0.1:8000/api/v1/account/ "${AUTH}" account_arn="${ARN}" resourcetype=AwsAccount

make oc-user-authenticate

AUTH="Authorization:Token "
AID="518028203513" ARN="arn:aws:iam::${AID}:role/grant_cloudi_to_372779871274"

# register the new cloud account. this takes a few seconds...
http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${AUTH}" account_arn="${ARN}" resourcetype=AwsAccount

# check that we found a new instance
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) scl enable rh-postgresql96 -- psql -x -c 'select * from account_awsinstance ai join account_instance i on ai.instance_ptr_id = i.id'

# check that we found a new images and that it's windows
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) scl enable rh-postgresql96 -- psql -x -c 'select * from account_awsmachineimage ami join account_machineimage mi on ami.machineimage_ptr_id = mi.id'

