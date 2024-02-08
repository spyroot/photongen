# DPDK 23.11 Photon OS 5.0 Build.

This DPDK 23.11 container is built on Photon OS 5.0 except for CUDA and a few specific libraries; 
it encompasses all PMD and associated libraries, such as XDR, in this build. Additionally, it includes 
DPDK pktgen, DPDK test-pmd, and iperf3 utility and a all respected toolchain tailored for development purposes.

Pktgen is a traffic generator tool designed for testing network performance.

Please note that 'spyroot/dpdk_generic_tester' is compiled with platform-generic code, whereas
'spyroot/dpdk_native_tester' is optimized for the latest 4th and 5th generation Intel processors with AVX support.

DPDK, Intel IPSec, and other libraries are compiled in /root/build. All DPDK lib installed as platform-wide 
and in /usr/llocal/lib

docker hub repo for native build for Intel Gen4/Gen5 [spyroot/dpdk_generic_tester] (https://hub.docker.com/repository/docker/spyroot/dpdk_native_tester/general)
* Main repo for different build [https://github.com/spyroot/photongen] (https://github.com/spyroot/photongen)
* Packet Gen [https://github.com/pktgen/Pktgen-DPDK] (https://github.com/pktgen/Pktgen-DPDK)
* Intel IPSec lib [https://github.com/intel/intel-ipsec-mb] (https://github.com/intel/intel-ipsec-mb)
* XDP [https://github.com/xdp-project/xdp-tools.git] (https://github.com/xdp-project/xdp-tools.git)

THe base os VMware Photon OS 5.0
[Photon OS] (https://github.com/vmware/photon)

## Usage

### Packet Gen

### Devices

```bash
docker run -it --privileged --rm spyroot/dpdk_generic_tester dpdk-devbind.py -s 
Network devices using kernel driver
===================================
0000:03:00.0 'Ethernet Controller X710 for 10GBASE-T 15ff' if= drv=i40e unused=
0000:03:00.1 'Ethernet Controller X710 for 10GBASE-T 15ff' if= drv=i40e unused=
```

### DPDK Packege Gen

```bash
docker run -it --privileged --rm spyroot/dpdk_generic_tester pktgen --help
*** Copyright(c) <2010-2023>, Intel Corporation. All rights reserved.
*** Pktgen  created by: Keith Wiles -- >>> Powered by DPDK <<<
EAL: Detected CPU lcores: 96
EAL: Detected NUMA nodes: 4
```

### DPDK Packet Gen

```bash
docker run -it --privileged --rm spyroot/dpdk_generic_tester dpdk-devbind.py -s
```

### DPDK Test PMD

```bash
docker run -it --privileged --rm spyroot/dpdk_generic_tester dpdk-testpmd
EAL: Detected CPU lcores: 96
EAL: Detected NUMA nodes: 4
EAL: Detected static linkage of DPDK
EAL: Multi-process socket /var/run/dpdk/rte/mp_socket
EAL: Selected IOVA mode 'PA'
```

### Example local docker with hugepages

In this example we use 2k huge pages.

First make sure you have latest driver.

- Download, extract, build, and install i40e
- Download, extract, build, and install iavf
- and verify that we have right version loaded.

This latest driver as for Feb 2024

```bash
export version_i40e="2.24.6"
export version_iavf="4.9.5"

wget "https://downloadmirror.intel.com/812528/i40e-$version_i40e.tar.gz" && \
tar xfz "i40e-$version_i40e.tar.gz" && \
cd "i40e-$version_i40e/src" && \
make && make install

wget "https://downloadmirror.intel.com/812526/iavf-$version_iavf.tar.gz" && \
tar xfz "iavf-$version_iavf.tar.gz" && \
cd "iavf-$version_iavf/src" && \
make && make install

modinfo i40e | grep "$version_i40e"
modinfo iavf | grep "$version_iavf"
```

## Optional step for secure boot and signing kernel modules. 

Please note that the specified path is intended for Ubuntu hosts. 
If you are using a different Linux distribution, ensure you locate the directory where the 
key for signing other kernel modules is stored

* Initially, we sign both modules.
* Verification of the kernel module signature is crucial; otherwise, errors may occur.
* We inspect the dmesg log for signature validation.
* Subsequently, we unload the old driver and load the new kernel modules.
* Please be aware that during loading and unloading, especially if done remotely, there is a risk of disconnection.

```bash
/lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/i40e/i40e.ko
/lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/iavf/iavf.ko

export path_pkey=/var/lib/shim-signed/mok/MOK.priv
export path_der=/var/lib/shim-signed/mok/MOK.der

/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 \
	$path_pkey $path_der /lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/i40e/i40e.ko

/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 \
	$path_pkey $path_der /lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/iavf/iavf.ko

# you should see both module signed

modinfo /lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/i40e/i40e.ko
modinfo /lib/modules/$(uname -r)/updates/drivers/net/ethernet/intel/iavf/iavf.ko

# make sure you see it signed.
dmesg | grep -i signature

# now we can load. load first iavf since i40e might your primary card
# used to ssh to a host
modinfo iavf | grep "$version_iavf" && rmmod -f iavf || true&& modprobe iavf &

# after this command you might lss connection
modinfo i40e | grep "$version_i40e" && rmmod -f i40e || true && modprobe i40e &
```

### Hugepages

This is a very basic setup.

```bash
hpagesize=1024
mkdir -p /dev/hugepages
mountpoint -q /dev/hugepages || mount -t hugetlbfs nodev /dev/hugepages
echo $hpagesize > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
```


In the subsequent step, we begin by selecting the target network adapter and enabling 
8 virtual functions. This ensures that even if you have only one adapter, you can still conduct a basic test.

We then expose the local sysfs and devfs to the target container.

It's important to note that the device and MAC addresses mentioned here are purely for 
illustrative purposes. Additionally, we're utilizing UIO (Userspace I/O) and VFIO_PCI.

In the first scenario, we leverage VFIO_PCI kernel interface. 
Please If the container is running inside a virtual machine, you have the option 
to utilize IOMMU (Input-Output Memory Management Unit) for enhanced performance.

It's worth noting that in this step, we load VFIO_PCI without IO MMU support 
for testing purposes. This approach ensures that you can bind to a VF within 
a container without making any changes to the actual OS. It only 
simply assumes that you have a relatively modern OS with 
VFIO_PCI support.

In follow first scenario we indicate step required for UIO (Userspace I/O).


```bash

export default_device0="/dev/uio0"
export default_adapter="eno1"
export default_peer_mac=$(ip addr show $default_adapter | awk '/ether/{print $2}')
export target_device=$(ethtool -i $default_adapter | awk '/bus-info/{print $2}')
export default_forward_mode="txonly"
export default_img_name="spyroot/dpdk_generic_tester"
export container_name="dpdk_generic_tester"
export default_dev_hugepage="/dev/hugepages"
export default_dpdk_path_bind="/usr/local/bin"
export default_rxq="4"
export default_txq="4"

export default_kmod="vfio-pci"

```

In our example, we are utilizing Virtual Functions (VFs). Therefore, we begin 
by creating 8 VFs on the target adapter. In the example below, the parent adapter PF is named eno1.

We set all VFs to trusted mode and disable spoof check. 
Additionally, we store a VF MAC address and VF local interface name (vf_local_name).

```bash
ip link show $default_adapter
modprobe iavf && for vf_id in {0..7}; do ip link set $default_adapter vf $vf_id trust on && ip link set $default_adapter vf $vf_id spoof off; done
export vf_mac_address=$(ip -d link show eno1 | awk '/vf 0/ {print $4}')
export vf_local_name=$(ifconfig -a | grep -B 1 "$mac_address" | head -n 1 | awk '{print $1}' | sed 's/://')
export vf_target_device=$(ethtool -i $vf_local_name | awk '/bus-info/{print $2}')
echo "VF mac $vf_mac_address, VF ifname $vf_local_name, VF pci addr $vf_target_device"
```

To bind to a DPDK device, either bind to an VF binding or check for an existing binding. 
Note that binding can occur either in the guest OS or inside a container, depending on 
the specific use case and the PMD (Poll Mode Driver) being utilized.

```bash
modprobe $default_kmod && modprobe $default_kmod enable_sriov=1 && \
		docker run --privileged --name "$container_name" --device="/sys/bus/pci/devices/*" \
        -v "$default_dev_hugepage":/dev/hugepages  -v /dev:/dev \
        --cap-add=SYS_RAWIO --cap-add IPC_LOCK \
        --cap-add NET_ADMIN --cap-add SYS_ADMIN \
        --cap-add SYS_NICE \
        --rm \
        -i -t "$default_img_name" dpdk-devbind.py -s
```

This command should output something along this line.  

```bash
0000:03:00.0 'Ethernet Controller X710 for 10GBASE-T 15ff' if= drv=i40e unused=vfio-pci
0000:03:00.1 'Ethernet Controller X710 for 10GBASE-T 15ff' if= drv=i40e unused=vfio-pci
0000:03:02.0 'Ethernet Virtual Function 700 Series 154c' if= drv=iavf unused=vfio-pci
0000:03:02.1 'Ethernet Virtual Function 700 Series 154c' if= drv=iavf unused=vfio-pci
```

This script first ensures that the necessary kernel modules are loaded and SR-IOV is enabled. 
Then it starts a Docker container to bind the VF device, waits for a few seconds, 
prints the current device binding status, stops and removes the Docker 
container, waits again, and finally unbinds the VF device.

```bash
echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode
export vf_target_device="0000:03:02.0"
modprobe $default_kmod && modprobe $default_kmod enable_sriov=1 && \
	    echo "Using device $vf_target_device" && \
		docker run --privileged --name "$container_name" --device="/sys/bus/pci/devices/*" \
        -v "$default_dev_hugepage":/dev/hugepages  -v /dev:/dev \
        --cap-add=SYS_RAWIO --cap-add IPC_LOCK \
        --cap-add NET_ADMIN --cap-add SYS_ADMIN \
        --cap-add SYS_NICE \
        --rm \
        -i -t "$default_img_name" dpdk-devbind.py -b $default_kmod $vf_target_device || true && \
		sleep 2
```

Here we select a numa node we index to 0 element and 
construct NUMA cores list that we later pass to pktgen and test pmd.

Please note you should use bash or sh. 

```bash
export NUMA_NODES=$(numactl --hardware | grep cpus | tr -cd "[:digit:] \n")
[[ -z "$NUMA_NODES" ]] && { echo "Error: numa nodes string empty"; exit 1; }
IFS=", " read -r -a nodelist <<< "$NUMA_NODES"

export numa_node="${nodelist[0]}"
export numa_lcores="${nodelist[@]:1}"
export numa_low_lcore="${nodelist[0]}"
export numa_hi_lcore="${nodelist[-1]}"
export core_range="numa_low_lcore-numa_hi_lcore"
echo "numa_node: $numa_node, numa_lcores: $numa_lcores, numa_low_lcore: $numa_low_lcore, numa_hi_lcore: $numa_hi_lcore"
```

Notice in this example we use all core so be careful.

```bash
echo "cores $numa_low_lcore-$numa_hi_lcore"
cores 0-59
```

Now, we can run pktgen with specific arguments.  In this command:
We first bind  to our target VF and start pktgen

Note: core_range represents the range of cores we'll utilize for 
example, core_range="0-1" is computed in the previous step.

  * -l "$numa_low_lcore-$numa_hi_lcore" specifies the CPU cores to be used.
  * --proc-type auto sets the process type to auto-detect.
  * --log-level 7 sets the log level to 7 (debug).
  * --file-prefix pg specifies the file prefix for log files.
  * -T enables timestamping.
  * --crc-strip enables CRC stripping.

```bash
modprobe $default_kmod && modprobe $default_kmod enable_sriov=1 && \
	    echo "Using device $vf_target_device" && \
		docker run --privileged --name "$container_name" --device="/sys/bus/pci/devices/*" \
        -v "$default_dev_hugepage":/dev/hugepages  -v /dev:/dev \
        --cap-add=SYS_RAWIO --cap-add IPC_LOCK \
        --cap-add NET_ADMIN --cap-add SYS_ADMIN \
        --cap-add SYS_NICE \
        --rm \
        -i -t "$default_img_name" /bin/bash -c \
		"dpdk-devbind.py -b '$default_kmod' '$vf_target_device' || true && sleep 2
		pktgen -l '$core_range' \
		--proc-type auto --log-level 7 \
		--file-prefix pg -- -T --crc-strip"
```

### Example of test PMD

We can also execute test-pmd

  * -l "$numa_low_lcore-$numa_hi_lcore" specifies the CPU cores to be used.
  * -n 4 specifies the number of memory channels.
  * -- separates EAL arguments from testpmd arguments.
  * --port-topology=loop specifies the port topology.
  * --forward-mode=$default_forward_mode specifies the forwarding mode.
  * --txq=$default_txq specifies the number of TX queues.
  * --rxq=$default_rxq specifies the number of RX queues.
  * -i enables interactive mode.
  * -w specifies the port mask to use.

```bash
modprobe $default_kmod && modprobe $default_kmod enable_sriov=1 && \
 echo "Using device $vf_target_device" && \
	docker run --privileged --name "$container_name" --device="/sys/bus/pci/devices/*" \
	-v "$default_dev_hugepage":/dev/hugepages  \
	--cap-add=SYS_RAWIO --cap-add IPC_LOCK \
	--cap-add NET_ADMIN --cap-add SYS_ADMIN \
	--cap-add SYS_NICE \
	--rm \
	-i -t $default_img_name /bin/bash -c \
	"dpdk-devbind.py -b '$default_kmod' '$vf_target_device' || true && sleep 2 && dpdk-testpmd -l '$core_range' -n 4 --  --port-topology=loop --forward-mode='$default_forward_mode' --txq='$default_txq' --rxq='$default_rxq' --interactive"
```


### Kubernetes

Example of kubernetes POD

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dpdkpod
  labels:
    environment: dpdk_tester
    app: dpdkpod
spec:
  replicas: 2
  selector:
    matchLabels:
      environment: dpdk_tester
      app: dpdkpod
  template:
    metadata:
      labels:
        environment: dpdk_tester
        app: dpdkpod
    spec:
      containers:
      - name: dpdkpod
        command: ["/bin/bash", "-c", "PID=; trap 'kill $PID' TERM INT; sleep infinity & PID=$!; wait $PID"]
        image: spyroot/dpdk_generic_tester
        imagePullPolicy: Always
        securityContext:
          capabilities:
            add: ["IPC_LOCK", "NET_ADMIN", "SYS_TIME", "CAP_NET_RAW", "CAP_BPF", "CAP_SYS_ADMIN", "SYS_ADMIN"]
          privileged: true
        env:
          - name: PATH
            value: "/bin:/sbin:/usr/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:$PATH"
        volumeMounts:
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: modules
          mountPath: /lib/modules
          readOnly: true
        resources:
          requests:
            memory: 2Gi
            cpu: "2"
            intel.com/sriovdpdk: '1'
          limits:
            hugepages-1Gi: 2Gi
            cpu: "2"
            intel.com/sriovdpdk: '1'
      volumes:
      - name: sys
        hostPath:
          path: /sys
      - name: modules
        hostPath:
          path: /lib/modules
      nodeSelector:
        kubernetes.io/os: linux
```

List of drives and PMD enabled.


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

```

### PMD Drivers

```
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

## For Developers

Note if you are building or developing custom application outside of the DPDK sample 
make sure to use pkg-config.

```bash
ls /usr/local/lib/pkgconfig/
libdpdk-libs.pc  libdpdk.pc  libxdp.pc
```

```bash
PKGCONF = pkg-config

CFLAGS += -O3 $(shell $(PKGCONF) --cflags libdpdk)
LDFLAGS += $(shell $(PKGCONF) --libs libdpdk)

$(APP): $(SRCS-y) Makefile
        $(CC) $(CFLAGS) $(SRCS-y) -o $@ $(LDFLAGS)
```
 
 All example are in /usr/local/share/dpdk/examples/

```
docker run -it --privileged --rm spyroot/dpdk_generic_tester /bin/bash
```

```
root [ ~/build/pktgen-dpdk ]# ls /usr/local/share/dpdk/examples/
bbdev_app  distributor        flow_filtering    ipsec-secgw     l2fwd-event      l3fwd-graph            packet_ordering  rxtx_callbacks   vdpa              vmdq
bond       dma                helloworld        ipv4_multicast  l2fwd-jobstats   l3fwd-power            pipeline         server_node_efd  vhost             vmdq_dcb
bpf        ethtool            ip_fragmentation  l2fwd           l2fwd-keepalive  link_status_interrupt  ptpclient        service_cores    vhost_blk
cmdline    eventdev_pipeline  ip_pipeline       l2fwd-cat       l2fwd-macsec     multi_process          qos_meter        skeleton         vhost_crypto
common     fips_validation    ip_reassembly     l2fwd-crypto    l3fwd            ntb                    qos_sched        timer            vm_power_manager
```

### Build example

```
root [ ~/build/pktgen-dpdk ]# ls /usr/local/share/dpdk/examples//l2fwd
Makefile  main.c
root [ ~/build/pktgen-dpdk ]# make
>>> Use 'make help' for more commands\n
./tools/pktgen-build.sh build
>>  SDK Path          : /root/build
>>  Install Path      : /root/build/pktgen-dpdk
>>  Build Directory   : /root/build/pktgen-dpdk/Builddir
>>  Target Directory  : usr/local
>>  Build Path        : /root/build/pktgen-dpdk/Builddir
>>  Target Path       : /root/build/pktgen-dpdk/usr/local

 Build and install values:
   lua_enabled       : -Denable_lua=false
   gui_enabled       : -Denable_gui=false

>>> Ninja build in '/root/build/pktgen-dpdk/Builddir' buildtype=release
meson setup -Dbuildtype=release -Denable_lua=false -Denable_gui=false /root/build/pktgen-dpdk/Builddir
The Meson build system
Version: 1.0.0
Source dir: /root/build/pktgen-dpdk
Build dir: /root/build/pktgen-dpdk/Builddir
Build type: native build
Program cat found: YES (/bin/cat)
Project name: pktgen
Project version: 23.06.1
C compiler for the host machine: cc (gcc 12.2.0 "cc (GCC) 12.2.0")
C linker for the host machine: cc ld.bfd 2.39
Host machine cpu family: x86_64
Host machine cpu: x86_64
Compiler for C supports arguments -mavx: YES
Compiler for C supports arguments -mavx2: YES
Compiler for C supports arguments -Wno-pedantic: YES
Compiler for C supports arguments -Wno-format-truncation: YES
Found pkg-config: /bin/pkg-config (0.29.2)
Run-time dependency libdpdk found: YES 23.11.0
WARNING: find_library('librte_net_bond') starting in "lib" only works by accident and is not portable
Library librte_net_bond found: YES
Program python3 found: YES (/usr/bin/python3)
Library rte_net_i40e found: YES
Library rte_net_ixgbe found: YES
Library rte_net_ice found: YES
Library rte_bus_vdev found: YES
Run-time dependency threads found: YES
Library numa found: YES
Library pcap found: YES
Library dl found: YES
Library m found: YES
Program doxygen found: YES (/bin/doxygen)
Program generate_doxygen.sh found: YES (/root/build/pktgen-dpdk/doc/api/generate_doxygen.sh)
Program generate_examples.sh found: YES (/root/build/pktgen-dpdk/doc/api/generate_examples.sh)
Program doxy-html-custom.sh found: YES (/root/build/pktgen-dpdk/doc/api/doxy-html-custom.sh)
Configuring doxy-api.conf using configuration
Program sphinx-build found: YES (/bin/sphinx-build)
Build targets in project: 12
NOTICE: Future-deprecated features used:
 * 0.56.0: {'meson.build_root', 'meson.source_root'}

pktgen 23.06.1

  User defined options
    buildtype : release
    enable_gui: false
    enable_lua: false

Found ninja-1.11.1 at /bin/ninja
ninja: Entering directory `/root/build/pktgen-dpdk/Builddir'
[69/69] Linking target app/pktgen
>>> Ninja install to '/root/build/pktgen-dpdk/usr/local'
ninja: Entering directory `/root/build/pktgen-dpdk/Builddir'
[0/1] Installing files.
Installing app/pktgen to /root/build/pktgen-dpdk/usr/local/bin
Installing /root/build/pktgen-dpdk/doc/source/custom.css to /root/build/pktgen-dpdk/usr/local/share/doc/dpdk/_static/css
```

 ### DPDK tools in /usr/local/bin

 ```bash
 ls /usr/local/bin
dpdk-cmdline-gen.py  dpdk-hugepages.py  dpdk-rss-flows.py  dpdk-test-bbdev          dpdk-test-dma-perf   dpdk-test-gpudev    dpdk-test-sad            pktgen    rdtset
dpdk-devbind.py      dpdk-pdump         dpdk-telemetry.py  dpdk-test-cmdline        dpdk-test-eventdev   dpdk-test-mldev     dpdk-test-security-perf  pqos
dpdk-dumpcap         dpdk-pmdinfo.py    dpdk-test          dpdk-test-compress-perf  dpdk-test-fib        dpdk-test-pipeline  dpdk-testpmd             pqos-msr
dpdk-graph           dpdk-proc-info     dpdk-test-acl      dpdk-test-crypto-perf    dpdk-test-flow-perf  dpdk-test-regex     membw                    pqos-os
```
