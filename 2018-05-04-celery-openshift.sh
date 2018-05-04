# 2018-05-04 DEMO NOTES


# asciinema rec

cloudigrade

make oc-login-developer

oc replace -f ./deployment/ocp/cloudigrade.yml && oc process cloudigrade-persistent-template \
-p NAMESPACE=myproject \
-p AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
-p AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
-p DJANGO_ALLOWED_HOSTS=* \
-p DJANGO_DATABASE_HOST=postgresql.myproject.svc \
-p RABBITMQ_HOST=rabbitmq.myproject.svc \
-p CELERY_REPLICA_COUNT=1 | oc replace -f - ; sleep 1; make oc-build-and-push-cloudigrade


oc rollout status dc/cloudigrade-celery

oc get pods -l name=cloudigrade-celery

oc describe pod -l name=cloudigrade-celery | less

oc logs $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery) | less





# oc describe pod $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery) | less



oc logs -c cloudigrade-celery $(oc get pods -o jsonpath='{.items[*].metadata.name}' -l name=cloudigrade-celery)
