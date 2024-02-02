# Author Mustafa Bayramov 

# Outside of cuda and some very specific lib all libs / PMD / XDR etc included.

# =================
# Applications Enabled
# =================

# apps:
# 	dumpcap, graph, pdump, proc-info, test-acl, test-bbdev, test-cmdline, test-compress-perf,
# 	test-crypto-perf, test-dma-perf, test-eventdev, test-fib, test-flow-perf, test-gpudev, 
#   test-mldev, test-pipeline,
# 	test-pmd, test-regex, test-sad, test-security-perf, test,

# Message:
# =================
# Libraries Enabled
# =================

# libs:
# 	log, kvargs, telemetry, eal, ring, rcu, mempool, mbuf,
# 	net, meter, ethdev, pci, cmdline, metrics, hash, timer,
# 	acl, bbdev, bitratestats, bpf, cfgfile, compressdev, cryptodev, distributor,
# 	dmadev, efd, eventdev, dispatcher, gpudev, gro, gso, ip_frag,
# 	jobstats, latencystats, lpm, member, pcapng, power, rawdev, regexdev,
# 	mldev, rib, reorder, sched, security, stack, vhost, ipsec,
# 	pdcp, fib, port, pdump, table, pipeline, graph, node,


# Message:
# ===============
# Drivers Enabled
# ===============

# common:
# 	cpt, dpaax, iavf, idpf, octeontx, cnxk, mlx5, nfp,
# 	qat, sfc_efx,
# bus:
# 	auxiliary, cdx, dpaa, fslmc, ifpga, pci, platform, vdev,
# 	vmbus,
# mempool:
# 	bucket, cnxk, dpaa, dpaa2, octeontx, ring, stack,
# dma:
# 	cnxk, dpaa, dpaa2, hisilicon, idxd, ioat, skeleton,
# net:
# 	af_packet, af_xdp, ark, atlantic, avp, axgbe, bnx2x, bnxt,
# 	bond, cnxk, cpfl, cxgbe, dpaa, dpaa2, e1000, ena,
# 	enetc, enetfec, enic, failsafe, fm10k, gve, hinic, hns3,
# 	i40e, iavf, ice, idpf, igc, ionic, ipn3ke, ixgbe,
# 	memif, mlx4, mlx5, netvsc, nfp, ngbe, null, octeontx,
# 	octeon_ep, pcap, pfe, qede, ring, sfc, softnic, tap,
# 	thunderx, txgbe, vdev_netvsc, vhost, virtio, vmxnet3,
# raw:
# 	cnxk_bphy, cnxk_gpio, dpaa2_cmdif, ifpga, ntb, skeleton,
# crypto:
# 	bcmfs, caam_jr, ccp, cnxk, dpaa_sec, dpaa2_sec, ipsec_mb, mlx5,
# 	nitrox, null, octeontx, openssl, scheduler, virtio,
# compress:
# 	isal, mlx5, octeontx, zlib,
# regex:
# 	mlx5, cn9k,
# ml:
# 	cnxk,
# vdpa:
# 	ifc, mlx5, nfp, sfc,
# event:
# 	cnxk, dlb2, dpaa, dpaa2, dsw, opdl, skeleton, sw,
# 	octeontx,
# baseband:
# 	acc, fpga_5gnr_fec, fpga_lte_fec, la12xx, null, turbo_sw,
# gpu:


# Message:
# =================
# Content Skipped
# =================

# apps:

# libs:

# drivers:
# 	common/mvep:	missing dependency, "libmusdk"
# 	net/mana:	missing dependency, "mana"
# 	net/mvneta:	missing dependency, "libmusdk"
# 	net/mvpp2:	missing dependency, "libmusdk"
# 	net/nfb:	missing dependency, "libnfb"
# 	crypto/armv8:	missing dependency, "libAArch64crypto"
# 	crypto/mvsam:	missing dependency, "libmusdk"
# 	crypto/uadk:	missing dependency, "libwd"
# 	gpu/cuda:	missing dependency, "cuda.h"

FROM library/photon

# Install library.
RUN tdnf install yum
RUN tdnf makecache
RUN yum update -y
RUN yum install -y gcc meson git wget numactl make curl \
	python3-pip unzip zip gzip build-essential zlib-devel \
	libbpf-devel libbpf libpcap-devel libpcap libmlx5 libhugetlbfs \
	libhugetlbfs-devel nmap-ncat tcpdump kexec-tools libnuma-devel libnuma \
	nasm linux-drivers-gpu elfutils-libelf-devel vim pciutils iproute \ 
	cmake yum libibverbs-devel \
	lshw glibc-tools glibc-devel glibc-libs json-glib json-glib-devel \
	libgcrypt-devel jansson-devel openssl-devel libarchive-devel libarchive \
	findutils vim-extra elfutils-devel dtc dtc-devel doxygen \
	libbpf libbpf-devel bpftool
 

# Stage one we build first ipsec mb lib
WORKDIR /root/
RUN mkdir build
RUN cd build
RUN git clone https://github.com/intel/intel-ipsec-mb.git && \
	cd intel-ipsec-mb && \
	make -j 32 && make install
RUN ldconfig

# we pull clang after due some issue in ipsec-mb
RUN yum install -y clang clang-devel

ENV TERM=xterm-256color
RUN yum -y install python3-libcap-ng python3-devel
RUN pip3 install pyelftools sphinx

WORKDIR /root/build
RUN git clone https://github.com/intel/isa-l.git && \
    cd isa-l && \
    ./autogen.sh && \
    ./configure --prefix=/usr --libdir=/usr/lib64 && \
    make -j 32 && \
    make install

RUN git clone --recursive https://github.com/xdp-project/xdp-tools.git && \
    cd xdp-tools && \
    ./configure && \
    make -j 32 && \
    make install

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
WORKDIR /root/build
RUN git clone https://github.com/intel/intel-cmt-cat.git && \
    cd intel-cmt-cat && \
    make -j 32 && \
    make install

RUN ldconfig
RUN wget http://fast.dpdk.org/rel/dpdk-23.11.tar.xz
RUN tar xf dpdk*
WORKDIR /root/build/dpdk-23.11
RUN meson -Dexamples=all build
RUN ninja -C build -j 32
WORKDIR /root/build/dpdk-23.11/build
RUN ninja install

ENV TERM=xterm-256color

# Last stage pkt-gen
WORKDIR /root/build
RUN git clone http://dpdk.org/git/apps/pktgen-dpdk
WORKDIR /root/build/pktgen-dpdk
COPY mus_pktgen_dpdk23.11.patch .
RUN patch -p1 < mus_pktgen_dpdk23.11.patch
RUN export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/; meson build
RUN ninja -C build
RUN ninja -C build install
RUN ldconfig

CMD ["ldconfig; /bin/bash"]
