##########
# prereqs

code && cd cloudigrade/cloudigrade && workon cloudigrade

export DJANGO_SETTINGS_MODULE=config.settings.local
export PYTHONPATH=$(pwd)

rm -f db.sqlite3 && ./manage.py migrate

##########
# test coverage

tox

##########
# test permission checking

ARN_BAD_POLICY="arn:aws:iam::518028203513:role/grant_failure_to_372779871274"
AWS_PROFILE=redhat ./cloudigrade/manage.py add_account $ARN_BAD_POLICY


##########
# test assuming role, checking currently running, and saving to DB

# check the customer's account for running instances:
# https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#Instances:sort=instanceId

ARN_WITH_RUNNING="arn:aws:iam::518028203513:role/grant_cloudi_to_372779871274"
AWS_PROFILE=redhat ./cloudigrade/manage.py add_account $ARN_WITH_RUNNING

# check that things were saved correctly
sqlite3 db.sqlite3
.headers on
.mode column
select * from account_account;
select * from account_instance;
select * from account_instanceevent;

