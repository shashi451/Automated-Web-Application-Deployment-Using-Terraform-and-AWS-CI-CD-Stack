#!/bin/bash
# This script is for the EC2 instance
set -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
IMAGE_REPO_NAME="my-devops-app"
# The exact image tag is provided by CodeDeploy from the imagedefinitions.json file
# We construct the full URI to log in to the right repository
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE_URI_WITH_TAG_FROM_CODEDEPLOY="$ECR_URI/$IMAGE_REPO_NAME:latest" # CodeDeploy replaces this

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | sudo docker login --username AWS --password-stdin $ECR_URI

# The $IMAGE_URI variable is made available by CodeDeploy based on the imagedefinitions.json file.
# We are using a placeholder here for clarity, but CodeDeploy will use the correct one.
sudo docker run -d --name my-devops-app-container -p 80:80 $IMAGE_URI_WITH_TAG_FROM_CODEDEPLOY