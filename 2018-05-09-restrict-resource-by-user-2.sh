cloudigrade

make oc-login-developer

oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql)\
    scl enable rh-postgresql96 -- psql -c 'truncate account_account cascade;'

SUPER_AUTH="Authorization:Token db9dfbb9f875bb4030d02e7b95fe05a268dfdb1e"
CUSTOMER1_AUTH="Authorization:Token 601a839f280d875809cd49bdd7998868d0af0e11"
CUSTOMER1_ARN="arn:aws:iam::518028203513:role/testing-customer-1"

http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${CUSTOMER1_AUTH}" account_arn="${CUSTOMER1_ARN}" resourcetype=AwsAccount

http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${CUSTOMER1_AUTH}"

http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${SUPER_AUTH}"
