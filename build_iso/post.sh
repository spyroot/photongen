#!/bin/bash
# This is post install script.  The goal here build MLX and Intel driver.
# spyroot@gmail.com
# Author Mustafa Bayramov

AVX_VERSION=4.5.3
MLNX_VER=5.4-1.0.3.0
MLX_BUILD=yes
INTEL_BUILD=yes

docker load < /vcu1.tar.gz
MLX_DIR=/tmp/mlnx_ofed_src
INTEL_DIR=/tmp/iavf

mkdir -p $MLX_DIR
mkdir -p $INTEL_DIR

export PATH=$PATH:/usr/local/bin
yum -y install python3-libcap-ng python3-devel rdma-core-devel util-linux-devel zip zlib zlib-devel libxml2-devel libudev-devel
cd /root || exit; mkdir -p build; git clone https://github.com/intel/intel-ipsec-mb.git
cd intel-ipsec-mb || exit; make -j 8
make install; ldconfig

if [ -z "$MLX_BUILD" ]
then
    echo "Skipping Mellanox driver build."
else
  MLX_IMG=http://www.mellanox.com/downloads/ofed/MLNX_OFED-"$MLNX_VER"/MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  MLX_FILE_NAME=MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  cd /tmp || exit; wget $MLX_IMG --directory-prefix=$MLX_DIR -O $MLX_FILE_NAME
  tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1
fi

if [ -z "$INTEL_BUILD" ]
then
    echo "Skipping intel driver build"
else
  INTEL_IMG=https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz
  cd /tmp || exit; wget $INTEL_IMG --directory-prefix=$INTEL_DIR -O iavf-$AVX_VERSION.tar.gz
  tar -zxvf iavf-* -C iavf --strip-components=1
  cd $INTEL_DIR/src || exit
  make && make install
fi

#reboot
