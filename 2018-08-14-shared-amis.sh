#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear

<<PREREQ
cloudigrade
cd ../shiftigrade/
make oc-clean
make oc-up-all
make oc-forward-ports
export API_REPO_REF=412-multiuser-images
kontemplate template ocp/local.yaml | oc apply -f -
oc start-build cloudigrade-api
# check the web console
# scale down frontigrade and celery
PREREQ

export CUSTOMER_ACCOUNT="273470430754"
export CUSTOMER_ARN="arn:aws:iam::$CUSTOMER_ACCOUNT:role/role-for-cloudigrade"
export SECONDARY_ACCOUNT="528231032158"
export SECONDARY_ARN="arn:aws:iam::$SECONDARY_ACCOUNT:role/role-for-cloudigrade"
export DJANGO_SETTINGS_MODULE=config.settings.local
source "$(brew --prefix)/bin/virtualenvwrapper.sh"
# source ~/projects/personal/demo-magic/demo-magic.sh -d -n
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

function create_user() {
    USERNAME=$1
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
}

function auth_token() {
    USERNAME=$1
    rm -rf /tmp/token
    p 'make oc-user-authenticate'
    expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | \
        grep -v 'spawn' | \
        tee >(grep 'Generated token' > /tmp/token)
}

function screenBreak() {
    p
    sleep 2
    clear
}

function dunzo() {
    sleep 1
    echo
    echo "🎉 🏆 🥇"
    echo
    sleep 5
    clear

}

function resetDb() {
    # https://youtu.be/jmVyUdHtxbU
    oc rsh -c postgresql \
        $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
        scl enable rh-postgresql96 -- psql -c \
        'drop schema public cascade; create schema public;' \
        2>&1 >/dev/null
    ./cloudigrade/manage.py migrate 2>&1 >/dev/null
}

##########
# here we go...

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Better Image Sharing'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/412'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/463'
echo
echo '### Create a user, register a cloud account (with 4 running instances) for'
echo '### that user, and query the list of images found during registration.'

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null
resetDb

screenBreak
###############

echo '### Authenticate'

USERNAME="main_user@example.com"
create_user $USERNAME
auth_token $USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"
p "CUSTOMER_ARN="$CUSTOMER_ARN

screenBreak
###############

echo '### Register the cloud account for this user.'

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${USER_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}" \
    name="best 🤖💕 account ever"'

screenBreak
###############

echo '### See what images this user can access.'
echo '###'
echo '### Instances running at registration were powered by the following images:'
echo '### - ami-065d0be9883aa064a: shared RHEL AMI (owner 518028203513)'
echo '### - ami-0a8190581f4f3cc40: my CentOS AMI (owner 273470430754)'
echo '### - ami-0db72bb44709e3230: my RHEL AMI (owner 273470430754) with OCP tag'
echo '### - ami-6871a115: marketplace RHEL AMI (owner 309956199498)'


pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/image/ \
    Authorization:"Token ${USER_TOKEN}"'

screenBreak
##############

echo '### Register a second user and query for available images.'
echo '### Because the second user has no activity, it should not see any images.'

USERNAME="other_user@example.com"
create_user $USERNAME
auth_token $USERNAME
USER_TOKEN="$(cat /tmp/token | cut -d ' ' -f 3)"
p "USER_TOKEN=$USER_TOKEN"
p "SECONDARY_ARN="$SECONDARY_ARN

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/image/ \
    Authorization:"Token ${USER_TOKEN}"'

screenBreak
###############

echo '### Register a cloud account for the second user.'

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${USER_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${SECONDARY_ARN}" \
    name="just another account"'

screenBreak
###############

echo '### See what images the second user can access.'
echo '###'
echo '### Instance running at registration was powered by the following image:'
echo '### - ami-065d0be9883aa064a: shared RHEL AMI (owner 518028203513)'

pe 'http get http://cloudigrade.127.0.0.1.nip.io/api/v1/image/ \
    Authorization:"Token ${USER_TOKEN}"'


dunzo
