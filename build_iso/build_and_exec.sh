#!/bin/bash
# Pull reference iso. This scrip main role.
# Creates container and pull all packages required to build ISO.
# It takes all json files.
#   - additional_direct_rpms.json rpms that we put to want to put to iso or over a network.
#   - additional_files.json docker images / drivers that we serialize to final ISO.
#   - ks.ref.cfg  is reference kickstart file.  don't delete or change it.
#   - by default key from $HOME/.ssh/id_rsa.pub injected to kickstart.
#
# The container itself client need  build_iso.sh script, and it will generate
# new iso file.
# The new iso file generate to be a reference kick-start unattended installer.
# Note: that docker run use current dir as volume make sure if you run on macOS you
# current dir added to resource.    Docker -> Preference -> Resource and add dir.
#
#
# spyroot@gmail.com
# Author Mustafa Bayramov

# lint in case it has error.
jsonlint ks.ref.cfg
jsonlint additional_direct_rpms.json
jsonlint additional_files.json
jsonlint additional_load_docker.json
jsonlint additional_packages.json
jsonlint additional_rpms.json

source shared.bash

if [[ -z "$DEFAULT_DST_IMAGE_NAME" ]]; then
  echo "Please make sure you have in shared\.bash DEFAULT_DST_IMAGE_NAME var"
  exit 99
fi

if [[ -z "$DEFAULT_DST_IMAGE_NAME" ]]; then
  echo "Please make sure you have in shared\.bash DEFAULT_DST_IMAGE_NAME var"
  exit 99
fi

if [[ -z "$BUILD_TYPE" ]]; then
  echo "Please make sure you have in shared\.bash BUILD_TYPE var"
  exit 99
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
# by default it RT 4.0
DEFAULT_RELEASE="4.0"

# a location form where to pull reference ISO
DEFAULT_ISO_LOCATION_4_X86="https://drive.google.com/u/0/uc?id=101hVCV14ln0hkbjXZEI38L3FbcrvwUNB&export=download&confirm=1e-b"
DEFAULT_ISO_PHOTON_5_X86="https://packages.vmware.com/photon/5.0/Beta/iso/photon-rt-5.0-9e778f409.iso"
DEFAULT_ISO_PHOTON_5_ARM="https://packages.vmware.com/photon/5.0/Beta/iso/photon-5.0-9e778f409-aarch64.iso"
DEFAULT_IMAGE_LOCATION=$DEFAULT_ISO_LOCATION_4_X86
DEFAULT_DOCKER_IMAGE="spyroot/photon_iso_builder:latest"
# comma seperated
DEFAULT_DOCKER_ARC="linux/amd64"
DEFAULT_FLAVOR="linux-rt"

# usage log "msg"
log() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
}

if [[ -n "$PHOTON_5_ARM" ]]; then
  log "Building photon 5 arm iso."
  DEFAULT_IMAGE_LOCATION=$DEFAULT_ISO_PHOTON_5_ARM
  DEFAULT_RELEASE="5.0"
fi

if [[ -n "$PHOTON_5_X86" ]]; then
  log "Building photon 5 x86 RT iso."
  DEFAULT_IMAGE_LOCATION=$DEFAULT_ISO_PHOTON_5_X86
  DEFAULT_RELEASE="5.0"
fi

# this default type
DEFAULT_JSON_SPEC_DIR="online"
if [[ -n "$BUILD_TYPE" ]]; then
  DEFAULT_JSON_SPEC=BUILD_TYPE
fi

# default hostname
DEFAULT_HOSTNAME="photon-machine"
# default size for /boot
DEFAULT_BOOT_SIZE="8192"
# default size for /root
DEFAULT_ROOT_SIZE="8192"
# will remove docker image
#DEFAULT_ALWAYS_CLEAN="yes"

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

# add ssh key
PUB_KEY=$HOME/.ssh/id_rsa.pub
current_ks_phase="ks.ref.cfg"
if test -f "$PUB_KEY"; then
  ssh_key=$(cat "$HOME"/.ssh/id_rsa.pub)
  export ssh_key
  jq --arg key "$ssh_key" '.public_key = $key' ks.ref.cfg >ks.phase1.cfg
  current_ks_phase="ks.phase1.cfg"
  jsonlint ks.phase1.cfg
else
  ssh-keygen
fi

# read additional_packages and add required.
ADDITIONAL=$DEFAULT_JSON_SPEC_DIR/additional_packages.json
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

if [[ "$DEFAULT_RELEASE" == "4.0" ]]; then
    # adjust release
    echo "Strings are equal."
    jq --arg r "$DEFAULT_RELEASE" '.photon_release_version=$r' $current_ks_phase >ks.phase4.cfg
    current_ks_phase="ks.phase4.cfg"
    jsonlint $current_ks_phase
else
    log "removing photon_release_version."
fi


# adjust /root partition if needed
jq --arg s "$DEFAULT_ROOT_SIZE" '.partitions[1].size=$s' $current_ks_phase >ks.phase5.cfg
current_ks_phase="ks.phase5.cfg"
jsonlint $current_ks_phase

# adjust /boot partition if needed
jq --arg s "$DEFAULT_BOOT_SIZE" '.partitions[2].size=$s' $current_ks_phase >ks.phase6.cfg
current_ks_phase="ks.phase6.cfg"
jsonlint $current_ks_phase

jq -c '.[]' $FILE | while read -r i; do
  wget --recursive --no-parent https://packages.vmware.com/photon/4.0/photon_updates_4.0_x86_64/x86_64/"${i}".rpm
done

# adjust installation and add additional if needed.
ADDITIONAL_RPMS=$DEFAULT_JSON_SPEC_DIR/additional_direct_rpms.json
[ ! -f $ADDITIONAL_RPMS ] && {
  echo "$ADDITIONAL_RPMS file not found"
  exit 99
}

jq -c '.[]' $ADDITIONAL_RPMS | while read -r i; do
  mkdir -p direct_rpms
  wget -q -nc https://packages.vmware.com/photon/4.0/photon_updates_4.0_x86_64/x86_64/"${i}".rpm
done

rpms=$(cat $ADDITIONAL_RPMS)
jq --argjson p "$rpms" '.postinstall += $p' $current_ks_phase >ks.phase7.cfg
current_ks_phase="ks.phase7.cfg"
jsonlint $current_ks_phase

# additional docker load.
DOCKER_LOAD_POST_INSTALL=$DEFAULT_JSON_SPEC_DIR/additional_load_docker.json
[ ! -f $DOCKER_LOAD_POST_INSTALL ] && {
  echo "$DOCKER_LOAD_POST_INSTALL file not found"
  exit 99
}
docker_imgs=$(cat $DOCKER_LOAD_POST_INSTALL)
jq --argjson i "$docker_imgs" '.postinstall += $i' $current_ks_phase >ks.phase8.cfg
current_ks_phase="ks.phase8.cfg"
jsonlint $current_ks_phase

# additional files that we copy from a cdrom
ADDITIONAL_FILES=$DEFAULT_JSON_SPEC/additional_files.json
[ ! -f "$ADDITIONAL_FILES" ] && {
  echo "$ADDITIONAL_FILES file not found"
  exit 99
}
additional_files=$(cat "$ADDITIONAL_FILES")
jq --argjson f "$additional_files" '. += $f' $current_ks_phase >ks.cfg
current_ks_phase="ks.cfg"
jsonlint $current_ks_phase

rm ks.phase[0-9].cfg

# extra check if ISO os not bootable
wget -nc -O $DEFAULT_SRC_IMAGE_NAME "$DEFAULT_IMAGE_LOCATION"
ISO_IS_BOOTABLE=$(file $DEFAULT_SRC_IMAGE_NAME | grep bootable)
if [ -z "$ISO_IS_BOOTABLE" ]; then
  log "Invalid iso image, failed boot flag check."
  exit 99
fi

# by a default we always do clean build
if [[ ! -v DEFAULT_ALWAYS_CLEAN ]]; then
    log "Detecting an existing image."
    existing_img=$(docker inspect "$DEFAULT_DOCKER_IMAGE" | jq '.[0].Id')
    if [[ -z "$existing_img" ]]; then
        log "Image not found, building a new image."
        docker build -t "$DEFAULT_DOCKER_IMAGE" . --platform $DEFAULT_DOCKER_ARC
    fi
elif [[ -z "$DEFAULT_ALWAYS_CLEAN" ]]; then
    echo "DEFAULT_ALWAYS_CLEAN is set to the empty string"
else
  log "Always clean build set to true, rebuilding image."
  docker rm -f /photon_iso_builder --platform $DEFAULT_DOCKER_ARC
  docker build -t "$DEFAULT_DOCKER_IMAGE" .
fi

#is_darwin=$(uname -a|grep Darwin)
container_id=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20)

# we need container running set NO_REMOVE_POST
if [[ ! -v NO_REMOVE_POST ]]; then
    log "Starting without container auto-remove."
    docker run --pull always -v `pwd`:`pwd` -w `pwd` \
         --privileged --name photon_iso_builder_"$container_id" \
         -i -t "$DEFAULT_DOCKER_IMAGE" bash
else
  log "Starting container with auto-remove."
  docker run --pull always -v `pwd`:`pwd` -w `pwd` \
		--privileged --name photon_iso_builder_"$container_id" \
		--rm -i -t "$DEFAULT_DOCKER_IMAGE" bash
fi
