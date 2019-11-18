import faker

from account.tests import helper as account_helper
from util.tests import helper as util_helper


_faker = faker.Faker()

users = {
    'normie': util_helper.generate_test_user(),
    'super': util_helper.generate_test_user(is_superuser=True)
}
for user in users.values():
    print(f'user:'
          f'id={user.id};'
          f'username={user.username};')

accounts = {
    'normie_greatest': account_helper.generate_aws_account(
        user=users['normie'],
        name='greatest account ever'),
    'normie_another': account_helper.generate_aws_account(
        user=users['normie'],
        name='just another account'),
    'super_spaghetti': account_helper.generate_aws_account(
        user=users['super'],
        name='knees weak arms spaghetti'),
}
for account in accounts.values():
    account.created_at = util_helper.utc_dt(2018, 1, 1, 0, 0, 0)
    account.save()
    print(f'account:'
          f'id={account.id};'
          f'user_id={account.user_id};'
          f'name={account.name};')

images = {
    'normie_greatest': {
        'plain': account_helper.generate_aws_image(
            accounts['normie_greatest'],
            ec2_ami_id='ami-plain'),
        'rhel7': account_helper.generate_aws_image(
            accounts['normie_greatest'], is_rhel=True,
            ec2_ami_id='ami-rhel7'),
        'rhel8': account_helper.generate_aws_image(
            accounts['normie_greatest'], is_rhel=True,
            ec2_ami_id='ami-rhel8'),
    },
    'normie_another': {
        'ocp': account_helper.generate_aws_image(
            accounts['normie_another'], is_openshift=True,
            ec2_ami_id='ami-ocp'),
    },
    'super_spaghetti': {
        'rhel_other': account_helper.generate_aws_image(
            accounts['super_spaghetti'], is_rhel=True,
            ec2_ami_id='ami-rhel_other'),
    }
}
for account, account_images in images.items():
    for image in account_images.values():
        print(f'image:'
              f'id={image.id};'
              f'account_id={image.account_id};'
              f'ec2_ami_id={image.ec2_ami_id};')

instances = {
    'normie_greatest': [
        account_helper.generate_aws_instance(accounts['normie_greatest']),
        account_helper.generate_aws_instance(accounts['normie_greatest']),
        account_helper.generate_aws_instance(accounts['normie_greatest']),
        account_helper.generate_aws_instance(accounts['normie_greatest']),
    ],
    'normie_another': [
        account_helper.generate_aws_instance(accounts['normie_another']),
        account_helper.generate_aws_instance(accounts['normie_another']),
    ],
    'super_spaghetti': [
        account_helper.generate_aws_instance(accounts['super_spaghetti']),
    ],
}
for account, account_instances in instances.items():
    for instance in account_instances:
        print(f'instance:'
              f'id={instance.id};'
              f'account_id={instance.account_id};')


times = [(
    util_helper.utc_dt(2018, 1, 12, 5, 0, 0),
    util_helper.utc_dt(2018, 1, 12, 6, 0, 0)
),]

events = []
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_greatest'][0], times,
    ec2_ami_id=images['normie_greatest']['rhel7'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_greatest'][1], times,
    ec2_ami_id=images['normie_greatest']['rhel7'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_greatest'][2], times,
    ec2_ami_id=images['normie_greatest']['rhel8'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_greatest'][3], times,
    ec2_ami_id=images['normie_greatest']['plain'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_another'][0], times,
    ec2_ami_id=images['normie_another']['ocp'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['normie_another'][1], times,
    ec2_ami_id=images['normie_another']['ocp'].ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instances['super_spaghetti'][0], times,
    ec2_ami_id=images['super_spaghetti']['rhel_other'].ec2_ami_id,
))

for event in events:
    print(f'event.instance.account.id={event.instance.account.id};'
          f'event.occurred_at={event.occurred_at};'
          f'event.event_type={event.event_type};'
          f'event.machineimage.ec2_ami_id={event.machineimage.ec2_ami_id};')
