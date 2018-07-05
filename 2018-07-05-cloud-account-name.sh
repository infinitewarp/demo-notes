#!/usr/bin/env bash
#
# asciinema rec -c ~/projects/personal/demo-notes/2018-07-05-cloud-account-name.sh

clear

<<PREREQ
make oc-clean
make oc-up-all
make oc-forward-ports
export API_REPO_REF=267-cloud-account-name
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

export CUSTOMER_ACCOUNT="273470430754"
export CUSTOMER_ARN="arn:aws:iam::$CUSTOMER_ACCOUNT:role/role-for-cloudigrade"
source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Cloud Account Name Demo'
echo '### https://github.com/cloudigrade/cloudigrade/issues/267'
echo '### https://github.com/cloudigrade/cloudigrade/pull/400'
echo
echo '### Summary of upcoming actions:'
echo '### - Create a cloudigrade user.'
echo '### - Register a Cloud Account with a custom display name.'
echo "### - Then change that Cloud Account's display name various ways."
echo '### - Delete that account so we can register it again differently.'
echo '### - Register a Cloud Account *without* a custom display name.'
echo "### - Then change that Cloud Account's display name."
echo '### - Create another cloudigrade user.'
echo "### - Try to change the first user's Cloud Account name as the new user."

sleep 5

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

USERNAME="customer@example.com"
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

pe "oc rsh -c postgresql \
    \$(oc get pods -o jsonpath=\"{.items[*].metadata.name}\" -l name=postgresql) \\
    scl enable rh-postgresql96 -- psql -c \\
    \"update auth_user set is_superuser=false where username='$USERNAME'\" \\
    2>&1 >/dev/null"

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
sleep 1
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Register named account.'
echo "### Register the customer's AWS account *with* a custom display name."

sleep 1

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="the o.g. name"'

sleep 1
echo
echo '###  Verify that the name is included when retrieving the account'
pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 1
echo
echo '###  Verify that the name is included when listing all accounts'
pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that you can change the name via PATCH update'
pe 'http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    name="another name PATCHed in"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that PATCH can take a JSON object'
pe 'echo "{\"name\": \"some very PATCHy json\", \"resourcetype\": \"AwsAccount\"}" | \
    http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that you can change the name via PUT replacement'
pe 'http put http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="this name was PUT in its place"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that PUT can take a JSON object'
pe 'echo "{\"name\": \"did you PUT that json here?\", \"resourcetype\": \"AwsAccount\", \"account_arn\": \"${CUSTOMER_ARN}\"}" | \
    http put http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that the name must be a string'
pe 'echo "{\"name\": false, \"resourcetype\": \"AwsAccount\"}" | \
    http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Verify that you *cannot* change the ARN via PATCH update'
pe 'http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="MOMS SPAGHETTI"'

sleep 5
clear

echo '### Verify that you *cannot* change the ARN via PUT replacement'
pe 'http put http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="YOU CANT DO THAT ON TELEVISION" \
    name="this name was PUT in its place"'

sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Register no-name account.'
echo '### First, clear out the previously registered account...'
echo "### Then register the customer's AWS account *without* a custom display name."

sleep 1

pe 'oc rsh -c postgresql \
    $(oc get pods -o jsonpath="{.items[*].metadata.name}" -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c \
    "truncate account_awsinstanceevent, account_instanceevent, account_awsmachineimagecopy, account_awsmachineimage, account_machineimage_tags, account_machineimage, account_awsinstance, account_instance, account_awsaccount, account_account;" \
    2>&1 >/dev/null'


pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/2/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

echo '### Change the name via PATCH update'
pe 'http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/2/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    name="whoops better PATCH that name back"'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/account/2/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}"'

sleep 5
clear

###############

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Others cannot change...'
echo '### Create another user for cloudigrade.'
echo "### Verify the new user cannot change the first user's account."

sleep 5

OTHER_USER="maybe-malicious-customer@example.com"
p "make oc-user"
expect -c "spawn make oc-user
        expect \"?name:\"
        send \"$OTHER_USER\r\"
        expect \"?ddress:\"
        send \"\r\"
        expect \"?ssword:\"
        send \"$OTHER_USER\r\"
        expect \"?ssword \(again\):\"
        send \"$OTHER_USER\r\"
        expect eof" 2>&1 | grep -v "spawn"
pe "oc rsh -c postgresql \
    \$(oc get pods -o jsonpath=\"{.items[*].metadata.name}\" -l name=postgresql) \\
    scl enable rh-postgresql96 -- psql -c \\
    \"update auth_user set is_superuser=false where username='$OTHER_USER'\" \\
    2>&1 >/dev/null"

rm -rf /tmp/token
p 'make oc-user-authenticate'
expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$OTHER_USER\r\"
        expect eof"  2>&1 | grep -v 'spawn' | tee >(grep 'Generated token' > /tmp/token)
OTHER_CLOUDIGRADE_TOKEN=$(cat /tmp/token | cut -d ' ' -f 3)
p "OTHER_CLOUDIGRADE_TOKEN=$OTHER_CLOUDIGRADE_TOKEN"
sleep 1

echo "### Fail to change the name of another user's account via PATCH"
pe 'http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/2/ \
    Authorization:"Token ${OTHER_CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    name="this PATCH no es bueno"'

echo "### Fail to change the name of another user's account via PUT"
pe 'http put http://cloudigrade.127.0.0.1.nip.io/api/v1/account/2/ \
    Authorization:"Token ${OTHER_CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="this PATCH no es bueno"'


sleep 1
echo
echo "🎉  🎉  🎉  🎉"
echo
sleep 5
clear
