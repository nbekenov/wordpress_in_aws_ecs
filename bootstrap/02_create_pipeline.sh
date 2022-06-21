#!/usr/bin/env bash
echo -n "Enter project name >"
read ProjectName
echo -n "Enter codecommit repository name> "
read RepositoryName

# ToolsAccount
echo -n "Enter ToolsAccount ProfileName for AWS Cli operations [tools]> "
read ToolsAccountProfile
ToolsAccountProfile=${ToolsAccountProfile:-tools}
ToolsAccount=$(eval aws sts get-caller-identity --profile=$ToolsAccountProfile | jq -r ".Account")
echo "ToolsAccount=$ToolsAccount"
# TestAccount
echo -n "Enter TestAccount ProfileName for AWS Cli operations [test]> "
read TestAccountProfile
TestAccountProfile=${TestAccountProfile:-test}
TestAccount=$(eval aws sts get-caller-identity --profile=$TestAccountProfile | jq -r ".Account")
echo "TestAccount=$TestAccount"
# ProdAccount
echo -n "Enter ProdAccount ProfileName for AWS Cli operations [prod]> "
read ProdAccountProfile
ProdAccountProfile=${ProdAccountProfile:-prod}
ProdAccount=$(eval aws sts get-caller-identity --profile=$ProdAccountProfile | jq -r ".Account")
echo "ProdAccount=$ProdAccount"

echo -n "Deploying pre-requisite stack to the tools account... "
pre_requisite_stack="${ProjectName}-pre-reqs"

aws cloudformation deploy --stack-name $pre_requisite_stack \
    --template-file cloudformation/pre-reqs.yml \
    --profile $ToolsAccountProfile \
    --parameter-overrides pProjectName=$ProjectName pTestAccount=$TestAccount pProductionAccount=$ProdAccount

echo -n "Fetching S3 bucket and CMK ARN from CloudFormation automatically..."
get_s3_command="aws cloudformation describe-stacks --stack-name $pre_requisite_stack --profile $ToolsAccountProfile --query \"Stacks[0].Outputs[?OutputKey=='oArtifactBucket'].OutputValue\" --output text"
ArtifactBucket=$(eval $get_s3_command)
echo "Got Artifact bucket name: $ArtifactBucket"
get_cmk_command="aws cloudformation describe-stacks --stack-name $pre_requisite_stack --profile $ToolsAccountProfile --query \"Stacks[0].Outputs[?OutputKey=='oCMK'].OutputValue\" --output text"
CMKArn=$(eval $get_cmk_command)
echo "Got CMK ARN: $CMKArn"
echo "====================="

pipeline_deployer_roles_stack="${ProjectName}-pipeline-deployer-roles"

echo -n "Executing in TEST Account"
aws cloudformation deploy --stack-name $pipeline_deployer_roles_stack \
    --template-file cloudformation/cloudformation-deployer-role.yml \
    --profile $TestAccountProfile \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides pProjectName=$ProjectName pToolsAccount=$ToolsAccount pCmkArn=$CMKArn  pArtifactBucket=$ArtifactBucket
echo "====================="

echo -n "Executing in PROD Account"
aws cloudformation deploy --stack-name $pipeline_deployer_roles_stack \
    --template-file cloudformation/cloudformation-deployer-role.yml \
    --profile $ProdAccountProfile \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides pProjectName=$ProjectName pToolsAccount=$ToolsAccount pCmkArn=$CMKArn  pArtifactBucket=$ArtifactBucket
echo "====================="

echo -n "Creating Pipeline in Tools Account"
pipeline_stack="${ProjectName}-cicd-pipeline"
aws cloudformation deploy --stack-name $pipeline_stack \
    --template-file cloudformation/code-pipeline.yml \
    --profile $ToolsAccountProfile \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides pProjectName=$ProjectName pTestAccount=$TestAccount pProductionAccount=$ProdAccount pCmkArn=$CMKArn  pArtifactBucket=$ArtifactBucket pRepositoryName=$RepositoryName
echo "====================="

echo -n "Adding Permissions to the CMK"
aws cloudformation deploy --stack-name $pre_requisite_stack \
    --template-file cloudformation/pre-reqs.yml \
    --profile $ToolsAccountProfile \
    --parameter-overrides pCodeBuildCondition=true
echo "====================="