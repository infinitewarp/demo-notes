# Manual verification notes.
# Changing a sources-api authentication password should result in 
# cloudigrade updating the AwsCloudAccount ARN and performing various
# logging and verification steps.
# 
# https://gitlab.com/cloudigrade/cloudigrade/-/issues/640

SOURCEID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources \
    name=test-source-15 source_type_id=2 | jq .id | cut -d'"' -f2)
echo $SOURCEID

ENDPOINTID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints \
    role=aws default=true source_id=$SOURCEID | jq .id | cut -d\" -f2)
echo $ENDPOINTID

APPLICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications \
    application_type_id=5 source_id=$SOURCEID | jq .id | cut -d\" -f2)
echo $APPLICATIONID

ARN1="arn:aws:iam::273470430754:role/cloudigrade-role-qa-stage-372779871274"
ARN2="arn:aws:iam::273470430754:role/role-for-cloudigrade-372779871274"
ARN_BAD="arn:aws:iam::273470430754:role/role-for-cloudigrade-977153484089"
ARN3="arn:aws:iam::114204391493:role/cloudigrade-qa-role"

AUTHENTICATIONID=$(http --verify=no --auth $AUTH --body post \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications \
    resource_type=Endpoint resource_id=$ENDPOINTID \
    password="${ARN1}" \
    authtype=cloud-meter-arn | jq .id | cut -d\" -f2)

echo $AUTHENTICATIONID

http --verify=no --auth $AUTH patch \
  https://qa.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID \
  password="${ARN2}"

http --verify=no --auth $AUTH patch \
  https://qa.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID \
  password="${ARN_BAD}"


#############

http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/authentications/$AUTHENTICATIONID
http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/applications/$APPLICATIONID
http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/endpoints/$ENDPOINTID
http --verify=no --auth $AUTH --headers delete \
    https://qa.cloud.redhat.com/api/sources/v1.0/sources/$SOURCEID

