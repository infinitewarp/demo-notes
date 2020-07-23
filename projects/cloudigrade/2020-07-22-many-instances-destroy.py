import time
import boto3

client = boto3.client('ec2', region_name='us-east-1')
describe_response = client.describe_instances()
verbose = False

for reservation in describe_response.get('Reservations', []):
    for instance in reservation.get('Instances', []):
        instance_id = instance['InstanceId']
        current_state = instance.get('State', {}).get('Name', '')

        # Only terminate not-already-terminated instances.
        if current_state != 'terminated':
            print(
                f'Terminating instance ID {instance_id} '
                f'having state {current_state}'
            )
            terminate_response = client.terminate_instances(
                InstanceIds=[instance_id]
            )
            print(terminate_response)
        elif verbose:
            print(
                f'Instance ID {instance_id} is still visible, '
                'but it was already terminated.'
            )
