#!/usr/bin/env bash
#
# asciinema rec -c ~/projects/personal/demo-notes/2018-07-05-cloud-account-name-too-long.sh

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
    'Cloud Account Name Demo 2'
echo '### https://github.com/cloudigrade/cloudigrade/issues/267'
echo '### https://github.com/cloudigrade/cloudigrade/pull/400'
echo
echo '### Summary of upcoming actions:'
echo '### - Create a cloudigrade user.'
echo '### - Fail to register a Cloud Account with a too-long name.'
echo '### - Register a Cloud Account with an acceptable display name.'
echo "### - Fail to change that Cloud Account's name to be too long."

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

read -r -d '' LONGNAME <<'EOF'
Come with me
And you'll be
In a world of

Pure imagination
Take a look
And you'll see
Into your imagination
We'll begin
With a spin
Traveling in

The world of my creation
What we'll see
Will defy
Explanation
If you want to view paradise
Simply look around and view it
Anything you want to, do it
EOF

p "LONGNAME=\"$LONGNAME\""
LONGNAME=$(echo $LONGNAME)

p
sleep 5
clear

###############

echo "### Fail to register the customer's aws account with a too-long name."

sleep 1

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="$LONGNAME"'

sleep 5
clear

###############

echo "### Register the customer's aws account with a normal name."
echo "### Fail to update it with a too-long name."

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="namey mcnameface"'

pe 'http patch http://cloudigrade.127.0.0.1.nip.io/api/v1/account/1/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    name="$LONGNAME"'

sleep 1
echo
echo "🎉  🎉  🎉  🎉"
echo
sleep 5
clear
