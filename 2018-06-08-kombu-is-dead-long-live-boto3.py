import collections
from queue import Empty
import kombu
from django.conf import settings
from django.utils import timezone
from django.utils.translation import gettext as _
from rest_framework.serializers import ValidationError
from account import AWS_PROVIDER_STRING
from account.models import (AwsInstance, AwsInstanceEvent, AwsMachineImage,
                            ImageTag, InstanceEvent)
from util.aws import is_instance_windows
from account.util import _create_exchange_and_queue
from account.util import add_messages_to_queue


queue_name = 'brasmith-test-12345'
add_messages_to_queue(queue_name, [{'foo': 'bar'}])
__, message_queue = _create_exchange_and_queue(queue_name)

messages = []
max_count = 4

with kombu.Connection(settings.CELERY_BROKER_URL) as conn:
    try:
        consumer = conn.SimpleQueue(name=message_queue)
        while len(messages) < max_count:
            message = consumer.get_nowait()
            messages.append(message.payload)
            print(message)
            message.ack()
    except Empty as e:
        print('####### exception!!!')
        print(e)
        pass
    print('####### before exit')

# ------------------------


import boto3
sqs = boto3.client('sqs')

# ec2.describe_snapshots(OwnerIds=['372779871274'])
# {'Snapshots': [{'Description': '', 'Encrypted': False, 'OwnerId': '372779871274', 'Progress': '0%', 'SnapshotId': 'snap-04c8e90820f851101', 'StartTime': datetime.datetime(2018, 4, 11, 14, 31, 8, tzinfo=tzutc()), 'State': 'pending', 'VolumeId': 'vol-ffffffff', 'VolumeSize': 0}], 'ResponseMetadata': {'RequestId': '5c2f6212-5bff-4acb-8369-a19f4f2256b3', 'HTTPStatusCode': 200, 'HTTPHeaders': {'content-type': 'text/xml;charset=UTF-8', 'transfer-encoding': 'chunked', 'vary': 'Accept-Encoding', 'date': 'Wed, 11 Apr 2018 14:31:19 GMT', 'server': 'AmazonEC2'}, 'RetryAttempts': 0}}


# ---------------------------

cloudigrade
./cloudigrade/manage.py shell


from account.util import *
import datetime
import time
import uuid

original_messages = [
    'string',
    b'bytes',
    123,
    123.456,
    False,
    None,
    [1, 2, 3],
    {4, 5, 6},
    (7, 8, 9),
    {'foo': 'bar'},
    datetime.datetime.now(),
]


queue_name = f'brasmith-{uuid.uuid4()}'  # very unique queue name!
queue_name

read_messages_from_queue(queue_name)
read_messages_from_queue(queue_name, max_count=12324)

add_messages_to_queue(queue_name, original_messages)

read_messages_from_queue(queue_name)
read_messages_from_queue(queue_name)

read_messages_from_queue(queue_name, max_count=12324)

time.sleep(30)  # AWS SQS default re-queue time is 30 sec. If messages are still gone after 30 seconds, they were properly deleted.
