#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

# <<PREREQ
# cloudigrade
# cd ../shiftigrade/
# make oc-clean
# make oc-up-db
# make oc-forward-ports
# PREREQ

clear

# SETUP
# source $(which virtualenvwrapper.sh)
# source ~/projects/personal/demo-magic/demo-magic.sh -d -w1
source ~/projects/personal/demo-magic/demo-magic.sh -w1

function screenBreak() {
    # p
    sleep 2
    clear
}

function dunzo() {
    sleep 1
    clear
    echo
    chafa --symbols solid+space -s 140x35 --stretch /Users/brasmith/Desktop/misc/Cloudigrade\ Mascot/cheers1.png
    echo
    sleep 5
    clear
}


toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'concurrent API'
echo '### https://gitlab.com/cloudigrade/cloudigrade/issues/542'
echo '### https://gitlab.com/cloudigrade/cloudigrade/merge_requests/638'
echo
echo '### New reporting API that returns a list of days and the maximum'
echo '### seen concurrent count of instances, vcpu, and memory (in GB)'
echo '### by instances owned by the authenticated user on each day.'
echo

echo
echo '###'
echo '### Before querying the API, look at some of the underlying data'
echo "### to set our expectations for the API's summarized results."
echo '###'
echo
pe "oc port-forward \$(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=review-542-concurrent-db | awk '{print \$1}') 5432 &>/dev/null &"
echo
sleep 2

echo '###'
echo '### Observe that user 2 has cloud accounts with overlapping activity in May.'
echo '###'
pe 'psql -h localhost -U postgres -c "select id, username from auth_user where id = 2;"'
pe "psql -h localhost -U postgres -c \"select a.user_id, i.cloud_account_id, r.id as run_id, r.start_time, r.end_time, r.instance_type, r.memory, r.vcpu from api_run r join api_instance i on r.instance_id = i.id join api_cloudaccount a on i.cloud_account_id = a.id join auth_user u on a.user_id = u.id where start_time >= '2019-05-01' and a.user_id = 2 order by start_time asc;\""
sleep 5

# quietly kill that port-forwarding now...
ps a | grep "oc port-forward" | grep -v grep | awk '{print $1}' | xargs kill

screenBreak
#########################

echo
echo '###'
echo '### Port-forward the deployed pod so we can query the HTTP API locally.'
echo '###'
echo
pe "oc port-forward \$(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=c-review-542-concurrent-a | awk '{print \$1}') 8080 &>/dev/null &"
echo
sleep 2

echo '###'
echo '### Get the concurrent data for 2019-05-31 when there should have'
echo '### been 6 instances running concurrently from 3 different clounts.'
echo '###'
echo

pe "http --pretty=all --print=hb localhost:8080/v2/concurrent/ \"X-RH-IDENTITY:\"\$(echo '{\"identity\":{\"user\":{\"email\":\"brasmith+qa@redhat.com\"}}}' | base64) start_date=='2019-05-31' end_date=='2019-06-15' limit==1 | less -R"
echo
sleep 2

echo '###'
echo '### Repeat that request, but limit to one of the clounts.'
echo '###'
echo

pe "http --pretty=all --print=hb localhost:8080/v2/concurrent/ \"X-RH-IDENTITY:\"\$(echo '{\"identity\":{\"user\":{\"email\":\"brasmith+qa@redhat.com\"}}}' | base64) start_date=='2019-05-31' end_date=='2019-06-15' limit==1 cloud_account_id==4 | less -R"
echo
sleep 2

echo '###'
echo '### And for a different one of the clounts...'
echo '###'
echo

pe "http --pretty=all --print=hb localhost:8080/v2/concurrent/ \"X-RH-IDENTITY:\"\$(echo '{\"identity\":{\"user\":{\"email\":\"brasmith+qa@redhat.com\"}}}' | base64) start_date=='2019-05-31' end_date=='2019-06-15' limit==1 cloud_account_id==5 | less -R"
echo
sleep 2

echo '###'
echo '### And for a clount that was not active during that day...'
echo '###'
echo

pe "http --pretty=all --print=hb localhost:8080/v2/concurrent/ \"X-RH-IDENTITY:\"\$(echo '{\"identity\":{\"user\":{\"email\":\"brasmith+qa@redhat.com\"}}}' | base64) start_date=='2019-05-31' end_date=='2019-06-15' limit==1 cloud_account_id==99 | less -R"
echo
sleep 2

echo '###'
echo '### Repeat the original request, but get more than 1 day.'
echo '###'
echo

pe "http --pretty=all --print=hb localhost:8080/v2/concurrent/ \"X-RH-IDENTITY:\"\$(echo '{\"identity\":{\"user\":{\"email\":\"brasmith+qa@redhat.com\"}}}' | base64) start_date=='2019-05-10' end_date=='2019-06-10' | less -R"
echo


# quietly kill that port-forwarding now...
ps a | grep "oc port-forward" | grep -v grep | awk '{print $1}' | xargs kill

dunzo
