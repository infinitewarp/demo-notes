from django.conf import settings
from api.models import CloudAccount
from api.tests import helper as api_helper
from util.tests import helper as util_helper
from api.tasks import delete_from_sources_kafka_message

CloudAccount.objects.count()

account_number = "1701"
user = util_helper.get_test_user(account_number)
aws_account_id = 273470430754
auth_id = 10
app_id = 20
end_id = 30
source_id = 40

api_helper.generate_aws_account(
    user=user,
    aws_account_id=aws_account_id,
    platform_authentication_id=auth_id,
    platform_application_id=app_id,
    platform_endpoint_id=end_id,
    platform_source_id=source_id,
)

message, headers = util_helper.generate_authentication_create_message_value(
    account_number, account_number, platform_id=auth_id
)
delete_from_sources_kafka_message(
    message, headers, settings.AUTHENTICATION_DESTROY_EVENT
)
