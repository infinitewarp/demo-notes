workon cloudigrade
make reinitdb

AWS_ACCOUNT_ID=518028203513
ARN_WITH_RUNNING="arn:aws:iam::${AWS_ACCOUNT_ID}:role/grant_cloudi_to_372779871274"
AWS_PROFILE=redhat ./cloudigrade/manage.py add_account $ARN_WITH_RUNNING

# report on a period before the instance started; should have zero usage
AWS_PROFILE=redhat ./cloudigrade/manage.py report_usage 2018-01-02 2018-03-01 $AWS_ACCOUNT_ID

# report on a period during which the instance started; should have usage from start time to the end of the month
AWS_PROFILE=redhat ./cloudigrade/manage.py report_usage 2018-03-01 2018-04-01 $AWS_ACCOUNT_ID

# report on a period after which the instance started; should have usage for the full month
AWS_PROFILE=redhat ./cloudigrade/manage.py report_usage 2018-04-01 2018-05-01 $AWS_ACCOUNT_ID

# verify that number is the seconds in one full month
python -c 'print(30*24*60*60.)'
