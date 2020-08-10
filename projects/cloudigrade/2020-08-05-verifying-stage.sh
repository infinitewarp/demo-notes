# Not an executable shell script.
# This is just a bunch of manual commands.
# For poking and verifying the new stage and prod environments.

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

STAGE_AWS_ACCOUNT_ID="PLACEHOLDER"
STAGE_ARN="arn:aws:iam::PLACEHOLDER:role/cloudigrade-role-prod-PLACEHOLDER"

CUSTOMER_AWS_ACCOUNT_ID="${STAGE_AWS_ACCOUNT_ID}"
ARN="${STAGE_ARN}"

#############################

# Verifying the stage envirionment.

AUTH="insights-qa:redhat"

HTTP_WITH_PROXY="http --auth $AUTH --proxy https:http://squid.corp.redhat.com:3128"

SOURCES_BASE_URL="https://cloud.stage.redhat.com/api/sources/v3.0"
CLOUDIG_BASE_URL="https://cloud.stage.redhat.com/api/cloudigrade/v2"

$HTTP_WITH_PROXY $SOURCES_BASE_URL

$HTTP_WITH_PROXY $SOURCES_BASE_URL/application_types \
    filter[name]==/insights/platform/cloud-meter | jq .data
APPLICATIONTYPEID=3

$HTTP_WITH_PROXY $SOURCES_BASE_URL/source_types \
    filter[name]=="amazon" | jq .data
SOURCETYPEID=1

# create the sources
$HTTP_WITH_PROXY $SOURCES_BASE_URL/sources \
    name=sauce-420 source_type_id=$SOURCETYPEID
SOURCEID=

$HTTP_WITH_PROXY $SOURCES_BASE_URL/endpoints \
    role=aws default=true source_id=$SOURCEID
ENDPOINTID=

$HTTP_WITH_PROXY $SOURCES_BASE_URL/applications \
    application_type_id=$APPLICATIONTYPEID source_id=$SOURCEID
APPLICATIONID=

$HTTP_WITH_PROXY $SOURCES_BASE_URL/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN authtype=cloud-meter-arn
AUTHENTICATIONID=

$HTTP_WITH_PROXY $SOURCES_BASE_URL/application_authentications \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID
APPLICATIONAUTHENTICATIONID=

$HTTP_WITH_PROXY $CLOUDIG_BASE_URL/accounts/
$HTTP_WITH_PROXY $CLOUDIG_BASE_URL/images/
$HTTP_WITH_PROXY $CLOUDIG_BASE_URL/instances/

$HTTP_WITH_PROXY delete $SOURCES_BASE_URL/application_authentications/$APPLICATIONAUTHENTICATIONID
$HTTP_WITH_PROXY delete $SOURCES_BASE_URL/authentications/$AUTHENTICATIONID
$HTTP_WITH_PROXY delete $SOURCES_BASE_URL/applications/$APPLICATIONID
$HTTP_WITH_PROXY delete $SOURCES_BASE_URL/endpoints/$ENDPOINTID
$HTTP_WITH_PROXY delete $SOURCES_BASE_URL/sources/$SOURCEID

$HTTP_WITH_PROXY $CLOUDIG_BASE_URL/images/
$HTTP_WITH_PROXY $CLOUDIG_BASE_URL/accounts/

#############################

# Slight variation of commands for verifying prod.

read AUTH
echo $AUTH

export HTTP_NEW_PROD="http --auth $AUTH"
export COOKIE="Cookie:x-rh-prod-v4=1"

export SOURCES_BASE_URL="https://cloud.redhat.com/api/sources/v3.0"
export CLOUDIG_BASE_URL="https://cloud.redhat.com/api/cloudigrade/v2"


$HTTP_NEW_PROD $SOURCES_BASE_URL

$HTTP_NEW_PROD $SOURCES_BASE_URL/application_types $COOKIE \
    filter[name]==/insights/platform/cloud-meter | jq .data
APPLICATIONTYPEID=

$HTTP_NEW_PROD $SOURCES_BASE_URL/source_types $COOKIE \
    filter[name]=="amazon" | jq .data
SOURCETYPEID=

# create the sources
$HTTP_NEW_PROD $SOURCES_BASE_URL/sources $COOKIE \
    name=cloudmeter-demo-47 source_type_id=$SOURCETYPEID
SOURCEID=

$HTTP_NEW_PROD $SOURCES_BASE_URL/endpoints $COOKIE \
    role=aws default=true source_id=$SOURCEID
ENDPOINTID=

$HTTP_NEW_PROD $SOURCES_BASE_URL/applications $COOKIE \
    application_type_id=$APPLICATIONTYPEID source_id=$SOURCEID
APPLICATIONID=

$HTTP_NEW_PROD $SOURCES_BASE_URL/authentications $COOKIE \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password=$ARN authtype=cloud-meter-arn
AUTHENTICATIONID=

$HTTP_NEW_PROD $SOURCES_BASE_URL/application_authentications $COOKIE \
    application_id=$APPLICATIONID authentication_id=$AUTHENTICATIONID
APPLICATIONAUTHENTICATIONID=

$HTTP_NEW_PROD $CLOUDIG_BASE_URL/accounts/ $COOKIE
$HTTP_NEW_PROD $CLOUDIG_BASE_URL/images/ $COOKIE
$HTTP_NEW_PROD $CLOUDIG_BASE_URL/instances/ $COOKIE

$HTTP_NEW_PROD delete $SOURCES_BASE_URL/application_authentications/$APPLICATIONAUTHENTICATIONID $COOKIE
$HTTP_NEW_PROD delete $SOURCES_BASE_URL/authentications/$AUTHENTICATIONID $COOKIE
$HTTP_NEW_PROD delete $SOURCES_BASE_URL/applications/$APPLICATIONID $COOKIE
$HTTP_NEW_PROD delete $SOURCES_BASE_URL/endpoints/$ENDPOINTID $COOKIE
$HTTP_NEW_PROD delete $SOURCES_BASE_URL/sources/$SOURCEID $COOKIE

$HTTP_NEW_PROD $CLOUDIG_BASE_URL/images/ $COOKIE
$HTTP_NEW_PROD $CLOUDIG_BASE_URL/accounts/ $COOKIE
