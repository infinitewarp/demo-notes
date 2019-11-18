# prereq setup

oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql)\
    scl enable rh-postgresql96 -- psql -c 'truncate auth_user cascade;'

make oc-create-registry-route
make oc-build-and-push-cloudigrade


# ------------

<<EOF

1. create superuser
1. create user1
1. create user2
1. convert user1 and user2 to regular users

1. authenticate as user1
1. register ARN

1. authenticate as user2
1. register different ARN

1. authenticate as superuser
1. list accounts

EOF

#---------

cloudigrade
make oc-login-developer

make oc-user
# super

make oc-user
# customer1

make oc-user
# customer2

# convert those last two users to NOT be superusers
oc rsh -c postgresql $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=postgresql)\
    scl enable rh-postgresql96 -- psql -c \
    "UPDATE auth_user SET is_superuser='f' WHERE username LIKE 'customer%';
    SELECT username, is_superuser FROM auth_user;"

# get different auth tokens for each of these users

make oc-user-authenticate
# super
SUPER_AUTH="Authorization:Token "


make oc-user-authenticate
# customer1

CUSTOMER1_AUTH="Authorization:Token "


make oc-user-authenticate
# customer2

CUSTOMER2_AUTH="Authorization:Token "

clear


# set up different cloud account ARNs for the customers
CUSTOMER1_ARN="arn:aws:iam::518028203513:role/testing-customer-1"
CUSTOMER2_ARN="arn:aws:iam::518028203513:role/testing-customer-2"


# register a cloud account for customer1. this takes a few seconds...
http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${CUSTOMER1_AUTH}" account_arn="${CUSTOMER1_ARN}" resourcetype=AwsAccount

# register a cloud account for customer2. this takes a few seconds...
http post http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ \
    "${CUSTOMER2_AUTH}" account_arn="${CUSTOMER2_ARN}" resourcetype=AwsAccount

# as superuser, get ALL registered cloud accounts
http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ "${SUPER_AUTH}"

# as customer1, only get accounts belonging to customer1
http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ "${CUSTOMER1_AUTH}"

# as customer2, only get accounts belonging to customer2
http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account/ "${CUSTOMER2_AUTH}"

# as customer2, fail to get account belonging to customer1
http get http://cloudigrade-myproject.127.0.0.1.nip.io/api/v1/account// "${CUSTOMER2_AUTH}"


