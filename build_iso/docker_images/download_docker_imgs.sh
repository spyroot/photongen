#!/bin/bash
DEFAULT_IMAGE_NAME=vcu.tar.gz
if [[ ! -v BUILD_HOST ]]; then
    echo "BUILD_HOST is not set"
elif [[ -z "$BUILD_HOST" ]]; then
    echo "BUILD_HOST is set to the empty string"
else
  scp vmware@"$BUILD_HOST":/home/vmware/$DEFAULT_IMAGE_NAME $DEFAULT_IMAGE_NAME
fi