#!/usr/bin/env bash
#
# asciinema rec -c ~/projects/personal/demo-notes/2018-06-28-copy-private-ami.sh

clear

<<PREREQ
make oc-clean
make oc-up-all
make oc-forward-ports
export API_REPO_REF=357-handle-shared-private-images
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade
# scale down and back up celery to reset logs
PREREQ

export CUSTOMER_ACCOUNT="273470430754"
export CUSTOMER_ARN="arn:aws:iam::$CUSTOMER_ACCOUNT:role/role-for-cloudigrade"
source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Private AMI Copy Demo'
echo '### https://github.com/cloudigrade/cloudigrade/issues/357'
echo '### https://github.com/cloudigrade/cloudigrade/pull/372'
echo '### https://github.com/cloudigrade/shiftigrade/pull/19'
echo
echo '### First, look in the customer AWS account to verify that an instance is'
echo '### running from a shared image. In that case, we must copy the image to'
echo '### the customer account before copying the snapshot to our account.'

sleep 5

pe 'AWS_PROFILE=customer env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    aws --region=us-east-1 ec2 describe-instances \
    --query "Reservations[*].{OwnerId:OwnerId,Instances:Instances[*].{InstanceId:InstanceId,ImageId:ImageId}}" \
    --filters Name=instance-state-name,Values=running \
    --output json'
pe 'AWS_PROFILE=customer env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    aws --region=us-east-1 ec2 describe-images \
    --image=ami-065d0be9883aa064a \
    --query "Images[*].{OwnerId:OwnerId,ImageId:ImageId}" \
    --output json'

echo
echo '### Observe that the `OwnerId`s are different!!'
echo '### This happens when the AWS account (273470430754) is running an instance'
echo '### using an image shared from a different AWS account (518028203513).'
sleep 5
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'AWS customer images'
echo "### List images in the customer AWS account *before* we do any copying."
echo "### In this example, we should see 2 existing (but irrelevant) images."
sleep 5

pe 'AWS_PROFILE=customer env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    aws --region=us-east-1 ec2 describe-images \
    --filters Name=owner-id,Values=273470430754 \
    --query "Images[*].{ImageId:ImageId,Name:Name}"'

p
sleep 5
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'cloudigrade setup'
sleep 2

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null

# https://youtu.be/jmVyUdHtxbU
oc rsh -c postgresql \
    $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c \
    'drop schema public cascade; create schema public;' \
    2>&1 >/dev/null

DJANGO_SETTINGS_MODULE=config.settings.local \
    python cloudigrade/manage.py migrate \
    2>&1 >/dev/null

USERNAME=customer1
p "make oc-user"
expect -c "spawn make oc-user
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect \"?ddress:\"
        send \"\r\"
        expect \"?ssword:\"
        send \"$USERNAME\r\"
        expect \"?ssword \(again\):\"
        send \"$USERNAME\r\"
        expect eof" 2>&1 | grep -v "spawn"

rm -rf /tmp/token
p 'make oc-user-authenticate'
expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | grep -v 'spawn' | tee >(grep 'Generated token' > /tmp/token)
CLOUDIGRADE_TOKEN=$(cat /tmp/token | cut -d ' ' -f 3)
p "CLOUDIGRADE_TOKEN=$CLOUDIGRADE_TOKEN"
p "CUSTOMER_ARN="$CUSTOMER_ARN

p
sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Register AWS account.'
echo "### Register the customer's AWS account."
echo '### Wait for Celery to run tasks...'

sleep 5

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}"'

p 'CELERY_POD=$(oc get pods -o jsonpath="{.items[*].metadata.name}" -l name=cloudigrade-celery)'
export CELERY_POD=$(oc get pods -o jsonpath="{.items[*].metadata.name}" -l name=cloudigrade-celery)
pe 'until [ "$(oc logs $CELERY_POD | grep "account.tasks.copy_ami_snapshot" | grep "succeeded" -c)" -eq "2" ]; do echo "### ($(date +%H:%M:%S)) waiting until we see 2 copy_ami_snapshot tasks succeed; this may take a while..."; sleep 5; done'
echo '### Celery task `copy_ami_snapshot` completed twice!  🎉'
sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Check the copy!'
echo "### List images again in the customer account. It should have 3 now."
echo '### Show the content of our relevant database tables.'
sleep 5

pe 'AWS_PROFILE=customer env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY \
    aws --region=us-east-1 ec2 describe-images \
    --filters Name=owner-id,Values=273470430754 \
    --query "Images[*].{ImageId:ImageId,Name:Name}"'

sleep 2

pe "oc rsh -c postgresql \
    $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c 'select * from account_awsmachineimage'"
sleep 1
pe "oc rsh -c postgresql \
    $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c 'select * from account_awsmachineimagecopy'"
sleep 1
pe "oc rsh -c postgresql \
    $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c 'select * from account_awsinstanceevent'"
sleep 3

echo '### We know about the copy relating to the original reference image, and'
echo '### the event still looks it came from the original reference image.'
echo
echo "🎉  🎉  🎉  🎉"
echo
sleep 5
clear
