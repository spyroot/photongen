# DPDK 23.11 Photon OS 5.0 Build.

This DPDK 23.11 container is built on Photon OS 5.0 except for CUDA and a few specific libraries; it encompasses all PMD 
and associated libraries, such as XDR, in this build. Additionally, it includes pktgen, 
test-pmd, and iperf3 utility and a toolchain tailored for development purposes.

Please note that 'spyroot/dpdk_generic_tester' is compiled with platform-generic code, whereas
'spyroot/dpdk_native_tester' is optimized for the latest 4th and 5th generation Intel processors with AVX support.

DPDK, Intel IPSec, and other libraries are compiled in /root/build. All DPKD lib installed as platform-wide 
and in /usr/llocal/lib.

## Usage
```
docker run -it --privileged --rm spyroot/dpdk_generic_tester pktgen --help


*** Copyright(c) <2010-2023>, Intel Corporation. All rights reserved.
*** Pktgen  created by: Keith Wiles -- >>> Powered by DPDK <<<

EAL: Detected CPU lcores: 96
EAL: Detected NUMA nodes: 4
```

List of drives and PMD enabled.

```

## Driver and PMD.

```
libs:
 	log, kvargs, telemetry, eal, ring, rcu, mempool, mbuf,
 	net, meter, ethdev, pci, cmdline, metrics, hash, timer,
 	acl, bbdev, bitratestats, bpf, cfgfile, compressdev, cryptodev, distributor,
 	dmadev, efd, eventdev, dispatcher, gpudev, gro, gso, ip_frag,
 	jobstats, latencystats, lpm, member, pcapng, power, rawdev, regexdev,
 	mldev, rib, reorder, sched, security, stack, vhost, ipsec,
 	pdcp, fib, port, pdump, table, pipeline, graph, node,



 common:
 	cpt, dpaax, iavf, idpf, octeontx, cnxk, mlx5, nfp,
 	qat, sfc_efx,
 bus:
 	auxiliary, cdx, dpaa, fslmc, ifpga, pci, platform, vdev,
 	vmbus,
 mempool:
 	bucket, cnxk, dpaa, dpaa2, octeontx, ring, stack,
 dma:
 	cnxk, dpaa, dpaa2, hisilicon, idxd, ioat, skeleton,
 net:
 	af_packet, af_xdp, ark, atlantic, avp, axgbe, bnx2x, bnxt,
 	bond, cnxk, cpfl, cxgbe, dpaa, dpaa2, e1000, ena,
 	enetc, enetfec, enic, failsafe, fm10k, gve, hinic, hns3,
 	i40e, iavf, ice, idpf, igc, ionic, ipn3ke, ixgbe,
 	memif, mlx4, mlx5, netvsc, nfp, ngbe, null, octeontx,
 	octeon_ep, pcap, pfe, qede, ring, sfc, softnic, tap,
 	thunderx, txgbe, vdev_netvsc, vhost, virtio, vmxnet3,
 raw:
 	cnxk_bphy, cnxk_gpio, dpaa2_cmdif, ifpga, ntb, skeleton,
 crypto:
 	bcmfs, caam_jr, ccp, cnxk, dpaa_sec, dpaa2_sec, ipsec_mb, mlx5,
 	nitrox, null, octeontx, openssl, scheduler, virtio,
 compress:
 	isal, mlx5, octeontx, zlib,
 regex:
 	mlx5, cn9k,
 ml:
 	cnxk,
 vdpa:
 	ifc, mlx5, nfp, sfc,
 event:
 	cnxk, dlb2, dpaa, dpaa2, dsw, opdl, skeleton, sw,
 	octeontx,
 baseband:
 	acc, fpga_5gnr_fec, fpga_lte_fec, la12xx, null, turbo_sw,
 gpu:
```

Note if you are building or developing custom application outside of the DPDK sample 
make sure to use pkg-config.

```
PKGCONF = pkg-config

CFLAGS += -O3 $(shell $(PKGCONF) --cflags libdpdk)
LDFLAGS += $(shell $(PKGCONF) --libs libdpdk)

$(APP): $(SRCS-y) Makefile
        $(CC) $(CFLAGS) $(SRCS-y) -o $@ $(LDFLAGS)
```
 
