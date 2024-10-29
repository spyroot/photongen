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
NC='\033[0m'
# by default, target build RT 4.0
DEFAULT_RELEASE="4.0"

# a location form where to pull reference ISO
DEFAULT_ISO_LOCATION_4_X86="https://drive.google.com/u/0/uc?id=101hVCV14ln0hkbjXZEI38L3FbcrvwUNB&export=download&confirm=1e-b"
DEFAULT_ISO_PHOTON_5_X86="https://packages.vmware.com/photon/5.0/GA/iso/photon-rt-5.0-dde71ec57.x86_64.iso"
DEFAULT_ISO_PHOTON_5_ARM="https://packages.vmware.com/photon/5.0/Beta/iso/photon-5.0-9e778f409-aarch64.iso"
DEFAULT_PACAKGE_LOCATION="https://packages.vmware.com/photon/5.0/photon_updates_5.0_x86_64/"
# https://packages.vmware.com/photon/5.0/photon_updates_5.0_x86_64/
DEFAULT_IMAGE_LOCATION=$DEFAULT_ISO_LOCATION_4_X86
DEFAULT_DOCKER_IMAGE="spyroot/photon_iso_builder:latest"
#
DEFAULT_RPM_DIR="direct_rpms"
DEFAULT_GIT_DIR="git_images"
DEFAULT_ARC_DIR="direct"

AVX_VERSION=4.12.5
MLNX_VER=5.4-1.0.3.0
NL_VER="3.2.25"

DPDK_VER="24.03.0"
# 22.11, 22.11.1, 22.07, 22.03. 21.11, 21.11.3, 21.11.2

MELLANOX_DOWNLOAD_URL="http://www.mellanox.com/downloads/ofed/MLNX_OFED-"$MLNX_VER"/MLNX_OFED_SRC-debian-"$MLNX_VER".tgz"
INTEL_DOWNLOAD_URL="https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz"
LIB_NL_DOWNLOAD="https://www.infradead.org/~tgr/libnl/files/libnl-$NL_VER.tar.gz"
DPDK_DOWNLOAD="http://fast.dpdk.org/rel/dpdk-$DPDK_VER.tar.xz"

SKIP_GIT="no"
SKIP_RPMS_DOWNLOAD="no"
SKIP_BUILD_CONTAINER="no"

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
  DEFAULT_JSON_SPEC_DIR=$BUILD_TYPE
fi

# default hostname
DEFAULT_HOSTNAME="photon-machine"
# default size for /boot
DEFAULT_BOOT_SIZE="8192"
# default size for /root
DEFAULT_ROOT_SIZE="8192"
# will remove docker image
#DEFAULT_ALWAYS_CLEAN="yes"

ADDITIONAL_FILES=$DEFAULT_JSON_SPEC_DIR/additional_files.json
ADDITIONAL_DIRECT_RPMS=$DEFAULT_JSON_SPEC_DIR/additional_direct_rpms.json
ADDITIONAL_PACKAGES=$DEFAULT_JSON_SPEC_DIR/additional_packages.json
DOCKER_LOAD_POST_INSTALL=$DEFAULT_JSON_SPEC_DIR/additional_load_docker.json
ADDITIONAL_RPMS=$DEFAULT_JSON_SPEC_DIR/additional_rpms.json
ADDITIONAL_GIT_REPOS=$DEFAULT_JSON_SPEC_DIR/additional_git_clone.json
ADDITIONAL_REMOTE_RPMS=$DEFAULT_JSON_SPEC_DIR/additional_remote_rpms.json

function generate_key_if_need() {
  # add ssh key
  local pub_key_location
  pub_key_location=$HOME/.ssh/id_rsa.pub
  current_ks_phase="ks.ref.cfg"
  if test -f "$pub_key_location"; then
    local ssh_key
    ssh_key=$(cat "$HOME"/.ssh/id_rsa.pub)
    export ssh_key
    jq --arg key "$ssh_key" '.public_key = $key' ks.ref.cfg >ks.phase1.cfg
    current_ks_phase="ks.phase1.cfg"
    jsonlint ks.phase1.cfg
  else
    ssh-keygen
  fi
}

function generate_kick_start() {
  local current_os
  current_os=$(uname -a)
  if [[ $current_os == *"xnu"* ]]; then
    local brew_info_out
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
    local DOCKER_PGP_FILE
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

  generate_key_if_need

  # read additional_packages and add required.
  [ ! -f $ADDITIONAL_PACKAGES ] && {
    echo "$ADDITIONAL_PACKAGES file not found"
    exit 99
  }

  local packages
  packages=$(cat $ADDITIONAL_PACKAGES)
  jq --argjson p "$packages" '.additional_packages += $p' "$current_ks_phase" >ks.phase2.cfg
  current_ks_phase="ks.phase2.cfg"
  jsonlint $current_ks_phase

  # adjust hostname
  jq --arg p "$DEFAULT_HOSTNAME" '.hostname=$p' $current_ks_phase >ks.phase3.cfg
  current_ks_phase="ks.phase3.cfg"
  jsonlint $current_ks_phase

  # adjust release
  if [[ "$DEFAULT_RELEASE" == "4.0" ]]; then
    echo "Strings are equal."
    jq --arg r "$DEFAULT_RELEASE" '.photon_release_version=$r' $current_ks_phase >ks.phase4.cfg
    current_ks_phase="ks.phase4.cfg"
    jsonlint $current_ks_phase
  else
    log "removing photon_release_version."
  fi

  # adjust /root partition if needed
  jq --argjson s "$DEFAULT_ROOT_SIZE" '.partitions[1].size=$s' "$current_ks_phase" >ks.phase5.cfg
  current_ks_phase="ks.phase5.cfg"
  jsonlint $current_ks_phase

  # adjust /boot partition if needed
  jq --argjson s "$DEFAULT_BOOT_SIZE" '.partitions[2].size=$s' "$current_ks_phase" >ks.phase6.cfg
  current_ks_phase="ks.phase6.cfg"
  jsonlint $current_ks_phase

  # adjust installation and adds additional rpms located on remote location.
  [ ! -f $ADDITIONAL_REMOTE_RPMS ] && {
    echo "$ADDITIONAL_REMOTE_RPMS file not found"
    exit 99
  }
  local rpms
  rpms=$(cat $ADDITIONAL_REMOTE_RPMS)
  jq --argjson p "$rpms" '.postinstall += $p' $current_ks_phase >ks.phase7.cfg
  current_ks_phase="ks.phase7.cfg"
  jsonlint $current_ks_phase

#
#  local rpms
#  rpms=$(cat $ADDITIONAL_REMOTE_RPMS)
#  jq --argjson p "$rpms" '.postinstall += $p' $current_ks_phase >ks.phase7.cfg
#  current_ks_phase="ks.phase7.cfg"
#  jsonlint $current_ks_phase
#  jq --raw-output -c '.[]' $ADDITIONAL_DIRECT_RPMS | while read -r rpm_pkg; do
#    mkdir -p direct_rpms
#    local url_target
#    url_target="$DEFAULT_PACAKGE_LOCATION${rpm_pkg}.rpm"
#    log "Downloading $url_target to $DEFAULT_RPM_DIR$"
#    wget -q -nc "$url_target" -O $DEFAULT_RPM_DIR/"${rpm_pkg}".rpm
#  done

  # additional docker load.
  [ ! -f $DOCKER_LOAD_POST_INSTALL ] && {
    echo "$DOCKER_LOAD_POST_INSTALL file not found"
    exit 99
  }
  local docker_imgs
  docker_imgs=$(cat $DOCKER_LOAD_POST_INSTALL)
  jq --argjson i "$docker_imgs" '.postinstall += $i' $current_ks_phase >ks.phase8.cfg
  current_ks_phase="ks.phase8.cfg"
  jsonlint $current_ks_phase

  # additional files that we copy from a cdrom
  [ ! -f "$ADDITIONAL_FILES" ] && {
    echo "$ADDITIONAL_FILES file not found"
    exit 99
  }
  local additional_files
  additional_files=$(cat "$ADDITIONAL_FILES")
  jq --argjson f "$additional_files" '. += $f' $current_ks_phase >ks.cfg
  current_ks_phase="ks.cfg"
  jsonlint $current_ks_phase

  rm ks.phase[0-9].cfg

  # extra check if ISO os not bootable
  wget -nc -O $DEFAULT_SRC_IMAGE_NAME "$DEFAULT_IMAGE_LOCATION"
  local ISO_IS_BOOTABLE
  ISO_IS_BOOTABLE=$(file $DEFAULT_SRC_IMAGE_NAME | grep bootable)
  if [ -z "$ISO_IS_BOOTABLE" ]; then
    log "Invalid iso image, failed boot flag check."
    exit 99
  fi
}

# build a container that will be used to as shell
# to generate iso file from a spec.
function build_container() {
  if [ -z "$SKIP_BUILD_CONTAINER" ] || [ $SKIP_BUILD_CONTAINER == "yes" ]; then
    log "Skipping rpm downloading."
  else
    # by a default we always do clean build
    if [[ ! -v DEFAULT_ALWAYS_CLEAN ]]; then
      log "Detecting an existing image."
      local existing_img
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
  fi
}

function start_container() {
  #is_darwin=$(uname -a|grep Darwin)
  local container_id
  container_id=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20)

  # we need container running set NO_REMOVE_POST
  if [[ ! -v NO_REMOVE_POST ]]; then
    log "Starting without container auto-remove."
    docker run --pull always -v $(pwd):$(pwd) -w $(pwd) \
      --privileged --name photon_iso_builder_"$container_id" \
      -i -t "$DEFAULT_DOCKER_IMAGE" bash
  else
    log "Starting container with auto-remove."
    docker run --pull always -v $(pwd):$(pwd) -w $(pwd) \
      --privileged --name photon_iso_builder_"$container_id" \
      --rm -i -t "$DEFAULT_DOCKER_IMAGE" bash
  fi
}

# git clone , create tar.gz for each repo
# each cloned will go to a final ISO.
function git_clone() {
  local git_repo
  local repo_name
  local suffix
  local git_repos_dir

  suffix=".git"
  git_repos_dir="git_repos"
  if [ -z "$SKIP_GIT" ] || [ $SKIP_GIT == "yes" ]; then
    log "Skipping git cloning."
  else
    # do a cleanup first.
    rm -rf $git_repos_dir
    jq --raw-output -c '.[]' $ADDITIONAL_GIT_REPOS | while read -r git_repo; do
      local repo_name
      repo_name=${git_repo/%$suffix/}
      repo_name=${repo_name##*/}
      mkdir -p git_repos/"$repo_name"
      echo "Git cloning git clone $git_repo $repo_name"
      git clone "$git_repo" $git_repos_dir/"$repo_name"
      repo_tmp_dir="$git_repos_dir/$repo_name"
      echo "Compressing $repo_tmp_dir"
      tar -zcvf "$repo_name".tar.gz "$repo_tmp_dir"
      mkdir -p git_images
      mv "$repo_name".tar.gz $DEFAULT_GIT_DIR
    done
    rm -rf $git_repos_dir
  fi
}

# Downloads all rpms to DEFAULT_PACAKGE_LOCATION
function download_rpms() {
  local rpm_pkg
  if [ -z "$DEFAULT_PACAKGE_LOCATION" ]; then
    log "DEFAULT_PACAKGE_LOCATION empty."
    return 1
  fi

  if [ -z "$SKIP_RPMS_DOWNLOAD" ] || [ $SKIP_RPMS_DOWNLOAD == "yes" ]; then
    log "Skipping rpm downloading."
  else
    mkdir -p $DEFAULT_RPM_DIR
    log "Downloading rpms."
    jq --raw-output -c '.[]' $ADDITIONAL_DIRECT_RPMS | while read -r rpm_pkg; do
      mkdir -p direct_rpms
      local url_target
      url_target="$DEFAULT_PACAKGE_LOCATION${rpm_pkg}.rpm"
      log "Downloading $url_target to $DEFAULT_RPM_DIR$"
      wget -q -nc "$url_target" -O $DEFAULT_RPM_DIR/"${rpm_pkg}".rpm
    done
  fi
}

# Download all tar gz that wil lgo to final ISO.
function download_direct() {
  echo "Downloading $MELLANOX_DOWNLOAD_URL"
  wget -q -nc $MELLANOX_DOWNLOAD_URL --directory-prefix=direct
  echo "Downloading $INTEL_DOWNLOAD_URL"
  wget -q -nc $INTEL_DOWNLOAD_URL --directory-prefix=direct
  echo "Downloading $LIB_NL_DOWNLOAD"
  wget -q -nc $LIB_NL_DOWNLOAD --directory-prefix=direct
  echo "Downloading $DPDK_DOWNLOAD"
  wget -q -nc $DPDK_DOWNLOAD --directory-prefix=direct
}

function print_and_validate_specs() {
  echo "Using $ADDITIONAL_FILES"
  echo "Using $ADDITIONAL_PACKAGES"
  echo "Using $ADDITIONAL_DIRECT_RPMS"
  echo "Using $ADDITIONAL_RPMS"
  echo "Using $ADDITIONAL_REMOTE_RPMS"
  echo "Using $DOCKER_LOAD_POST_INSTALL"

  echo "Will download $DEFAULT_IMAGE_LOCATION"
  echo "Will download $MELLANOX_DOWNLOAD_URL --directory-prefix=$DEFAULT_ARC_DIR"
  echo "Will download $INTEL_DOWNLOAD_URL --directory-prefix=$DEFAULT_ARC_DIR"
  echo "Will download $LIB_NL_DOWNLOAD --directory-prefix=$DEFAULT_ARC_DIR"
  echo "Will download $DPDK_DOWNLOAD --directory-prefix=$DEFAULT_ARC_DIR"
  echo "All RPMS wil downloaded to $DEFAULT_RPM_DIR"
  echo "All GIT tars will be wil downloaded to $ADDITIONAL_GIT_REPOS"
  echo "All archive  will be wil downloaded to $ADDITIONAL_GIT_REPOS"
  echo "All archive  will be wil downloaded to $DEFAULT_ARC_DIR"

  jq -c '.[]' $ADDITIONAL_GIT_REPOS | while read -r repo; do
    mkdir -p direct
    echo "Will git clone $repo"
  done

  echo "Verifying JSON files"
  jsonlint ks.ref.cfg
  jsonlint $ADDITIONAL_FILES
  jsonlint $ADDITIONAL_PACKAGES
  jsonlint $ADDITIONAL_DIRECT_RPMS
  jsonlint $ADDITIONAL_RPMS
  jsonlint $DOCKER_LOAD_POST_INSTALL
  jsonlint $ADDITIONAL_GIT_REPOS
  jsonlint $ADDITIONAL_REMOTE_RPMS
}

function main() {

  print_and_validate_specs
  local choice
  read -r -p "Please check and confirm (y/n)?" choice
  case "$choice" in
  y | Y) echo "yes" ;;
  n | N) return 1 ;;
  *) echo "invalid" ;;
  esac

  download_direct
  download_rpms
  git_clone
  generate_kick_start
}

main
