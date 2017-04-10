#!/bin/bash -e

fly -t $DEPLOYMENT_NAME login  -n  $DEPLOYMENT_NAME -c $CONCOURSE_URL -u $CONCOURSE_USER -p $CONCOURSE_PASSWORD

function update_pipeline()
{
  product_name=$1
  pipeline_repo=$2
  echo "Updating pipeline $product_name"
  fly -t $DEPLOYMENT_NAME set-pipeline -n -p deploy-$product_name \
              --config="concourse-deploy-$product_name/ci/pipeline.yml" \
              --var="vault-address=$VAULT_ADDR" \
              --var="vault-token=$VAULT_TOKEN" \
              --var="foundation-name=$DEPLOYMENT_NAME" \
              --var="deployment-name=$product_name" \
              --var="pipeline-repo=$pipeline_repo" \
              --var="pipeline-repo-branch=master" \
              --var="pipeline-repo-private-key=$GIT_PRIVATE_KEY" \
              --var="product-name=$product_name"
}

update_pipeline redis $DEPLOY_REDIS_GIT_URL
update_pipeline turbulence $DEPLOY_TURBULENCE_GIT_URL
update_pipeline chaos-loris $DEPLOY_CHAOS_LORIS_GIT_URL

export CONCOURSE_URI=$CONCOURSE_URL
export CONCOURSE_TARGET=$DEPLOYMENT_NAME
export PRODUCT_NAME=rabbitmq
export FOUNDATION_NAME=$DEPLOYMENT_NAME
export PIPELINE_REPO=$DEPLOY_RABBITMQ_GIT_URL
export PIPELINE_REPO_BRANCH=master
echo $GIT_PRIVATE_KEY > git-private-key.pem
export PIPELINE_REPO_PRIVATE_KEY_PATH=git-private-key.pem
export BOSH_ENVIRONMENT=${BOSH_URL#https://}
export BOSH_CLIENT=$bosh_client_id
export BOSH_CLIENT_SECRET=$bosh_client_secret
echo $bosh_cacert > bosh-ca-cert.pem
export BOSH_CA_CERT=bosh-ca-cert.pem

concourse-deploy-rabbitmq/setup-pipeline.sh
