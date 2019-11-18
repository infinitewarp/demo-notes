#!/usr/bin/env bash
#
# asciinema rec -c ~/projects/personal/demo-notes/2018-05-18-exception-handling.sh

clear

toilet -f standard -d /usr/local/share/figlet/fonts/ -t 'Demo'
echo '### https://github.com/cloudigrade/cloudigrade/issues/286'
echo '### https://github.com/cloudigrade/cloudigrade/pull/300'


source "$(brew --prefix)/bin/virtualenvwrapper.sh"
source /Users/brasmith/projects/personal/demo-magic/demo-magic.sh -d -w1

p 'cloudigrade'
source ~/bin/cloudigrade.sh

pe "oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) scl enable rh-postgresql96 -- psql -c 'truncate auth_user cascade;'"
# pe "oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql) scl enable rh-postgresql96 -- psql -c 'truncate account_account cascade;'"

USERNAME=customer1
# p 'make oc-user'
# expect -c "spawn make oc-user
#         expect \"?name:\"
#         send \"$USERNAME\r\"
#         expect \"?ddress:\"
#         send \"\r\"
#         expect \"?ssword:\"
#         send \"$USERNAME\r\"
#         expect \"?ssword \(again\):\"
#         send \"$USERNAME\r\"
#         expect eof" 2>&1 | grep -v 'spawn'
# sleep 1

# p 'make oc-user-authenticate'
# expect -c "spawn make oc-user-authenticate
#         expect \"?name:\"
#         send \"$USERNAME\r\"
#         expect eof"  2>&1 | grep -v 'spawn' | tee >(grep 'Generated token' > /tmp/token)
# CLOUDIGRADE_TOKEN=$(cat /tmp/token | )
# p 'CLOUDIGRADE_TOKEN='$CLOUDIGRADE_TOKEN

CLOUDIGRADE_TOKEN=$(expect -c "spawn make oc-user-authenticate
        expect \"?name:\"
        send \"$USERNAME\r\"
        expect eof"  2>&1 | grep 'Generated token' | sed -e 's/.*token \(.*\)* for.*/\1/')

p 'CLOUDIGRADE_TOKEN='$CLOUDIGRADE_TOKEN
pe 'clear'

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Role has Bad Policy'
echo '### Try account creation using a ARN for a Role that has a known-bad Policy.'
echo '### This can happen if the customer did not set up the Policy correctly.'
echo '### Expect to receive a 400 error with details explaining the problem.'
sleep 5
ARN_WITH_BAD_POLICY="arn:aws:iam::518028203513:role/grant_failure_to_372779871274"
pe 'ARN_WITH_BAD_POLICY='$ARN_WITH_BAD_POLICY
pe 'http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="$ARN_WITH_BAD_POLICY"'
p
sleep 5
clear

################

toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'Access Denied to Role'
echo '### Try account creation using an ARN for a Role that we are not allowed to access.'
echo '### This can happen if the customer did not set up the ARN with our AWS account ID.'
echo '### Expect to receive a 400 error with details explaining the problem.'
sleep 5
ARN_WITH_NO_ACCESS="arn:aws:iam::518028203513:role/you_get_no_access_to_this_arn"
pe 'ARN_WITH_NO_ACCESS='$ARN_WITH_NO_ACCESS
pe 'http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    Authorization:"Token ${CLOUDIGRADE_TOKEN}" \
    resourcetype="AwsAccount" \
    account_arn="$ARN_WITH_NO_ACCESS"'
p
sleep 5
clear
