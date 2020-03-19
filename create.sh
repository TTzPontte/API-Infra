#!/bin/bash
if [ "$1" == "" ]; 
then
  ENV="dev"
else
  ENV=$1
fi

if [ "$ENV" == "prod" ] 
then
  echo -n "Deploying to prod. Confirm? [y/N] "
  read confirmation

  if [ "$confirmation" != "y" -a "$confirmation" != "Y" ]
  then
    exit
  fi
fi

GITHUB=$2

AWS_PROFILE="default"
PROJECT_NAME="API"

echo "Start: api-base-$ENV"

aws cloudformation create-stack --stack-name api-base-$ENV --template-body file://$(pwd)/base.yaml --profile $AWS_PROFILE \
  --parameters ParameterKey=Project,ParameterValue=$PROJECT_NAME \
  ParameterKey=Environment,ParameterValue=$ENV 

echo "Waiting: api-base-$ENV"

aws cloudformation wait stack-create-complete --stack-name  api-base-$ENV --profile $AWS_PROFILE

echo "Created: api-base-$ENV"

S3Base=$(aws s3api list-buckets --query 'Buckets[?starts_with(Name, `api-base-'$ENV'`) == `true`].Name' --output text --profile $AWS_PROFILE)

echo "Upload files to $S3Base"

aws s3api put-object --bucket $S3Base --key API/ --profile $AWS_PROFILE
aws s3 sync API/ s3://$S3Base/API --profile $AWS_PROFILE

echo "Uploaded files"
echo "--------------------"
echo " "
echo "Start: api-infra-$ENV"

aws cloudformation create-stack --stack-name api-infra-$ENV --template-body file://$(pwd)/cfn-api-infra.yaml --profile $AWS_PROFILE \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=Environment,ParameterValue=$ENV \
   ParameterKey=Project,ParameterValue=$PROJECT_NAME \
   ParameterKey=TemplateStackName,ParameterValue=api-base-$ENV

echo "Waiting: api-infra-$ENV"

aws cloudformation wait stack-create-complete --stack-name  api-infra-$ENV --profile $AWS_PROFILE

echo "Created: api-infra-$ENV"
echo "--------------------"
echo " "
echo "Start: api-ci-cd-$ENV"

echo "Paramenters: GITHUB-$GITHUB"

aws cloudformation create-stack --stack-name api-ci-cd-$ENV --template-body file://$(pwd)/cfn-ci-cd-api.yaml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=Environment,ParameterValue=$ENV \
   ParameterKey=Project,ParameterValue=$PROJECT_NAME \
   ParameterKey=TemplateStackName,ParameterValue=api-base-$ENV \
   ParameterKey=RepositoryName,ParameterValue=API \
   ParameterKey=GithubSecret,ParameterValue=$GITHUB

   #https://github.com/settings/tokens

echo "Wainting: api-ci-cd-$ENV"

aws cloudformation wait stack-create-complete --stack-name api-ci-cd-$ENV --profile $AWS_PROFILE

echo "Created: api-ci-cd-$ENV"

