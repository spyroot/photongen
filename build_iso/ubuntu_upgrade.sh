#!/bin/bash
# Upgrades Ubuntu distro upgrade and docker.
#
# spyroot@gmail.com
# Author Mustafa Bayramov

RELEASE_UPGRADE="no"
DOCKER_UPGRADE="no"

# disk need extended

PATH_TO_PGP="etc/apt/keyrings/docker.gpg"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# log green
log_green() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}

# log red
log_red() {
  printf "%b %s. %b\n" "${RED}" "$@" "${NC}"
}

if [ -z "$RELEASE_UPGRADE" ]
then
	log_green "Skipping release upgrade phase."
else
  if [ $RELEASE_UPGRADE == "yes" ]
  then
    log_green "Upgrading operating system."
    do-release-upgrade; apt-get update; apt-get upgrade; apt-get dist-upgrade
  else
    log_green "Skipping release upgrade phase."
  fi
fi

if [ -z "$DOCKER_UPGRADE" ]
then
	log_green "Skipping docker upgrade phase."
else
    if [ $RELEASE_UPGRADE == "yes" ]
    then
      log_green "Upgrading operating system."
      apt-get remove docker docker-engine docker.io containerd runc
      apt-get update; apt-get install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o $PATH_TO_PGP
      log_green "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update; apt-get install docker-ce docker-ce-cli \
      containerd.io docker-compose-plugin
    else
      log_green "Skipping release upgrade phase."
    fi
fi
