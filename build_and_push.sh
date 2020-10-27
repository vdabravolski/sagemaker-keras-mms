#!/usr/bin/env bash

# This script shows how to build the Docker image and push it to ECR to be ready for use
# by SageMaker.

# There are 3 arguments in this script:
#    - image - required, this will be used as the image on the local machine and combined with the account and region to form the repository name for ECR;
#    - tag - optional, if provided, it will be used as ":tag" of your image; otherwise, ":latest" will be used;
#    - Dockerfile - optional, if provided, then docker will try to build image from provided dockerfile (e.g. "Dockerfile.serving"); otherwise, default "Dcokerfile" will be used.
# Usage examples:
#    1. "./build_and_push.sh d2-sm-coco-serving debug Dockerfile.serving"
#    2. "./build_and_push.sh d2-sm-coco v2"

image=$1
tag=$2
dockerfile=$3

if [ "$image" == "" ]
then
    echo "Usage: $0 <image-name>"
    exit 1
fi


if [ "$tag" == "" ]
then
    $tag="latest"
fi


# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)
# Get the region defined in the current configuration
region=$(aws configure get region)
region=${region:-us-east-2}

if [ $? -ne 0 ]
then
    exit 255
fi

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${image}:${tag}"

# If the repository doesn't exist in ECR, create it.

aws ecr describe-repositories --repository-names "${image}" > /dev/null 2>&1

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${image}" > /dev/null
fi

# Get the login command from ECR and execute it directly
$(aws ecr get-login --region ${region} --no-include-email)

# Build the docker image locally with the image name and then push it to ECR
# with the full name.

if [ "$dockerfile" == "" ]
then
    docker build -t ${fullname} .
else
    docker build -t ${fullname} . -f ${dockerfile}
fi

docker push ${fullname}