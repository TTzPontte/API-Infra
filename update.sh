#!/bin/bash
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

aws cloudformation update-stack --stack-name api-base-$ENV --template-body file://$(pwd)/base.yaml --profile $AWS_PROFILE \
  --parameters ParameterKey=Project,ParameterValue=$PROJECT_NAME \
  ParameterKey=Environment,ParameterValue=$ENV 

echo "Updated: api-base-$ENV"

S3Base=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name, `api-base-'$ENV'`) == `true`].Name' --output text --profile $AWS_PROFILE)

echo "Upload files to $S3Base"

aws s3api put-object --bucket $S3Base --key API/ --profile $AWS_PROFILE
aws s3 sync API/ s3://$S3Base/api --profile $AWS_PROFILE

echo "Uploaded files"
echo "--------------------"
echo " "
echo "Start: api-infra-$ENV"

aws cloudformation update-stack --stack-name api-infra-$ENV --template-body file://$(pwd)/cfn-api-infra.yaml --profile $AWS_PROFILE \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=Environment,ParameterValue=$ENV \
   ParameterKey=Project,ParameterValue=$PROJECT_NAME \
   ParameterKey=TemplateStackName,ParameterValue=api-base-$ENV \

echo "Updated: api-infra-$ENV"
echo "--------------------"
echo " "
echo "Start: api-ci-cd-$ENV"

echo "Paramenters: GITHUB-$GITHUB"

aws cloudformation update-stack --stack-name api-ci-cd-$ENV --template-body file://$(pwd)/cfn-ci-cd-api.yaml --profile $AWS_PROFILE \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=Environment,ParameterValue=$ENV \
   ParameterKey=Project,ParameterValue=$PROJECT_NAME \
   ParameterKey=TemplateStackName,ParameterValue=api-base-$ENV \
   ParameterKey=RepositoryName,ParameterValue=API \
   ParameterKey=GithubSecret,ParameterValue=$GITHUB

echo "Updated: api-ci-cd-$ENV"
