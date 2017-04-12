#!/bin/bash -e

fly -t $FOUNDATION_NAME login  -n  $FOUNDATION_NAME -c $CONCOURSE_URL -u $CONCOURSE_USER -p $CONCOURSE_PASSWORD

function update_pipeline()
{
  product_name=$1
  pipeline_repo=$2
  echo "Updating pipeline $product_name"
  fly -t $FOUNDATION_NAME set-pipeline -n -p deploy-$product_name \
              --config="concourse-deploy-$product_name/ci/pipeline.yml" \
              --var="vault-address=$VAULT_ADDR" \
              --var="vault-token=$VAULT_TOKEN" \
              --var="foundation-name=$FOUNDATION_NAME" \
              --var="deployment-name=$product_name" \
              --var="pipeline-repo=$pipeline_repo" \
              --var="pipeline-repo-branch=master" \
              --var="pipeline-repo-private-key=$GIT_PRIVATE_KEY" \
              --var="product-name=$product_name"
}

update_pipeline chaos-loris $DEPLOY_CHAOS_LORIS_GIT_URL
update_pipeline bluemedora $DEPLOY_BLUEMEDORA_GIT_URL
update_pipeline firehose-to-loginsight $DEPLOY_FIREHOSE_TO_LOGINSIGHT_GIT_URL
update_pipeline spring-services $DEPLOY_SPRING_SERVICES_GIT_URL

all_ips=$(prips $(echo "$PCF_SERVICES_STATIC" | sed 's/-/ /'))
OLD_IFS=$IFS
IFS=$'\n'
all_ips=($all_ips)
IFS=$OLD_IFS

echo "0" > /tmp/index
get_ips(){
  index=$(cat /tmp/index)
  res=""
  new_index=$(($index + $1))
  for ((i = $index; i < $new_index; i++))
  do
    res="$res,${all_ips[$i]}"
  done
  echo "$new_index" > /tmp/index
  echo "$res" | cut -c 2-
}

bosh_client_id=$(vault read -field=bosh-client-id secret/bosh-$FOUNDATION_NAME-props)
bosh_client_secret=$(vault read -field=bosh-client-secret secret/bosh-$FOUNDATION_NAME-props)
bosh_cacert=$(vault read -field=bosh-cacert secret/bosh-$FOUNDATION_NAME-props)

export CONCOURSE_URI=$CONCOURSE_URL
export CONCOURSE_TARGET=$FOUNDATION_NAME
export PIPELINE_REPO_BRANCH=master
echo "$GIT_PRIVATE_KEY" > git-private-key.pem
export PIPELINE_REPO_PRIVATE_KEY_PATH=../git-private-key.pem
export BOSH_ENVIRONMENT=${BOSH_URL#https://}
export BOSH_CLIENT=$bosh_client_id
export BOSH_CLIENT_SECRET=$bosh_client_secret
echo "$bosh_cacert" > bosh-ca-cert.pem
export BOSH_CA_CERT=../bosh-ca-cert.pem

pushd concourse-deploy-p-mysql
export PRODUCT_NAME=p-mysql
export PIPELINE_REPO=$DEPLOY_P_MYSQL_GIT_URL
cat > deployment-props.json <<EOF
{
  "network": "pcf-services",
  "ip": "$(get_ips 1)", 
  "proxy-ip": "$(get_ips 1)", 
  "monitoring-ip": "$(get_ips 1)", 
  "broker-ip": "$(get_ips 1)", 
  "notification-recipient-email": "noreply@vmware.com",
  "base-domain": "${SYSTEM_DOMAIN#sys.}"
  "az": "az1",
  "pivnet_api_token": "$PIVNET_API_TOKEN",
  "syslog-address": "$SYSLOG_ADDRESS" 
}
EOF

./setup-pipeline.sh
popd

pushd concourse-deploy-redis
export PRODUCT_NAME=redis
export PIPELINE_REPO=$DEPLOY_REDIS_GIT_URL
cat > deployment-props.json <<EOF
{
  "broker-ip": "$(get_ips 1)",
  "dedicated-nodes-ips": "$(get_ips 2)",
  "network-name": "pcf-services",
  "az": "az1",
  "vm-type": "medium",
  "disk-type": "medium",
  "syslog-aggregator-host": "$SYSLOG_ADDRESS",
  "syslog-aggregator-port": "514"
}
EOF

bin/update-pipeline
popd

cat > concourse-deploy-turbulence/deployment-props.json <<EOF
{
  "turbulence-api-ip":  "$(get_ips 1)",
  "turbulence-bosh-jobs": "cf-wdc1-prod:cloud_controller_worker-partition,cf-scdc1-prod:doppler-partition"
}
EOF
vault write secret/turbulence-$FOUNDATION_NAME-props @concourse-deploy-turbulence/deployment-props.json
update_pipeline turbulence $DEPLOY_TURBULENCE_GIT_URL

pushd concourse-deploy-rabbitmq
export PRODUCT_NAME=rabbitmq
export PIPELINE_REPO=$DEPLOY_RABBITMQ_GIT_URL
cat > deployment-props.json <<EOF
{
  "network": "pcf-services",
  "pivnet_api_token": "$PIVNET_API_TOKEN",
  "rabbit-public-ip": "$(get_ips 1)",
  "rabbit-server-ip": "$(get_ips 1)",
  "rabbit-broker-ip": "$(get_ips 1)",
  "syslog-address": "$SYSLOG_ADDRESS"
}
EOF
./setup-pipeline.sh
popd

