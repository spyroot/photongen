#!/bin/bash

# All dev dependancies we need to compile DPDK, kernel mods etc
# Melanox DPKD build for PhotonOS.

# Author Mustafa Bayramov 

yum install -y  gdb valgrind systemtap ltrace strace python3-devel \
 tar lshw libnuma numactl \
 libnuma libnuma-devel numactl \
 zip zlib zlib-devel \
 git util-linux-devel libxml2-devel curl-devel zlib-devel \
 elfutils-devel libgcrypt-devel libxml2-devel linux-devel \
 lua-devel dtc-devel tuned tcpdump netcat cmake meson \
 build-essential wget \
 gdb valgrind systemtap ltrace strace \

# Python dependancies 
yum install -y python-sphinx python3-sphinxyum

# Tuned dependancies 
systemctl enable tuned
systemctl start tuned
tuned-adm profile latency-performance

# OFED tool
cd /root/ || exit
wget http://www.mellanox.com/downloads/ofed/MLNX_OFED-5.4-1.0.3.0/MLNX_OFED_SRC-debian-5.4-1.0.3.0.tgz
tar xfz MLNX_OFED_SRC-debian-5.4-1.0.3.0.tgz

# DPKD (change if you need adjust verion)
wget http://fast.dpdk.org/rel/dpdk-20.11.3.tar.xz
tar xf dpdk*
cd /root/build/dpdk-stable-20* || exit

kernel_ver=$(uname -r)
meson -Dplatform=native -Dexamples=all -Denable_kmods=true \
    -Dkernel_dir=/lib/modules/"$kernel_ver" \
    -Dibverbs_link=shared -Dwerror=true build
ninja -C build install