#!/bin/bash
# This is post install script.  This must happened
# after first post install.
# The goal here
# - build mellanox driver and Intel driver.
# - link to current kernel src.
# - build all DPKD kmod and install. (including UIO)
# - build all libs required for DPDK Crypto.
# - build IPSec libs required for vdev DPDK.
# - build CUDA (optional)
# - install all as shared libs.
# - make sure vfio latest.
# - enable vfio and vfio-pci.
# - enable SRIOV on target network adapter.(must be UP)
#    - For now it just one. TODO do a loop and do it for list
# - enable huge pages for single socket or dual socket.
# - enable PTP
# - set VF to trusted mode and disable spoof check.
# - automatically generate tuned profile , load.
# spyroot@gmail.com
# Author Mustafa Bayramov

AVX_VERSION=4.5.3
MLNX_VER=5.4-1.0.3.0
DOCKER_IMAGE_PATH="/vcu1.tar.gz"

# what we are building
MLX_BUILD=yes
INTEL_BUILD=yes
DPDK_BUILD=yes
IPSEC_BUILD=yes
LIBNL_BUILD=yes
LIBNL_ISA=yes
LOAD_DOCKER_IMAGE=yes
TUNED_BUILD=yes
BUILD_SRIOV=yes
BUILD_HUGEPAGES=yes
BUILD_PTP=yes

# SRIOV NIC make sure it up.
SRIOV_NIC="eth6"
SRIOV_PCI="pci@0000:8a:00.0"
# number of VFS we need.
NUM_VFS=8

# num huge pages for 2k and 1Gbe
# make sure this number is same or less than what I do for mus_rt profile.
# i.e cross-check /proc/cmdline if you need more adjust config at the bottom.
PAGES="2048"
PAGES_1GB="8"

# all links and dirs
DPDK_URL_LOCATION="http://fast.dpdk.org/rel/dpdk-21.11.tar.xz"
IPSEC_LIB_LOCATION="https://github.com/intel/intel-ipsec-mb.git"
NL_LIB_LOCATION="https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz"
DPDK_TARGET_DIR_BUILD="/root/dpdk-21.11"
LIB_NL_TARGET_DIR_BUILD="/root/build/libnl"
LIB_ISAL_TARGET_DIR_BUILD="/root/build/isa-l"

# DRIVER TMP DIR where we are building.
MLX_DIR=/tmp/mlnx_ofed_src
INTEL_DIR=/tmp/iavf

export PATH="$PATH":/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

mkdir -p $MLX_DIR
mkdir -p $INTEL_DIR

if [ -z "$LOAD_DOCKER_IMAGE" ]
then
    echo "Skipping docker load phase."
else
  systemctl enable docker; systemctl start docker
  is_docker_running=$(systemctl status docker | grep running)
  if [ -z "$is_docker_running" ]
  then
    echo "Skipping docker load since it down."
  else
    docker load < $DOCKER_IMAGE_PATH > /docker_load.log
  fi
fi

export PATH=$PATH:/usr/local/bin
yum --quiet -y install python3-libcap-ng python3-devel rdma-core-devel util-linux-devel \
zip zlib zlib-devel libxml2-devel libudev-devel > /rpms_pull_build.log

if [ -z "$IPSEC_BUILD" ]
then
    echo "Skipping ipsec lib build."
else
  cd /root || exit; mkdir -p build; git clone $IPSEC_LIB_LOCATION > /ipsec_clone.log
  cd intel-ipsec-mb || exit; make -j 8 > /ipsec_build.log
  make install > ipsec_install.log; ldconfig
fi

if [ -z "$MLX_BUILD" ]
then
    echo "Skipping Mellanox driver build."
else
  MLX_IMG=http://www.mellanox.com/downloads/ofed/MLNX_OFED-"$MLNX_VER"/MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  MLX_FILE_NAME=MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  cd /tmp || exit; wget --quiet $MLX_IMG --directory-prefix=$MLX_DIR -O $MLX_FILE_NAME
  tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1 > /mlx_driver_install.log
fi

if [ -z "$INTEL_BUILD" ]
then
    echo "Skipping intel driver build"
else
  INTEL_IMG=https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz
  cd /tmp || exit; wget --quiet $INTEL_IMG --directory-prefix=$INTEL_DIR -O iavf-$AVX_VERSION.tar.gz
  tar -zxvf iavf-* -C iavf --strip-components=1
  cd $INTEL_DIR/src || exit; make && make install  > /intel_driver_install.log
fi

# we add shared lib to ld.so.conf
SHARED_LIB_LINE='/usr/local/lib'
SHARED_LD_FILE='/etc/ld.so.conf'
grep -qF -- "$SHARED_LIB_LINE" "$SHARED_LD_FILE" || echo "$SHARED_LIB_LINE" >> "$SHARED_LD_FILE"
ldconfig

pip3 install -U pyelftools sphinx

# build and install libnl
if [ -z "$LIBNL_BUILD" ]
then
    echo "Skipping libnl driver build"
else
  rm -rf $LIB_NL_TARGET_DIR_BUILD; cd /root/build || exit; wget --quiet $NL_LIB_LOCATION
  mkdir libnl || exit; tar -zxvf libnl-*.tar.gz -C libnl --strip-components=1
  cd $LIB_NL_TARGET_DIR_BUILD || exit; ./configure --prefix=/usr; make -j 8 && make install > /build_install_nl.log
  ldconfig; ldconfig /usr/local/lib
fi

# build and install isa
if [ -z "$LIBNL_ISA" ]
then
    echo "Skipping isa-l driver build"
else
  rm -rf $LIB_ISAL_TARGET_DIR_BUILD > /build_isa.log
  cd /root/build || exit; git clone https://github.com/intel/isa-l
  cd $LIB_ISAL_TARGET_DIR_BUILD || exit; chmod 700 autogen.sh && ./autogen.sh; ./configure; make -j 8 > /build_isa.log && make install > /build_install_isa.log
  ldconfig; ldconfig /usr/local/lib

fi

# kernel source and DPDK, we're building with Intel and Mellanox driver.
yum --quiet -y install stalld dkms linux-devel linux-rt-devel openssl-devel libmlx5 > /yum_kernel_build.log

if [ -z "$DPDK_BUILD" ]
then
    echo "Skipping DPDK build."
else
  pip3 install pyelftools sphinx > /pip_install.log
  ln -s /usr/src/linux-headers-$(uname -r)/ /usr/src/linux 2>/dev/null
  rm $DPDK_TARGET_DIR_BUILD 2>/dev/null
  cd /root || exit; wget --quiet -nc -O dpdk.tar.gz $DPDK_URL_LOCATION; tar xf dpdk.tar.gz > /dpkd_pull.log
  ldconfig
  cd $DPDK_TARGET_DIR_BUILD || exit; meson -Dplatform=native -Dexamples=all -Denable_kmods=true \
  -Dkernel_dir=/lib/modules/$(uname -r) -Dibverbs_link=shared -Dwerror=true build; ninja -C build -j 8 > /dpkd_build.log
  cd $DPDK_TARGET_DIR_BUILD/build || exit; ninja install > /dpkd_install.log; ldconfig;   ldconfig /usr/local/lib
fi

# adjust config and load VFIO
VFIO_KMOD_FILE="/etc/modules-load.d/vfio-pci.conf"
mkdir -p /etc/modules-load.d 2>/dev/null
if [[ ! -e $VFIO_KMOD_FILE ]]; then
    touch VFIO_KMOD_FILE
fi

export PATH="$PATH":/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
MODULES_VFIO_PCI_LINE='/etc/modules-load.d/vfio-pci.conf'
MODULES_VFIO_PCI_FILE='vfio-pci'
grep -qF -- "$MODULES_VFIO_PCI_LINE" "$MODULES_VFIO_PCI_FILE" || echo "$MODULES_VFIO_PCI_LINE" >> "$MODULES_VFIO_PCI_FILE"

MODULES_VFIO_LINE='/etc/modules-load.d/vfio.conf'
MODULES_VFIO_FILE='vfio'
grep -qF -- "$MODULES_VFIO_LINE" "$MODULES_VFIO_FILE" || echo "$MODULES_VFIO_LINE" >> "$MODULES_VFIO_FILE"

#### create tuned profile.
if [ -z "$TUNED_BUILD" ]; then
    echo "Skipping tuned optimization."
else
mkdir -p /usr/lib/tuned/mus_rt 2>/dev/null

# create vars
cat > /etc/tuned/realtime-variables.conf << 'EOF'
isolated_cores=${f:calc_isolated_cores:2}
isolate_managed_irq=Y
EOF

# create profile
touch /usr/lib/tuned/mus_rt/tuned.conf
cat > /usr/lib/tuned/mus_rt/tuned.conf << 'EOF'
[main]
summary=Optimize for realtime workloads
include = network-latency
[variables]
include = /etc/tuned/realtime-variables.conf
isolated_cores_assert_check = \\${isolated_cores}
isolated_cores = ${isolated_cores}
not_isolated_cpumask = ${f:cpulist2hex_invert:${isolated_cores}}
isolated_cores_expanded=${f:cpulist_unpack:${isolated_cores}}
isolated_cpumask=${f:cpulist2hex:${isolated_cores_expanded}}
isolated_cores_online_expanded=${f:cpulist_online:${isolated_cores}}
isolate_managed_irq = ${isolate_managed_irq}
managed_irq=${f:regex_search_ternary:${isolate_managed_irq}:\b[y,Y,1,t,T]\b:managed_irq,domain,:}
[net]
channels=combined ${f:check_net_queue_count:${netdev_queue_count}}
[sysctl]
kernel.hung_task_timeout_secs = 600
kernel.nmi_watchdog = 0
kernel.sched_rt_runtime_us = -1
vm.stat_interval = 10
kernel.timer_migration = 0
net.ipv4.conf.all.rp_filter=2
[sysfs]
/sys/bus/workqueue/devices/writeback/cpumask = ${not_isolated_cpumask}
/sys/devices/virtual/workqueue/cpumask = ${not_isolated_cpumask}
/sys/devices/virtual/workqueue/*/cpumask = ${not_isolated_cpumask}
/sys/devices/system/machinecheck/machinecheck*/ignore_ce = 1
[bootloader]
cmdline_realtime=+isolcpus=${managed_irq}${isolated_cores} intel_pstate=disable intel_iommu=on iommu=pt nosoftlockup tsc=reliable transparent_hugepage=never hugepages=16 default_hugepagesz=1G hugepagesz=1G nohz_full=${isolated_cores} rcu_nocbs=${isolated_cores}
[irqbalance]
banned_cpus=${isolated_cores}
[script]
script = ${i:PROFILE_DIR}/script.sh
[scheduler]
isolated_cores=${isolated_cores}
[rtentsk]
EOF
# create script used in tuned.
touch /usr/lib/tuned/mus_rt/script.sh
cat > /usr/lib/tuned/mus_rt/script.sh << 'EOF'
#!/usr/bin/sh
. /usr/lib/tuned/functions
start() { return 0 }
stop() { return 0 }
verify() {
    retval=0
    if [ "$TUNED_isolated_cores" ]; then
        tuna -c "$TUNED_isolated_cores" -P > /dev/null 2>&1
        retval=$?
    fi
    return \$retval
}
process $@
EOF
# enabled tuned and load profile we created.
systemctl enable tuned
systemctl daemon-reload
systemctl start tuned
tuned-adm profile mus_rt
fi


####### SRIOV and Hugepages
yum instlal libhugetlbfs libhugetlbfs-devel

if [ -z "$BUILD_SRIOV" ]
then
    echo "Skipping SRIOV phase."
else
  # First enable num VF on interface
  # check that we have correct number adjust if needed
  # then for each VF set to trusted mode and enable disable spoof check
  num_cur_vfs=$(cat /sys/class/net/$SRIOV_NIC/device/sriov_numvfs)
  interface_status=$(ip link show $SRIOV_NIC | grep UP)
  [[ -z "$interface_status" ]] && { echo "Error: Interface $SRIOV_NIC either down or invalid."; exit 1; }
  if [ "$NUM_VFS" -ne "$num_cur_vfs" ]; then
    echo "Error: Expected number of sriov vfs for adapter $SRIOV_NIC vfs=$NUM_VFS, found $num_cur_vfs";
    echo $NUM_VFS >  /sys/class/net/ens8f0/device/sriov_numvfs;
  fi
  #  set to trusted mode and enable disable spoof check
  for (( i=1; i<=NUM_VFS; i++ ))
  do
     ip link set $SRIOV_NIC vf "$i" trust on
    ip link set $SRIOV_NIC vf "$i" spoof off
  done

fi

if [ -z "$BUILD_HUGEPAGES" ]
then
    echo "Skipping hugepages allocation."
else
  # Huge pages for each NUMA NODE
  IS_SINGLE_NUMA=$(numactl --hardware | grep available | grep 0-1)
  if [ -z "$IS_SINGLE_NUMA" ]
  then
          echo "Target system with single socket."
          echo $PAGES > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES_1GB > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

  else
          echo "Target system with dual socket."
          echo $PAGES > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES_1GB  > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
          echo $PAGES_1GB > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
  fi
  FSTAB_FILE='/etc/fstab'
  HUGEPAGES_MOUNT_LINE='nodev /mnt/huge hugetlbfs pagesize=1GB 0 0'
  grep -qF -- "$HUGEPAGES_MOUNT_LINE" "$FSTAB_FILE" || echo "$HUGEPAGES_MOUNT_LINE" >> "$FSTAB_FILE"
fi


if [ -z "$BUILD_PTP" ]
then
    echo "Skipping ptp allocation."
else

# enable PTP and create config
systemctl enable ptp4l
systemctl daemon-reload
systemctl start ptp4l

cat > /etc/ptp4l.conf  << 'EOF'
[global]
twoStepFlag		1
socket_priority		0
priority1		128
priority2		128
domainNumber		0
#utc_offset		37
clockClass		248
clockAccuracy		0xFE
offsetScaledLogVariance	0xFFFF
free_running		0
freq_est_interval	1
dscp_event		0
dscp_general		0
dataset_comparison	ieee1588
G.8275.defaultDS.localPriority	128
maxStepsRemoved		255
logAnnounceInterval	1
logSyncInterval		0
operLogSyncInterval	0
logMinDelayReqInterval	0
logMinPdelayReqInterval	0
operLogPdelayReqInterval 0
announceReceiptTimeout	3
syncReceiptTimeout	0
delayAsymmetry		0
fault_reset_interval	4
neighborPropDelayThresh	20000000
G.8275.portDS.localPriority	128
asCapable               auto
BMCA                    ptp
inhibit_announce        0
inhibit_delay_req       0
ignore_source_id        0
assume_two_step		0
logging_level		6
path_trace_enabled	0
follow_up_info		0
hybrid_e2e		0
inhibit_multicast_service	0
net_sync_monitor	0
tc_spanning_tree	0
tx_timestamp_timeout	10
unicast_listen		0
unicast_master_table	0
unicast_req_duration	3600
use_syslog		1
verbose			1
summary_interval	0
kernel_leap		1
check_fup_sync		0
pi_proportional_const	0.0
pi_integral_const	0.0
pi_proportional_scale	0.0
pi_proportional_exponent	-0.3
pi_proportional_norm_max	0.7
pi_integral_scale	0.0
pi_integral_exponent	0.4
pi_integral_norm_max	0.3
step_threshold		0.0
first_step_threshold	0.00002
max_frequency		900000000
clock_servo		pi
sanity_freq_limit	200000000
ntpshm_segment		0
msg_interval_request	0
servo_num_offset_values 10
servo_offset_threshold  0
write_phase_mode	0
# Transport options
transportSpecific	0x0
ptp_dst_mac		01:1B:19:00:00:00
p2p_dst_mac		01:80:C2:00:00:0E
udp_ttl			1
udp6_scope		0x0E
uds_address		/var/run/ptp4l
# Default interface options
clock_type		OC
network_transport	UDPv4
delay_mechanism		E2E
time_stamping		hardware
tsproc_mode		filter
delay_filter		moving_median
delay_filter_length	10
egressLatency		0
ingressLatency		0
boundary_clock_jbod	0
# Clock description
productDescription	;;
revisionData		;;
manufacturerIdentity	00:00:00
userDescription		;
timeSource		0xA0
EOF
fi

#reboot
