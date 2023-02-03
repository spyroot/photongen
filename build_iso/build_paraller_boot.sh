#!/bin/bash
# source should have following.
# comma separated list of IPS in the env.
#example:
#
#export IDRAC_IPS="192.168.1.1,192.168.1.2"
#export IDRAC_PASSWORD="password"
#export IDRAC_USERNAME"root"
#export IDRAC_REMOTE_HTTP

source shared.bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
source shared.env.bash# default image name build_iso.sh produced
DEFAULT_IMAGE_NAME=$DEFAULT_DST_IMAGE_NAME
# a location where to copy iso, assume same host runs http.
DEFAULT_LOCATION_MOVE="/var/www/html/"
IDRAC_IP_ADDR=""

# all envs
if [ ! -f cluster.env ]
then
    echo "Please create cluster\.env file"
    exit 99
else
  source cluster.env
fi

#trim white spaces
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# usage log "msg"
log() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}

if [ ! -f $DEFAULT_IMAGE_NAME ]
then
    echo "Please create iso file $DEFAULT_IMAGE_NAME first."
    exit 99
fi

if [[ -z "$IDRAC_IPS" ]]; then
  echo "Please set address of http server in IDRAC_REMOTE_HTTP environment variable."
  exit 99
fi

if ! command -v pip &> /dev/null
then
    echo "please install pip3"
    exit 99
fi

pip --quiet install idrac_ctl -U

## build-iso.sh generates ph4-rt-refresh_adj.iso
cp $DEFAULT_IMAGE_NAME $DEFAULT_LOCATION_MOVE

# by a default we always do clean build
if [[ -z "$IDRAC_IPS" ]]; then
  log "IDRAC_IPS variable is empty, it must store either IP address or list comma seperated."
	exit 99
else
  log "Using $IDRAC_IPS."
fi

# first trim all whitespace and then iterate.
IDRAC_IP_LIST=$(trim $IDRAC_IPS)
echo "$IDRAC_IP_ADDR"
IFS=',' read -ra IDRAC_IP_ADDR <<< "$IDRAC_IP_LIST"
for IDRAC_HOST in "${IDRAC_IP_ADDR[@]}"
do
  addr=$(trim "$IDRAC_HOST")
  export IDRAC_IP="$addr"; idrac_ctl get_vm --device_id 1 --filter_key Inserted
  export IDRAC_IP="$addr"; idrac_ctl eject_vm --device_id 1
  export IDRAC_IP="$addr"; idrac_ctl insert_vm --uri_path http://"$IDRAC_REMOTE_HTTP"/$DEFAULT_IMAGE_NAME --device_id 1
  export IDRAC_IP="$addr"; idrac_ctl boot-one-shot --device Cd -r --power_on
done