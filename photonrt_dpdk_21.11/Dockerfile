# Author Mustafa Bayramov 
FROM library/photon

# Install tornado library.
RUN tdnf install yum
RUN yum -y install gcc meson git wget numactl make curl \
	python3-pip unzip zip gzip build-essential zlib-devel \
	libbpf-devel libbpf libpcap-devel libpcap libmlx5 libhugetlbfs \
	libhugetlbfs-devel nmap-ncat tcpdump kexec-tools libnuma-devel libnuma \
	nasm linux-drivers-gpu elfutils-libelf-devel vim pciutils iproute \ 
	lshw findutils vim-extra elfutils-devel
 

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

WORKDIR /root/build
RUN wget http://fast.dpdk.org/rel/dpdk-21.11.tar.xz
RUN tar xf dpdk*
WORKDIR /root/build/dpdk-21.11
RUN meson -Dexamples=all build
RUN ninja -C build
WORKDIR /root/build/dpdk-21.11/build
RUN ninja install

RUN pip3 install tensorflow-gpu

ENV TERM=xterm-256color

# Last stage pkt-gen
WORKDIR /root/build
RUN git clone http://dpdk.org/git/apps/pktgen-dpdk
WORKDIR /root/build/pktgen-dpdk
RUN export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/; meson build
RUN ninja -C build
RUN ninja -C build install
RUN ldconfig

CMD ["ldconfig; /bin/bash"]
