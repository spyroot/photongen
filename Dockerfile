# Author Mustafa Bayramov 
FROM library/photon

# Install tornado library.
RUN tdnf install yum
RUN yum -y install gcc meson git wget numactl make curl python3-pip unzip zip gzip build-essential zlib-devel libbpf-devel libbpf libpcap-devel libpcap libmlx5 libhugetlbfs libhu
getlbfs-devel ansible nmap-ncat tcpdump kexec-tools libnuma-devel libnuma nasm linux-drivers-gpu elfutils-libelf-devel

# Stage one we build first ipsec mb lib
WORKDIR /root/
RUN mkdir build
RUN cd build
RUN git clone https://github.com/intel/intel-ipsec-mb.git
WORKDIR intel-ipsec-mb
RUN make
RUN make install
RUN ldconfig

# Stage two we build DPKD LTS
WORKDIR /root/build
RUN wget http://fast.dpdk.org/rel/dpdk-20.11.3.tar.xz
RUN tar xf dpdk*
WORKDIR /root/build/dpdk-stable-20.11.3
RUN meson -Dexamples=all build
RUN ninja -C build
WORKDIR /root/build/dpdk-stable-20.11.3/build
RUN ninja install

# Stage three we build rt cyclictest and other tools from kernel.org 
WORKDIR /root/build
RUN git clone git://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
WORKDIR /root/build/rt-tests
RUN make
RUN make install

# Sphix and TF2 gpu 
RUN pip3 install tensorflow-gpu
RUN pip3 install sphinx

# Last stage pkt-gen
WORKDIR /root/build
RUN git clone http://dpdk.org/git/apps/pktgen-dpdk
WORKDIR /root/build/pktgen-dpdk
RUN export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/; meson build
RUN ninja -C build
RUN ninja -C build install
RUN ldconfig

CMD ["ldconfig; /bin/bash"]
