#!/bin/bash
# Pull reference iso.
# Creates container and pull all requested packages.
# Container will run build_iso script and generate new iso file.
# The new iso file generate to be a reference kick-start unattended installer.
# Note: that docker run use current dir as volume make sure if you run on macos you
# current dir added to resource.    Docker -> Preference -> Resource and add dir.
#
#
# in additional_direct_rpms.json, rpms we need to install postinstall.
# ["wget -nc http://MY_IP/my.rpm -P /tmp/  >> /etc/postinstall",
#"tdnf install -y /tmp/my.rpm  >> /etc/postinstall"]
#
# in additional_load_docker.json image that we want to load post install
#
# Author Mustafa Bayramov

# lint in case it has error.
jsonlint ks.ref.cfg
jsonlint additional_direct_rpms.json
jsonlint additional_files.json
jsonlint additional_load_docker.json
jsonlint additional_packages.json
jsonlint additional_rpms.json

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

DEFAULT_ISO_LOCATION="https://drive.google.com/u/0/uc?id=101hVCV14ln0hkbjXZEI38L3FbcrvwUNB&export=download&confirm=1e-b"
DEFAULT_IMAGE_NAME="ph4-rt-refresh_adj.iso"

DEFAULT_HOSTNAME="photon-machine"
DEFAULT_BOOT_SIZE="8192"
DEFAULT_ROOT_SIZE="8192"
DEFAULT_ALWAYS_CLEAN="yes"

# usage log "msg"
log() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}


current_os=$(uname -a)
if [[ $current_os == *"xnu"* ]]; then
	brew_info_out=$(brew info wget | grep bottled)
	if [[ $brew_info_out == *"vault: stable"* ]]; then
		echo "wget already installed."
	else
		brew install wget
	fi
fi

if [[ $current_os == *"linux"* ]]; then
  apt-get update
  apt-get install ca-certificates curl gnupg lsb-release python3-demjson
  DOCKER_PGP_FILE=/etc/apt/keyrings/docker.gpg
  if [ -f "$DOCKER_PGP_FILE" ]; then
    echo "$DOCKER_PGP_FILE exists."
  else
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
			$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi
  apt-get update
  apt-get install aufs-tools cgroupfs-mount docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
fi

PUB_KEY=$HOME/.ssh/id_rsa.pub
current_ks_phase="ks.ref.cfg"
if test -f "$PUB_KEY"; then
  export ssh_key=$(cat "$HOME"/.ssh/id_rsa.pub)
  jq --arg key "$ssh_key" '.public_key = $key' ks.ref.cfg >ks.phase1.cfg
  current_ks_phase="ks.phase1.cfg"
  jsonlint ks.phase1.cfg
else
  ssh-keygen
fi

# read additional_packages and add required.
ADDITIONAL=additional_packages.json
[ ! -f $ADDITIONAL ] && {
  echo "$ADDITIONAL file not found"
  exit 99
}
packages=$(cat $ADDITIONAL)
jq --argjson p "$packages" '.additional_packages += $p' $current_ks_phase >ks.phase2.cfg
current_ks_phase="ks.phase2.cfg"
jsonlint $current_ks_phase

# adjust hostname
jq --arg p "$DEFAULT_HOSTNAME" '.hostname=$p' $current_ks_phase >ks.phase3.cfg
current_ks_phase="ks.phase3.cfg"
jsonlint $current_ks_phase

# adjust /root partition if needed
jq --arg s "$DEFAULT_ROOT_SIZE" '.partitions[1].size=$s' $current_ks_phase >ks.phase4.cfg
current_ks_phase="ks.phase4.cfg"
jsonlint $current_ks_phase

# adjust /boot partition if needed
jq --arg s "$DEFAULT_BOOT_SIZE" '.partitions[2].size=$s' $current_ks_phase >ks.phase5.cfg
current_ks_phase="ks.phase5.cfg"
jsonlint $current_ks_phase

# adjust installation and add additional if needed.
ADDITIONAL_RPMS=additional_direct_rpms.json
[ ! -f $ADDITIONAL_RPMS ] && {
  echo "$ADDITIONAL_RPMS file not found"
  exit 99
}
rpms=$(cat $ADDITIONAL_RPMS)
jq --argjson p "$rpms" '.postinstall += $p' $current_ks_phase >ks.phase6.cfg
current_ks_phase="ks.phase6.cfg"
jsonlint $current_ks_phase

# additional docker load.
DOCKER_LOAD_POST_INSTALL=additional_load_docker.json
[ ! -f $DOCKER_LOAD_POST_INSTALL ] && {
  echo "$DOCKER_LOAD_POST_INSTALL file not found"
  exit 99
}
docker_imgs=$(cat $DOCKER_LOAD_POST_INSTALL)
jq --argjson i "$docker_imgs" '.postinstall += $i' $current_ks_phase >ks.phase7.cfg
current_ks_phase="ks.phase7.cfg"
jsonlint $current_ks_phase

# additional files that we copy from cdorom
ADDITIONAL_FILES=additional_files.json
[ ! -f $ADDITIONAL_FILES ] && {
  echo "$ADDITIONAL_FILES file not found"
  exit 99
}
additional_files=$(cat $ADDITIONAL_FILES)
jq --argjson f "$additional_files" '. += $f' $current_ks_phase >ks.cfg
current_ks_phase="ks.cfg"
jsonlint $current_ks_phase

rm ks.phase[0-9].cfg
wget -nc -O $DEFAULT_IMAGE_NAME "$DEFAULT_ISO_LOCATION"

# by a default we always do clean build
if [[ ! -v DEFAULT_ALWAYS_CLEAN ]]; then
    log "Detecting an existing image."
    existing_img=$(docker inspect photon_iso_builder | jq '.[0].Id')
    if [[ -z "$existing_img" ]]; then
        log "Image not found, building new image."
        docker build -t spyroot/photon_iso_builder:1.0 .
    fi
elif [[ -z "$DEFAULT_ALWAYS_CLEAN" ]]; then
    echo "DEFAULT_ALWAYS_CLEAN is set to the empty string"
else
  log "Always clean build set to true, rebuilding image."
  docker rm -f /photon_iso_builder
  docker build -t spyroot/photon_iso_builder:1.0 .
fi

container_id=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20)

# we need container running set NO_REMOVE_POST
if [[ ! -v NO_REMOVE_POST ]]; then
    log "Starting without container auto-remove."
    docker run --pull always -v `pwd`:`pwd` -w `pwd` \
         --privileged --name photon_iso_builder_"$container_id" \
         -i -t spyroot/photon_iso_builder:1.0 bash
else
  log "Starting container with auto-remove."
  docker run --pull always -v `pwd`:`pwd` -w `pwd` \
		--privileged --name photon_iso_builder_"$container_id" \
		--rm -i -t spyroot/photon_iso_builder:1.0 bash
fi
