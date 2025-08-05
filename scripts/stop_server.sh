#!/bin/bash

# Use `docker ps -aq` to find ANY container (running or stopped) by its name
CONTAINER_ID=$(sudo docker ps -aq --filter name=my-devops-app-container)

# Check if a container was found
if [ -n "$CONTAINER_ID" ]; then
  echo "Found old container $CONTAINER_ID. Stopping and removing it."
  sudo docker stop $CONTAINER_ID
  sudo docker rm $CONTAINER_ID
fi