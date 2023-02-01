#!/bin/bash

AVX_VERSION=4.5.3
MLNX_VER=5.4-1.0.3.0

#cd /tmp || exit
#mkdir -p /tmp/mlnx_ofed_src
#wget http://www.mellanox.com/downloads/ofed/MLNX_OFED-"$MLNX"/MLNX_OFED_SRC-debian-"$MLNX".tgz \
#--directory-prefix=/tmp/mlnx_ofed_src -O MLNX_OFED_SRC-debian-"$MLNX".tgz
#tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1
#
#mkdir -p /tmp/iavf
#wget https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz \
#--directory-prefix=/tmp/iavf -O iavf-$AVX_VERSION.tar.gz
#cd /tmp/iavf || exit
#tar -zxvf iavf-* -C iavf --strip-components=1
#cd /tmp/iavf/src || exit
#make && make install
