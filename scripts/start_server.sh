#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# This script needs 'jq' (a JSON parser) to read the image URI. Let's install it.
sudo yum install -y jq

# The imagedefinitions.json file is copied to this directory by CodeDeploy
APP_DIR="/home/ec2-user/app"
IMAGE_DEFINITIONS_FILE="$APP_DIR/imagedefinitions.json"

# Use jq to safely parse the JSON file and extract the image URI
IMAGE_URI=$(jq -r '.[0].imageUri' $IMAGE_DEFINITIONS_FILE)

# Login to ECR using the EC2 instance role
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
aws ecr get-login-password --region $AWS_REGION | sudo docker login --username AWS --password-stdin $ECR_URI

# Run the new container using the EXACT image URI from the build stage
# This ensures we are deploying the version that was just built
echo "Running Docker container with image: $IMAGE_URI"
sudo docker run -d --name my-devops-app-container -p 80:80 $IMAGE_URI