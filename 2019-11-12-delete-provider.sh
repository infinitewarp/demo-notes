# demo

# setup before recording
# see 00-koku-masu...sh

# verify the main bucket is empty
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith/data_archive
AWS_PROFILE=koku aws s3 rm --recursive s3://koku-data-archive-brasmith/data_archive

# recreate nise data, start the services, etc.
docker-compose down
make docker-reinitdb

docker-compose up -d redis db koku-rabbit koku-server masu-server koku-worker
# but if python dependencies need rebuilding
docker-compose up -d redis db koku-rabbit
time docker-compose up -d --build koku-server masu-server koku-worker
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


# trigger the "nightly" job for exporting our own archives
http post localhost:5000/api/cost-management/v1/upload_normalized_data/

# quickly watch the logs
docker-compose logs -f koku-worker

# observe that the files have been archived in Koku's bucket
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith | less -S

clear

# START RECORDING
asciinema rec -i2

# set up identity for creating providers
IDENTITY=$(echo '{"identity":{"account_number":"10001",
"user":{"username":"test_customer","email":"koku-dev@example.com"}}}' | base64)
echo ${IDENTITY} | base64 -D | jq

# list current providers
http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" | \
    jq .data | jq '.[] | [.name, .uuid]'

PROVIDER_AWS=b1e1758b-cfa4-4313-b88b-803d22cf3967
PROVIDER_AZURE=6de0610a-b79f-4229-b74a-dcd15ef7e463
PROVIDER_OCP=db5ca30b-aee2-4461-9e9b-2c6d5d55503a

# show the current archived files
AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith | less -S
# search for the three UUIDs

##################################
# DELETE AWS PROVIDER
http delete localhost:8000/api/cost-management/v1/providers/${PROVIDER_AWS}/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"

docker-compose logs -f koku-worker

http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" | \
    jq .data | jq '.[] | [.name, .uuid]'

AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith | less -S
# SEARCH FOR b1e1758b-cfa4-4313-b88b-803d22cf3967
# SEARCH FOR aws

##################################
# DELETE OCP PROVIDER
http delete localhost:8000/api/cost-management/v1/providers/${PROVIDER_OCP}/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"

http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}" | \
    jq .data | jq '.[] | [.name, .uuid]'

AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith | less -S
# SEARCH FOR db5ca30b-aee2-4461-9e9b-2c6d5d55503a
# SEARCH FOR ocp

##################################
# DELETE AZURE PROVIDER
http delete localhost:8000/api/cost-management/v1/providers/${PROVIDER_AZURE}/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"

http localhost:8000/api/cost-management/v1/providers/ \
    HTTP_X_RH_IDENTITY:"${IDENTITY}"

AWS_PROFILE=koku aws s3 ls --recursive s3://koku-data-archive-brasmith


# dunzo!
koku-demo-done
