#!/bin/bash

if [ -z "$PHOTON_5_X86" ]
then
    echo "PHOTON_5_X86 $PHOTON_5_X86 is unset using photon 4"
    DEFAULT_SRC_IMAGE_NAME="ph4-rt-refresh.iso"
    DEFAULT_DST_IMAGE_NAME="ph4-rt-refresh_adj.iso"
else
    echo "PHOTON_5_X86 is $PHOTON_5_X86 is set using photon 5"
    DEFAULT_SRC_IMAGE_NAME="ph5-rt-refresh.iso"
    DEFAULT_DST_IMAGE_NAME="ph5-rt-refresh_adj.iso"
fi

## a default name reference ISO will be renamed.
#DEFAULT_IMAGE_NAME="ph4-rt-refresh.iso"
## default image name build_iso.sh produced
#DEFAULT_IMAGE_NAME="ph4-rt-refresh_adj.iso"
