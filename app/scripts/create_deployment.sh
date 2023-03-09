#!/usr/bin/env bash

ENV=$1
echo "environment: $ENV"
INFRA_PREFIX="demo-infra"
DOMAIN_NAME="XXXXXXXX"
if [ "$ENV" != "prod" ]; then
  DOMAIN_NAME="$ENV.XXXXXXXX"
fi
SITE_URL="https://$DOMAIN_NAME"
echo "DOMAIN_NAME: $DOMAIN_NAME"
echo "SITE_URL: $SITE_URL"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile=$ENV --query 'Account' --output text )
S3_BUCKET_NAME="appspec-bucket-$AWS_ACCOUNT_ID"
TARGET_ID="$INFRA_PREFIX-ecs-cluster:$INFRA_PREFIX-ecs-service"

# create task definition file
rDataBaseCredentials=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rDataBaseCredentials" | jq -r ".SecretList[0].ARN")
rAuthKey=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rAuthKey" | jq -r ".SecretList[0].ARN")
rSecureAuthKey=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rSecureAuthKey" | jq -r ".SecretList[0].ARN")
rLoggedInKey=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rLoggedInKey" | jq -r ".SecretList[0].ARN")
rNonceKey=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rNonceKey" | jq -r ".SecretList[0].ARN")
rAuthSalt=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rAuthSalt" | jq -r ".SecretList[0].ARN")
rSecureAuthSalt=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rSecureAuthSalt" | jq -r ".SecretList[0].ARN")
rLoggedInSalt=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rLoggedInSalt" | jq -r ".SecretList[0].ARN")
rNonceSalt=$(aws secretsmanager list-secrets --profile=$ENV --filter Key="name",Values="rNonceSalt" | jq -r ".SecretList[0].ARN")
imageUri=$(cat imagedefinitions.json | jq -r ".[0].imageUri")
containerName=$(cat imagedefinitions.json | jq -r ".[0].name")
FileSystemId=$(aws efs describe-file-systems  --profile=$ENV --query "FileSystems[?Name=='EcsWordpress/content'].FileSystemId" --output json | jq -r '.[]')
logGroup=$(aws logs describe-log-groups --profile=$ENV --log-group-name-prefix $INFRA_PREFIX-ecs-logs | jq -r ".logGroups[0].logGroupName")
rdsEndpoint=$(aws rds describe-db-clusters --profile=$ENV --query "DBClusters[?DatabaseName=='auroramysqldb'].Endpoint" --output json | jq -r '.[]')

sed -e "s#<rDataBaseCredentials>#$rDataBaseCredentials#" \
    -e "s#<rAuthKey>#$rAuthKey#" \
    -e "s#<rSecureAuthKey>#$rSecureAuthKey#" \
    -e "s#<rLoggedInKey>#$rLoggedInKey#" \
    -e "s#<rNonceKey>#$rNonceKey#" \
    -e "s#<rAuthSalt>#$rAuthSalt#" \
    -e "s#<rSecureAuthSalt>#$rSecureAuthSalt#" \
    -e "s#<rLoggedInSalt>#$rLoggedInSalt#" \
    -e "s#<rNonceSalt>#$rNonceSalt#" \
    -e "s#<imageUri>#$imageUri#" \
    -e "s#<containerName>#$containerName#" \
    -e "s#<FileSystemId>#$FileSystemId#" \
    -e "s#<rdsEndpoint>#$rdsEndpoint#" \
    -e "s#<logGroup>#$logGroup#" \
    -e "s#<DOMAIN_NAME>#$DOMAIN_NAME#" \
    -e "s#<SITE_URL>#$SITE_URL#" \
    -e "s#<AWS_ACCOUNT_ID>#$AWS_ACCOUNT_ID#" deploy/taskdef.json | tee /tmp/taskdef.json

echo "======================================================="
echo "registering new task version ..."
aws ecs register-task-definition --profile=$ENV --cli-input-json file:///tmp/taskdef.json | tee /tmp/rtd
TASK_DEF_ARN=$(cat /tmp/rtd | jq -r .taskDefinition.taskDefinitionArn)
echo "new task def arn: $TASK_DEF_ARN"
echo "======================================================="

echo "create bucket $S3_BUCKET_NAME"
aws s3 mb s3://appspec-bucket-$AWS_ACCOUNT_ID --profile=$ENV
echo "update <TASK_DEFINITION> and upload appspec.yaml"
sed -e "s#<TASK_DEFINITION>#$TASK_DEF_ARN#" deploy/appspec.yaml | tee /tmp/appspec.yaml
aws s3 cp /tmp/appspec.yaml s3://$S3_BUCKET_NAME/appspec.yaml --profile=$ENV
echo "======================================================="

cat << EOF > /tmp/deployment.json
{
    "applicationName": "$INFRA_PREFIX-wordpress",
    "deploymentGroupName": "$INFRA_PREFIX-wordpress-dg",
    "revision": {
        "revisionType": "S3",
        "s3Location": {
            "bucket": "$S3_BUCKET_NAME",
            "key": "appspec.yaml",
            "bundleType": "YAML"
        }
    }
}
EOF
echo "creating deployment ..."
aws deploy create-deployment --profile=$ENV --cli-input-json file:///tmp/deployment.json 2>&1 | tee /tmp/deploymentId
deploymentId=$(cat /tmp/deploymentId | jq -r .deploymentId)

echo "======================================================="
echo "waiting for deployment $deploymentId to finish ..."
while date; do
  aws deploy get-deployment-target --profile=$ENV --target-id $TARGET_ID --deployment-id $deploymentId 2>&1 | tee /tmp/dep-target
  if cat /tmp/dep-target | grep "Deployment status: CREATED"; then
    sleep 10
    continue
  fi
  if cat /tmp/dep-target | jq -r .deploymentTarget.ecsTarget.status | egrep InProgress; then
    echo "still InProgress ..."
  else
    if cat /tmp/dep-target | grep "An error occurred"; then
      exit 1
    else
      break
    fi
  fi
  sleep 10
done