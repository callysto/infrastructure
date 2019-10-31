meta_files=(
  analytics_api/meta/main.yml
  certs/meta/main.yml
  common/meta/main.yml
  demo/meta/main.yml
  discovery/meta/main.yml
  ecommerce/meta/main.yml
  ecomworker/meta/main.yml
  edxapp/meta/main.yml
  edxlocal/meta/main.yml
  elasticsearch/meta/main.yml
  forum/meta/main.yml
  insights/meta/main.yml
  journals/meta/main.yml
  mongo_3_2/meta/main.yml
  mysql/meta/main.yml
  nginx/meta/main.yml
  notifier/meta/main.yml
  rabbitmq/meta/main.yml
  server_utils/meta/main.yml
  user/meta/main.yml
  xqueue/meta/main.yml
)

cd ~/work/callysto-infra/ansible/roles/edx/configuration/playbooks/roles
for i in ${meta_files[@]}; do
  echo $i
  mv $i $i.orig
done
