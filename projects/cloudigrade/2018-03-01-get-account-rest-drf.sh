workon cloudigrade
make reinitdb

./cloudigrade/manage.py shell --settings=config.settings.local

from account.models import Account
for a in range(50):
    a += 500000000000
    arn = f'arn:aws:iam::{a}:role/grant_cloudi_to_372779871274'
    print(Account.objects.create(account_id=a, account_arn=arn))

#------
screen

workon cloudigrade
./cloudigrade/manage.py runserver --settings=config.settings.local

# ^a n

http 127.0.0.1:8000/api/v1/account/1/
http 127.0.0.1:8000/api/v1/account/2/
http 127.0.0.1:8000/api/v1/account/99999/
http 127.0.0.1:8000/api/v1/account/foo/

# ^d
# ^a n

http 127.0.0.1:8000/api/v1/account/
http 127.0.0.1:8000/api/v1/account/?offset=10
http 127.0.0.1:8000/api/v1/account/?offset=48
http 127.0.0.1:8000/api/v1/account/?offset=9999
