import boto3

image_id = 'ami-0293da6a'
instance_type = 't1.micro'
count = 10

resource = boto3.resource('ec2', region_name='us-east-1')
response = resource.create_instances(
    InstanceType=instance_type,
    ImageId=image_id,
    MinCount=count,
    MaxCount=count,
)

print('created instances:')
for item in response:
    print(item)
