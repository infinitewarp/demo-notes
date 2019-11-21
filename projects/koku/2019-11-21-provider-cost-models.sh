#!/usr/bin/env bash
#
# asciinema rec -i2 -c THIS_FILE

# <<PREREQ
# see 00-koku-masu...sh
# docker-compose up -d redis db koku-rabbit
# time docker-compose up -d --build koku-server masu-server koku-worker
# PREREQ

# delete all the existing providers and cost models

http :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" \
    | jq ".data | .[].uuid"

clear

# SETUP
# source $(which virtualenvwrapper.sh)
# source ~/projects/personal/demo-magic/demo-magic.sh -d -w1
source ~/projects/personal/demo-magic/demo-magic.sh -w1
# source ~/projects/personal/demo-magic/demo-magic.sh -d -n

function deleteAll() {
    IDENTITY=$(echo '{"identity":{
        "account_number":"10001",
        "user":{"username":"test_customer","email":"koku-dev@example.com"}
    }}' | base64)

    http :8000/api/cost-management/v1/costmodels/ \
        HTTP_X_RH_IDENTITY:"${IDENTITY}" | jq ".data | .[].uuid" \
        | cut -d '"' -f 2 | xargs -I UUID \
        http delete :8000/api/cost-management/v1/costmodels/UUID/ \
        HTTP_X_RH_IDENTITY:"${IDENTITY}" 2>&1 > /dev/null

    http :8000/api/cost-management/v1/providers/ \
        HTTP_X_RH_IDENTITY:"${IDENTITY}" | jq ".data | .[].uuid" \
        | cut -d '"' -f 2 | xargs -I UUID \
        http delete :8000/api/cost-management/v1/providers/UUID/ \
        HTTP_X_RH_IDENTITY:"${IDENTITY}" 2>&1 > /dev/null
}

function screenBreak() {
    p
    clear
}

function dunzo() {
    sleep 1
    clear
    echo
    # chafa --symbols solid+space -s 75x35 ~/Desktop/misc/koku-logo.png
    chafa --symbols solid+space -s 125 ~/Desktop/misc/koku-cheers.png
    echo
    sleep 5
    clear
    exit
}

function ecko() {
    echo "### $1"
}


toilet -f standard -d /usr/local/share/figlet/fonts/ -t \
    'provider cost models'
echo
ecko 'https://github.com/project-koku/koku/issues/1051'
ecko 'https://github.com/project-koku/koku/pull/1418'
ecko
ecko 'Update the provider API get and list responses to include'
ecko 'the names and UUIDs of any assigned cost models.'

deleteAll
screenBreak

ecko
ecko 'Start by verifying no providers or cost models exist for my identity.'
ecko
echo

IDENTITY=$(echo '{"identity":{
    "account_number":"10001",
    "user":{"username":"test_customer","email":"koku-dev@example.com"}
}}' | base64)

pe 'echo "${IDENTITY}" | base64 -D | jq'

pe 'http :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"'

pe 'http :8000/api/cost-management/v1/costmodels/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"'

screenBreak

ecko
ecko 'Create a provider, and retain its new UUID.'
ecko
echo

# sleep 1

INPUT='{
    "name": "very 👋 ｂｉｇｌｙ 𝔸.𝕎.𝕊. 👌 provider",
    "type": "AWS-local",
    "authentication": {
        "provider_resource_name": "arn:aws:iam::123456789012:role/taters"
    },
    "billing_source": {
        "bucket": "/tmp/local_bucket"
    }
}'

pe 'http :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" <<< '"'$INPUT'"
pe 'PROVIDER_UUID=$( \
    http :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" \
    | jq ".data | .[].uuid" | head -n1 | cut -d"\"" -f 2 \
)'
PROVIDER_UUID=$( \
    http :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" \
    | jq ".data | .[].uuid" | head -n1 | cut -d '"' -f 2 \
)
pe 'echo $PROVIDER_UUID'

screenBreak

ecko
ecko "Create a cost model assigned to the new provider's UUID."
ecko
echo

INPUT=$'{
    "name": "👐 𝘵𝘳𝘦𝘮𝘦𝘯𝘥𝘰𝘶𝘴 cost model 👏",
    "source_type": "AWS",
    "description": "I\\\'m very highly educated. I know cost models. I have the best cost models.",
    "rates": [],
    "markup": {
        "value": "9000.0000000001", "unit": "percent"
    },
    "provider_uuids": ["\'$PROVIDER_UUID\'"]
}'

pe 'http :8000/api/cost-management/v1/costmodels/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" <<< $'"'$INPUT'"

screenBreak

ecko
ecko "List and get the new provider, and look for the assigned cost model info."
ecko
echo

pe 'http --pretty=all :8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" | less -RS'

pe 'http --pretty=all :8000/api/cost-management/v1/providers/"${PROVIDER_UUID}"/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" | less -RS'


dunzo
deleteAll
sleep 2
