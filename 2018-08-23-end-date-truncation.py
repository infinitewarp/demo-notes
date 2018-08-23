import faker

from account.tests import helper as account_helper
from util.tests import helper as util_helper


_faker = faker.Faker()

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
        name='my favorite account'),
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

images = {
    'normie_account': {
        'plain': account_helper.generate_aws_image(
            # accounts['normie_account'],
            is_encrypted=False,
            ec2_ami_id='ami-plain',
            name='my-named-plain-image'
        ),
        'rhel7': account_helper.generate_aws_image(
            # accounts['normie_account'],
            is_encrypted=False,
            rhel_detected=True,
            ec2_ami_id='ami-rhel7',
            name='my-named-rhel7-image'
        ),
        'ocp': account_helper.generate_aws_image(
            # accounts['normie_account'],
            is_encrypted=False,
            openshift_detected=True,
            ec2_ami_id='ami-ocp',
        ),
    }
}
for account, account_images in images.items():
    for image in account_images.values():
        print(
            f'image:'
            f'id={image.id};'
            f'owner_aws_account_id={image.owner_aws_account_id};'
            f'ec2_ami_id={image.ec2_ami_id};'
            f'name={image.name};'
        )

instances = {
    'normie_account': [
        account_helper.generate_aws_instance(accounts['normie_account']),
        account_helper.generate_aws_instance(accounts['normie_account']),
        account_helper.generate_aws_instance(accounts['normie_account']),
        account_helper.generate_aws_instance(accounts['normie_account']),
    ],
}
for account, account_instances in instances.items():
    for instance in account_instances:
        print(
            f'instance:'
            f'id={instance.id};'
            f'account_id={instance.account_id};'
        )


times = [(
    util_helper.utc_dt(2018, 1, 12, 5, 0, 0),
    util_helper.utc_dt(2018, 1, 12, 6, 0, 0)
),(
    util_helper.utc_dt(2018, 8, 23, 0, 0, 0),
    util_helper.utc_dt(2019, 8, 23, 0, 0, 0),
),]

events = []
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_account'][0], times,
    ec2_ami_id=images['normie_account']['plain'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_account'][1], times,
    ec2_ami_id=images['normie_account']['rhel7'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_account'][2], times,
    ec2_ami_id=images['normie_account']['rhel7'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_account'][3], times,
    ec2_ami_id=images['normie_account']['ocp'].ec2_ami_id,
))


for event in events:
    print(
        f'event.instance.account.id={event.instance.account.id};'
        f'event.occurred_at={event.occurred_at};'
        f'event.event_type={event.event_type};'
        f'event.machineimage.ec2_ami_id={event.machineimage.ec2_ami_id};'
    )
