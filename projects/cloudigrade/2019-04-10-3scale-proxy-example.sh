#!/usr/bin/env bash
#
# asciinema rec -c THIS_FILE

clear
source ~/projects/personal/demo-magic/demo-magic.sh -d -w1

function screenBreak() {
    # p
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


toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    '3Scale » cloudigrade'
echo '### https://gitlab.com/cloudigrade/scaligrade/merge_requests/2'
echo
echo '### Update URL paths per recent Insights changes.'
echo '### See also:'
echo '### https://docs.google.com/spreadsheets/d/188uz04yPb0Oe4rcq6QxLV1rHBjAJtp5UbUNZlPD2pwQ/edit'
echo '### https://docs.google.com/spreadsheets/d/1occFQZoDQitFti0l276OqeA6MwYwP8Dmx_I97UsZqMQ/edit'

screenBreak
export THREESCALEPASS=redhat
export REALRHPASS=

echo '### Example API call for our dev review environments.'
echo '### Setting "X-4Scale-Env:ci" directs scaligrade to use our review environments.'
echo '### Remember that 3scale "qa" uses fake credentials.'
echo
pe 'http --print=hb --pretty=all --verify=no --auth brasmith@redhat.com:${THREESCALEPASS} \
    https://qa.cloud.paas.upshift.redhat.com/api/cloudigrade/api/v2/sysconfig/ \
    X-4Scale-Env:ci \
    X-4Scale-Branch:533-count-inspection-attempts \
    X-4Scale-Debug:yes 2>&1 | less -R'
screenBreak

echo '### Example API call for our test environment.'
echo '### Setting "X-4Scale-Env:ci" directs scaligrade to use our **test** environment.'
echo '### Remember that 3scale "stage" uses fake credentials.'
echo
pe 'http --print=hb --pretty=all --verify=no --auth brasmith@redhat.com:${THREESCALEPASS} \
    https://stage.cloud.paas.upshift.redhat.com/api/cloudigrade/api/v2/sysconfig/ \
    X-4Scale-Env:qa \
    X-4Scale-Debug:yes 2>&1 | less -R'
screenBreak

echo '### Example API call for our stage environment.'
echo '### Setting "X-4Scale-Env:stage" directs scaligrade to use our **stage** environment.'
echo '### Remember that 3scale "stage" uses fake credentials.'
echo
pe 'http --print=hb --pretty=all --verify=no --auth brasmith@redhat.com:${THREESCALEPASS} \
    https://stage.cloud.paas.upshift.redhat.com/api/cloudigrade/api/v2/sysconfig/ \
    X-4Scale-Env:stage \
    X-4Scale-Debug:yes 2>&1 | less -R'
screenBreak

echo '### Example API call for our stage environment.'
echo '### 3scale "prod" with no extra env variables maps to our prod environment.'
echo '### Remember that 3scale "prod" uses real credentials.'
echo
pe 'http --print=hb --pretty=all --verify=no --auth bradsmith_rh:${REALRHPASS} \
    https://cloud.redhat.com/api/cloudigrade/api/v2/sysconfig/ \
    X-4Scale-Debug:yes 2>&1 | less -R'
dunzo
