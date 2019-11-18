# demo

# setup before recording
# see 00-koku-masu...sh

# verify the buckets are empty
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith/data_archive
AWS_PROFILE=koku aws s3 rm --recursive s3://koku-data-archive-brasmith/data_archive
AWS_PROFILE=koku-customer aws s3 ls --recursive s3://koku-customer-junk-bucket/data_archive
AWS_PROFILE=koku-customer aws s3 rm --recursive s3://koku-customer-junk-bucket/data_archive

# recreate nise data, start the services, etc.
docker-compose down
make docker-reinitdb

docker-compose up -d redis db koku-rabbit koku-server masu-server koku-worker
# but if python dependencies need rebuilding
docker-compose up -d redis db koku-rabbit
docker-compose up -d --build koku-server masu-server koku-worker
# note: no koku-beat because we don't want jobs running prematurely
docker-compose logs -f

# check that the expected tables are empty
PGPASSWORD=postgres psql -p 15432 -h localhost -U postgres -c \
    "select * from reporting_common_costusagereportstatus"

# set up identity for creating providers
IDENTITY=$(echo '{"identity":{"account_number":"10001",
"user":{"username":"test_customer","email":"koku-dev@example.com"}}}' | base64)
echo ${IDENTITY} | base64 -D | jq

# create the AWS provider
http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" <<< '{
    "name": "my great AWS local provider",
    "type": "AWS-local",
    "authentication": {
        "provider_resource_name": "arn:aws:iam::589173575009:role/LocalOne"
    },
    "billing_source": {
        "bucket": "/tmp/local_bucket"
    }
}'

# create the OCP provider
http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" <<< '{
    "name": "my great OCP provider",
    "type": "OCP",
    "authentication": {
        "provider_resource_name": "my-ocp-cluster-1"
    },
    "billing_source": {
        "bucket": ""
    }
}'

# create the Azure provider
http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" <<< '{
    "name": "my great Azure provider",
    "type": "AZURE-local",
    "authentication": {
        "credentials": {
            "subscription_id": "329cc628-23e6-45f1-9993-736ea5c79216",
            "tenant_id": "91910d45-f47a-4dc2-a667-39dd7ab0fd65",
            "client_id": "85dbba8e-5e3c-4f42-97c3-e58a5492dbca",
            "client_secret": "potatoes"
        }
    }, "billing_source": {
        "data_source": {
            "resource_group": {
                "export_name": "cur",
                "directory": "my-azure-prefix"
            },
            "storage_account": {
                "local_dir": "/tmp/local_container",
                "container": "my_container"
            }
        }
    }
}'

# trigger the processing of local nise files, and wait...
# IMPORTANT REMINDER: check that OCP_PVC dir is not set for koku-worker.
http localhost:5000/api/cost-management/v1/download/

# check that the database is loaded
PGPASSWORD=postgres psql -p 15432 -h localhost -U postgres -c \
    "select * from reporting_common_costusagereportstatus"

clear

# start recording the demo!
asciinema rec -i 2.0 -t '1315-provider-split-archive'
koku
# start by showing that S3 is empty
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith
AWS_PROFILE=koku-customer aws s3 ls --recursive s3://koku-customer-junk-bucket

# mention that this is from an empty DB with recent nise data for AWS, Azure, and OCP.
tree ~/koku-data/ | less

# check the database to show that data is loaded for all three providers
PGPASSWORD=postgres psql -p 15432 -h localhost -U postgres -c \
    "select * from reporting_common_costusagereportstatus"

# trigger the "nightly" job for exporting our own archives
http post localhost:5000/api/cost-management/v1/upload_normalized_data/

# quickly watch the logs
docker-compose logs -f koku-worker

# observe that the files have been archived in Koku's bucket
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith | less -S

# observe still no files in the customer bucket
AWS_PROFILE=koku-customer aws s3 ls --recursive s3://koku-customer-junk-bucket/data_archive

# create an export request as the customer
IDENTITY=$(echo '{"identity":{"account_number":"10001",
"user":{"username":"test_customer","email":"koku-dev@example.com"}}}' | base64)
echo ${IDENTITY} | base64 -D | jq

http localhost:8000/api/cost-management/v1/dataexportrequests/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" \
    start_date='2019-10-06' \
    end_date='2019-10-14' \
    bucket_name='koku-customer-junk-bucket'

# quickly watch the logs
docker-compose logs -f koku-worker

# check that the expected files were copied
AWS_PROFILE=koku-customer aws s3 ls --recursive s3://koku-customer-junk-bucket/data_archive | less -S

# check the list of requests
http localhost:8000/api/cost-management/v1/dataexportrequests/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"

# dunzo!
koku-demo-done
