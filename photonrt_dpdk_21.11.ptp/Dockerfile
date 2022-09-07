# Author Mustafa Bayramov 
# First we pull all low level lib for intel ipsec.
# - Pull all the libs and build required for Mellanox PMD, i.e nl, rdma-core
# - Pull isal ( bpf / pcap / libcrypto part of yum install, hence we don't no need build anything )
# - OFED has all src for Mellanox distro.  This one optional
# - DPKD build with almost all libs and kmod all installed in kernel mod dir.
# - All DPDK libs compiled as shared and static including MLX iverbs etc. 
# - All installed globaly and add to LD_PATH.
# - Linux PTP based on latest source code.  Installed globally. 
# - ( Note systemd need reflect that from consumption point of view )
# - Lastly we build latest iavf to resolve all funny issue with CNI / SRVIO and bridge mode
# for none DPKD case.
# Note we use arg with default tested version,  caller can overwrite and pass during docker build.

FROM library/photon

ARG NL_VERSION=3.2.25
ENV NL_ENV_VER ${NL_VERSION}
ARG PTP_VERSION=3.1.1
ENV PTP_ENV_VER ${PTP_VERSION}
ARG AVX_VERSION=4.5.3
ENV AVX_ENV_VER ${AVX_VERSION}
ARG KERNEL_VERSION=5.10.118-14.ph4
ENV KERNEL_ENV_VER ${KERNEL_VERSION}
ARG DPDK_VERSION=21.11
ENV DPKD_ENV_VER ${DPDK_VERSION}

# Install tornado library.
RUN tdnf install yum
RUN yum -y install gcc meson git wget numactl make curl \
	python3-pip unzip zip gzip build-essential zlib-devel \
	libbpf-devel libbpf libpcap-devel libpcap libmlx5 libhugetlbfs \
	libhugetlbfs-devel nmap-ncat tcpdump kexec-tools libnuma-devel libnuma \
	nasm linux-drivers-gpu elfutils-libelf-devel vim pciutils iproute \ 
	lshw findutils vim-extra elfutils-devel cmake cython3 python3-docutils \
	dtc dtc-devel pciutils-devel openssl-devel
 

# Stage one we build first ipsec mb lib
WORKDIR /root/
RUN mkdir build
RUN cd build
RUN git clone https://github.com/intel/intel-ipsec-mb.git
WORKDIR intel-ipsec-mb
RUN make
RUN make install
RUN ldconfig

ENV TERM=xterm-256color
RUN yum -y install python3-libcap-ng python3-devel
RUN pip3 install pyelftools sphinx

RUN yum install -y rdma-core-devel util-linux-devel zip zlib zlib-devel \
	libxml2-devel libudev-devel

# libnl we need that for latest rmda-core
WORKDIR /root/build
RUN wget https://www.infradead.org/~tgr/libnl/files/libnl-$NL_ENV_VER.tar.gz
RUN mkdir libnl
RUN tar -zxvf libnl-$NL_ENV_VER.tar.gz -C libnl --strip-components=1 
WORKDIR /root/build/libnl
RUN ./configure --prefix=/usr
RUN make && make install

# rmda-core
WORKDIR /root/build
RUN git clone https://github.com/linux-rdma/rdma-core
WORKDIR /root/build/rdma-core
RUN bash build.sh

# isal lib
WORKDIR /root/build
RUN git clone https://github.com/intel/isa-l
WORKDIR /root/build/isa-l
RUN chmod 700 autogen.sh && ./autogen.sh
RUN ./configure
RUN make && make install

# OFED tool
WORKDIR /root/build 
RUN wget http://www.mellanox.com/downloads/ofed/MLNX_OFED-5.4-1.0.3.0/MLNX_OFED_SRC-debian-5.4-1.0.3.0.tgz --directory-prefix=/root/build -O MLNX_OFED_SRC-debian-5.4-1.0.3.0.tgz 
RUN mkdir mlnx_ofed_src
RUN tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1

# pyelf tools and both normal kernel src and rt
RUN pip3 install pyelftools
RUN yum -y install stalld dkms \
        linux-devel linux-rt-devel
RUN ln -s /usr/src/linux-headers-5.10.118-14.ph4/ /usr/src/linux

# build all modules / including ibverbs, the only missing one for now cuda
WORKDIR /root/build
RUN wget http://fast.dpdk.org/rel/dpdk-$DPKD_ENV_VER.tar.xz
RUN tar xf dpdk*
WORKDIR /root/build/dpdk-$DPKD_ENV_VER
RUN meson -Dplatform=native -Dexamples=all -Denable_kmods=true -Dkernel_dir=/lib/modules/$KERNEL_ENV_VER -Dibverbs_link=shared -Dwerror=true build
RUN ninja -C build
WORKDIR /root/build/dpdk-$DPKD_ENV_VER/build
RUN ninja install
ENV TERM=xterm-256color

# stage pkt-gen
WORKDIR /root/build
RUN git clone http://dpdk.org/git/apps/pktgen-dpdk
WORKDIR /root/build/pktgen-dpdk
RUN export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/; meson build
RUN ninja -C build
RUN ninja -C build install
RUN ldconfig

# build latest linux ptp from source code.
WORKDIR /root/build
RUN wget https://sourceforge.net/projects/linuxptp/files/v3.1/linuxptp-$PTP_ENV_VER.tgz/download --directory-prefix=/root/build -O linuxptp-$PTP_ENV_VER.tgz
RUN mkdir linuxptp 
RUN tar -zxvf linuxptp-* -C linuxptp --strip-components=1
WORKDIR /root/build/linuxptp
RUN make && make install

# latest intel iavf (change link to permanent if needed )
WORKDIR /root/build
RUN wget https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz --directory-prefix=/root/build -O iavf-$AVX_VERSION.tar.gz 
RUN mkdir iavf
RUN tar -zxvf iavf-* -C iavf --strip-components=1
WORKDIR /root/build/iavf/src
RUN make && make install

# tinytkg
RUN yum install -y ebtables ethtool socat conntrack apparmor-profiles rpm-build
# RUN rpm -i http://httpd.mgmt.vmw-nfv.rocks/iso/photon/ztp/tinykube-0.0.1-1.x86_64.rpm
RUN yum -y install iptables

CMD ["ldconfig; /bin/bash"]
