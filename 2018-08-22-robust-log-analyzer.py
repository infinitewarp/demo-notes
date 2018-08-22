from account.tests import helper as account_helper
from util.tests import helper as util_helper


users = {
    'normie': util_helper.generate_test_user(),
}
for user in users.values():
    print(
        f'user:'
        f'id={user.id};'
        f'username={user.username};'
    )

accounts = {
    'normie_account': account_helper.generate_aws_account(
        user=users['normie'],
        name='greatest account ever 🎉',
        aws_account_id=273470430754,
        arn='arn:aws:iam::273470430754:role/role-for-cloudigrade'),
}
for account in accounts.values():
    account.created_at = util_helper.utc_dt(2018, 1, 1, 0, 0, 0)
    account.save()
    print(
        f'account:'
        f'id={account.id};'
        f'user_id={account.user_id};'
        f'name={account.name};'
    )
