import faker

from account.tests import helper as account_helper
from util.tests import helper as util_helper


_faker = faker.Faker()

user_1 = util_helper.generate_test_user()

print(f'user_1.id={user_1.id};'
      f'user_1.username={user_1.username};')

account_1 = account_helper.generate_aws_account(
    user=user_1, name=_faker.bs())

print(f'account_1.id={account_1.id};'
      f'account_1.user_id={account_1.user_id};'
      f'account_1.name={account_1.name};')

instance_1 = account_helper.generate_aws_instance(account_1)

print(f'instance_1.id={instance_1.id};'
      f'instance_1.account_id={instance_1.account_id};')

image_rhel = account_helper.generate_aws_image(
    account_1, is_rhel=True,
    ec2_ami_id='ami-rhel')

print(f'image_rhel.id={image_rhel.id};'
      f'image_rhel.ec2_ami_id={image_rhel.ec2_ami_id};'
      )

events = account_helper.generate_aws_instance_events(
    instance_1,
    [(
        util_helper.utc_dt(2018, 1, 11, 5, 0, 0),
        util_helper.utc_dt(2018, 1, 11, 6, 0, 0)
    ),
    (
        util_helper.utc_dt(2018, 1, 11, 7, 0, 0),
        util_helper.utc_dt(2018, 1, 11, 8, 0, 0)
    ),
    (
        util_helper.utc_dt(2018, 1, 11, 9, 0, 0),
        util_helper.utc_dt(2018, 1, 11, 10, 0, 0)
    )],
    ec2_ami_id=image_rhel.ec2_ami_id,
)

for event in events:
    print(f'event.instance.account.id={event.instance.account.id};'
          f'event.occurred_at={event.occurred_at};'
          f'event.event_type={event.event_type};'
          f'event.machineimage.ec2_ami_id={event.machineimage.ec2_ami_id};')
