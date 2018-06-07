#!/usr/bin/env bash
#
# asciinema rec -c this-script.sh

clear

export CUSTOMER_ARN="arn:aws:iam::273470430754:role/role-for-cloudigrade"
export CUSTOMER_ARN_BAD="arn:aws:iam::273470430754:role/duplicate-role-for-cloudigrade"

toilet -f standard -d /usr/local/share/figlet/fonts/ -t 'Issue 334 bugfix'
echo '### https://github.com/cloudigrade/cloudigrade/issues/334'
echo '### https://github.com/cloudigrade/cloudigrade/pull/336'

source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1


################
# here we go...

p 'cloudigrade'
source ~/bin/cloudigrade.sh
make oc-login-developer 2>&1 >/dev/null

# initial user setup
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) \
    scl enable rh-postgresql96 -- psql -c 'truncate auth_user cascade;' 2>&1 >/dev/null

USERNAME=customer1
p "make oc-user oc-user-authenticate"
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
expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | grep -v 'spawn' | tee >(grep 'Generated token' > /tmp/token)
CLOUDIGRADE_TOKEN=$(cat /tmp/token | cut -d ' ' -f 3)
p "CLOUDIGRADE_TOKEN=$CLOUDIGRADE_TOKEN"
p "CUSTOMER_ARN="$CUSTOMER_ARN
p "CUSTOMER_ARN_BAD="$CUSTOMER_ARN_BAD

p
sleep 2
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    '1 AWS account only'
echo '### Register an account with an AWS ARN.'
echo '### Register another account with different ARN but same AWS Account ID.'

sleep 5

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN}"'

pe 'http post http://cloudigrade.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="${CUSTOMER_ARN_BAD}"'

echo
echo "🎉  🎉  🎉  🎉"
echo

sleep 5
clear
