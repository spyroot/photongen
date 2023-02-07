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
