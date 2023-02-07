#!/bin/bash
# This mandatory shared vars.  Please don't change.
# spyroot@gmail.com
# Author Mustafa Bayramov

if [ -z "$PHOTON_5_X86" ]
then
    echo "PHOTON_5_X86 $PHOTON_5_X86 is unset, target build photon 4"
    DEFAULT_SRC_IMAGE_NAME="ph4-rt-refresh.iso"
    DEFAULT_DST_IMAGE_NAME="ph4-rt-refresh_adj.iso"
else
    echo "PHOTON_5_X86 is $PHOTON_5_X86 is set, target build photon 5"
    DEFAULT_SRC_IMAGE_NAME="ph5-rt-refresh.iso"
    DEFAULT_DST_IMAGE_NAME="ph5-rt-refresh_adj.iso"
fi

export BUILD_TYPE="offline"
# all direct rpms will download and stored in direct_rpms
DEFAULT_RPM_DIR="direct_rpms"
# all cloned and tar.gzed repos in git_repos
DEFAULT_GIT_DIR="git_images"
# all downloaded tar.gz ( drivers and other arc) will be in direct.
DEFAULT_ARC_DIR="direct"

# this directory will be created inside ISO
DEFAULT_RPM_DST_DIR="direct_rpms"
# this directory will be created inside ISO
DEFAULT_GIT_DST_DIR="git_images"
# this directory will be created inside ISO
DEFAULT_ARC_DST_DIR="direct"
