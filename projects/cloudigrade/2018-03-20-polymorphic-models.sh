demo notes

asciinema rec -t "https://github.com/cloudigrade/cloudigrade/issues/105 demo"

workon cloudigrade
make stop-compose clean reinitdb start-compose user user-authenticate

AUTH=Authorization:"Token "
AID="518028203513" ARN="arn:aws:iam::${AID}:role/grant_cloudi_to_372779871274"

clear

# Create an AWS account (this takes a few seconds)
http post localhost:8000/api/v1/account/ "${AUTH}" \
    account_arn=${ARN} \
    resourcetype="AwsAccount"

clear

# List all accounts
http localhost:8000/api/v1/account/ "${AUTH}"

clear

# Retrieve a specific account
http localhost:8000/api/v1/account/1/ "${AUTH}"

clear

# Retrieve a usage report for a valid cloud provider and account
http localhost:8000/api/v1/report/ "${AUTH}" \
    cloud_provider=="aws" \
    cloud_account_id=="518028203513" \
    start=="2018-03-01T00:00:00" \
    end=="2018-04-01T00:00:00"

clear

# Retrieve a usage report for an invalid cloud provider (400 error)
http localhost:8000/api/v1/report/ "${AUTH}" \
    cloud_provider=="daystom-institute" \
    cloud_account_id=="518028203513" \
    start=="2018-03-01T00:00:00" \
    end=="2018-04-01T00:00:00"

clear

# Retrieve a usage report for a missing account (404 error)
http localhost:8000/api/v1/report/ "${AUTH}" \
    cloud_provider=="aws" \
    cloud_account_id=="1701" \
    start=="2018-03-01T00:00:00" \
    end=="2018-04-01T00:00:00"

clear

# Retrieve a usage report for an invalid account ID format (404 error)
http localhost:8000/api/v1/report/ "${AUTH}" \
    cloud_provider=="aws" \
    cloud_account_id=="NX-74205" \
    start=="2018-03-01T00:00:00" \
    end=="2018-04-01T00:00:00"


clear

psql -U postgres -h localhost -p 15432 -c '\d account_account'
psql -U postgres -h localhost -p 15432 -c '\d account_awsaccount'
psql -U postgres -h localhost -p 15432 -c '\d account_instance'
psql -U postgres -h localhost -p 15432 -c '\d account_awsinstance'
psql -U postgres -h localhost -p 15432 -c '\d account_instanceevent'
psql -U postgres -h localhost -p 15432 -c '\d account_awsinstanceevent'
