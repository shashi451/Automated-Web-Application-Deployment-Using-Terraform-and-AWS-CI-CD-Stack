#!/bin/bash
# This script is for the EC2 instance
CONTAINER_ID=$(sudo docker ps -q --filter name=my-devops-app-container)
if [ -n "$CONTAINER_ID" ]; then
  sudo docker stop $CONTAINER_ID
  sudo docker rm $CONTAINER_ID
fi