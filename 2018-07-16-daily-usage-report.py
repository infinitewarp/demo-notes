import faker

from account.tests import helper as account_helper
from util.tests import helper as util_helper


_faker = faker.Faker()

user_1 = util_helper.generate_test_user()
user_2 = util_helper.generate_test_user()
user_super = util_helper.generate_test_user(is_superuser=True)

print(f'user_1.id={user_1.id};'
      f'user_1.username={user_1.username};')
print(f'user_2.id={user_2.id};'
      f'user_2.username={user_2.username};')
print(f'user_super.id={user_super.id};'
      f'user_super.username={user_super.username};')

account_1 = account_helper.generate_aws_account(
    user=user_1, name=_faker.bs())
account_2 = account_helper.generate_aws_account(
    user=user_1, name=_faker.bs())

print(f'account_1.id={account_1.id};'
      f'account_1.user_id={account_1.user_id};'
      f'account_1.name={account_1.name};')
print(f'account_2.id={account_2.id};'
      f'account_2.user_id={account_2.user_id};'
      f'account_2.name={account_2.name};')

instance_1 = account_helper.generate_aws_instance(account_1)
instance_2 = account_helper.generate_aws_instance(account_1)
instance_3 = account_helper.generate_aws_instance(account_1)
instance_4 = account_helper.generate_aws_instance(account_2)

print(f'instance_1.id={instance_1.id};'
      f'instance_1.account_id={instance_1.account_id};')
print(f'instance_2.id={instance_2.id};'
      f'instance_2.account_id={instance_2.account_id};')
print(f'instance_3.id={instance_3.id};'
      f'instance_3.account_id={instance_3.account_id};')
print(f'instance_4.id={instance_4.id};'
      f'instance_4.account_id={instance_4.account_id};')

image_plain = account_helper.generate_aws_image(
    account_1,
    ec2_ami_id='ami-plain')
# image_windows = account_helper.generate_aws_image(
#     account_1, is_windows=True)
image_rhel = account_helper.generate_aws_image(
    account_1, is_rhel=True,
    ec2_ami_id='ami-rhel')
image_ocp = account_helper.generate_aws_image(
    account_1, is_openshift=True,
    ec2_ami_id='ami-ocp')
image_rhel_ocp = account_helper.generate_aws_image(
    account_2, is_rhel=True, is_openshift=True,
    ec2_ami_id='ami-rhel_ocp')

print(f'image_plain.id={image_plain.id};'
      f'image_plain.ec2_ami_id={image_plain.ec2_ami_id};'
      # f'image_rhel.rhel={image_rhel.rhel};'
      # f'image_rhel.openshift={image_rhel.openshift};'
      )
print(f'image_rhel.id={image_rhel.id};'
      f'image_rhel.ec2_ami_id={image_rhel.ec2_ami_id};'
      # f'image_rhel.rhel={image_rhel.rhel};'
      # f'image_rhel.openshift={image_rhel.openshift};'
      )
print(f'image_ocp.id={image_ocp.id};'
      f'image_ocp.ec2_ami_id={image_ocp.ec2_ami_id};'
      # f'image_ocp.rhel={image_ocp.rhel};'
      # f'image_ocp.openshift={image_ocp.openshift};'
      )
print(f'image_rhel_ocp.id={image_rhel_ocp.id};'
      f'image_rhel_ocp.ec2_ami_id={image_rhel_ocp.ec2_ami_id};'
      # f'image_rhel_ocp.rhel={image_rhel_ocp.rhel};'
      # f'image_rhel_ocp.openshift={image_rhel_ocp.openshift};'
      )

events = []
events.extend(account_helper.generate_aws_instance_events(
    instance_1,
    [(
        util_helper.utc_dt(2018, 1, 9, 3, 0, 0),
        util_helper.utc_dt(2018, 1, 11, 3, 0, 0)
    )],
    ec2_ami_id=image_plain.ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instance_2,
    [(
        util_helper.utc_dt(2017, 12, 24, 3, 0, 0),
        util_helper.utc_dt(2017, 12, 29, 3, 0, 0)
    ),
    (
        util_helper.utc_dt(2018, 1, 10, 5, 0, 0),
        util_helper.utc_dt(2018, 1, 12, 5, 0, 0)
    ),
    (
        util_helper.utc_dt(2018, 2, 20, 5, 0, 0),
        util_helper.utc_dt(2018, 2, 23, 5, 0, 0)
    ),],
    ec2_ami_id=image_rhel.ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instance_3,
    [(
        util_helper.utc_dt(2018, 1, 11, 7, 0, 0),
        util_helper.utc_dt(2018, 1, 13, 7, 0, 0)
    )],
    ec2_ami_id=image_ocp.ec2_ami_id,
))
events.extend(account_helper.generate_aws_instance_events(
    instance_4,
    [(
        util_helper.utc_dt(2018, 1, 12, 9, 0, 0),
        util_helper.utc_dt(2018, 1, 14, 9, 0, 0)
    )],
    ec2_ami_id=image_rhel_ocp.ec2_ami_id,
))

for event in events:
    print(f'event.instance.account.id={event.instance.account.id};'
          f'event.occurred_at={event.occurred_at};'
          f'event.event_type={event.event_type};'
          f'event.machineimage.ec2_ami_id={event.machineimage.ec2_ami_id};')
