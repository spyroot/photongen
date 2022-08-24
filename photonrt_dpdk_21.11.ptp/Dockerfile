# Author Mustafa Bayramov 
# First pull all low level lib for intel ipsec
# Pull all libs and build required for Mellanox , external plus rdma-core
# Pull isal ( bpf / pcap all in yum , hence no need build anything )
# OFED has all src for Mellanox distro.

FROM library/photon

ARG NL_VERSION=3.2.25
ENV NL_ENV_VER ${NL_VERSION}

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

# libnl for rmda-core
WORKDIR /root/build
RUN wget https://www.infradead.org/~tgr/libnl/files/libnl-NL_ENV_VER.tar.gz
RUN mkdir libnl
RUN tar -zxvf libnl-NL_ENV_VER.tar.gz -C libnl --strip-components=1 
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
RUN pip3 install pyelftools

#kernel_ver=$(uname -r)
#meson -Dplatform=native -Dexamples=all -Denable_kmods=true \
#    -Dkernel_dir=/lib/modules/"$kernel_ver" \
#    -Dibverbs_link=shared -Dwerror=true build
#ninja -C build install

RUN yum -y install stalld dkms \
        linux-devel linux-rt-devel
RUN ln -s /usr/src/linux-headers-5.10.118-14.ph4/ /usr/src/linux

WORKDIR /root/build
RUN wget http://fast.dpdk.org/rel/dpdk-21.11.tar.xz
RUN tar xf dpdk*
WORKDIR /root/build/dpdk-21.11
RUN meson -Dplatform=native -Dexamples=all -Denable_kmods=true -Dkernel_dir=/lib/modules/5.10.118-14.ph4 -Dibverbs_link=shared -Dwerror=true build 
RUN ninja -C build
WORKDIR /root/build/dpdk-21.11/build
RUN ninja install
ENV TERM=xterm-256color

# Last stage pkt-gen
WORKDIR /root/build
RUN git clone http://dpdk.org/git/apps/pktgen-dpdk
WORKDIR /root/build/pktgen-dpdk
RUN export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/; meson build
RUN ninja -C build
RUN ninja -C build install
RUN ldconfig

# latest PTP
WORKDIR /root/build
RUN wget https://sourceforge.net/projects/linuxptp/files/v3.1/linuxptp-3.1.1.tgz/download --directory-prefix=/root/build -O linuxptp-3.1.1.tgz
RUN mkdir linuxptp 
RUN tar -zxvf linuxptp-* -C linuxptp --strip-components=1
WORKDIR /root/build/linuxptp
RUN make && make install

# latest iavf
WORKDIR /root/build
RUN wget https://downloadmirror.intel.com/738727/iavf-4.5.3.tar.gz --directory-prefix=/root/build -O iavf-4.5.3.tar.gz 
RUN mkdir iavf
RUN tar -zxvf iavf-* -C iavf --strip-components=1
WORKDIR /root/build/iavf/src
RUN make && make install

CMD ["ldconfig; /bin/bash"]
