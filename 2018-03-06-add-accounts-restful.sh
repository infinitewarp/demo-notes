# REST + Auth: https://asciinema.org/a/9jiuCQnu7KG2ynvqh5qqqGA2h
# log analyzer: https://asciinema.org/a/Tilc8MPazWPku5tjBGAwhzKBN

##########
# prereqs

code && cd cloudigrade/cloudigrade && workon cloudigrade
# export AWS_PROFILE=redhat
export AWS_ACCESS_KEY_ID=FOO
export AWS_SECRET_ACCESS_KEY=BAR
export AWS_DEFAULT_REGION=us-east-2

##########
# test coverage

make stop-compose
make clean
make reinitdb
make start-compose


##########
# test creating account via HTTP

ARN_BAD_POLICY="arn:aws:iam::518028203513:role/grant_failure_to_372779871274"
http post localhost:8000/api/v1/account/ account_arn="${ARN_BAD_POLICY}"


ARN_WITH_RUNNING="arn:aws:iam::518028203513:role/grant_cloudi_to_372779871274"
http post localhost:8000/api/v1/account/ account_arn="${ARN_WITH_RUNNING}"


# check that things were saved correctly
# sqlite3 db.sqlite3
# .headers on
# .mode column
# select * from account_account;
# select * from account_instance;
# select * from account_instanceevent;
psql -h localhost -p 15432 -U postgres
\x
select * from account_account;
select * from account_instance;
select * from account_instanceevent;

# test permission checking


AWS_PROFILE=redhat ./cloudigrade/manage.py add_account $ARN_BAD_POLICY


##########
# test assuming role, checking currently running, and saving to DB

# check the customer's account for running instances:
# https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#Instances:sort=instanceId

ARN_WITH_RUNNING="arn:aws:iam::518028203513:role/grant_cloudi_to_372779871274"
AWS_PROFILE=redhat ./cloudigrade/manage.py add_account $ARN_WITH_RUNNING

# check that things were saved correctly
psql -h localhost -p 15432 -U postgres
\x
select * from account_account;
select * from account_instance;
select * from account_instanceevent;
