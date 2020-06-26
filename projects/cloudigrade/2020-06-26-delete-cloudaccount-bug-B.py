from django.conf import settings
from api.models import CloudAccount
from util.tests import helper as util_helper
from api.tasks import delete_from_sources_kafka_message

CloudAccount.objects.count()

CloudAccount.objects.first()

account_number = "1701"
user = util_helper.get_test_user(account_number)

auth_id = 10

message, headers = util_helper.generate_authentication_create_message_value(
    account_number, account_number, platform_id=auth_id
)
delete_from_sources_kafka_message(
    message, headers, settings.AUTHENTICATION_DESTROY_EVENT
)
