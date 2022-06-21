#!/usr/bin/env bash

echo -n "Enter Tools Account profile name > "
read ToolsAccount
echo -n "Enter codecommit repository name for Infra ci/cd > "
read InfraRepositoryName
echo -n "Enter codecommit repository name for App ci/cd > "
read AppRepositoryName

aws codecommit create-repository --repository-name $InfraRepositoryName --repository-description "AB-3 Infra CI/CD" --profile $ToolsAccount
aws codecommit create-repository --repository-name $AppRepositoryName --repository-description "AB-3 App CI/CD" --profile $ToolsAccount

