#!/bin/bash
# This is post install script.  This must happened
# after first post install.
# The goal here
# - build mellanox driver and Intel driver.
# - link to current kernel src.
# - build all DPDK kmod and install. (including UIO)
# - build all libs required for DPDK Crypto.
# - build IPSec libs required for vdev DPDK.
# - build CUDA (optional)
# - install all as shared libs.
# - make sure vfio latest.
# - enable vfio and vfio-pci.
# - enable SRIOV on target network adapter.(must be UP)
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
WITH_QAT=yes

# SRIOV NIC make sure it up.
SRIOV_NIC_LIST="eth4,eth5"
SRIOV_PCI="pci@0000:8a:00.0"
# number of VFS we need.
NUM_VFS=8

# list of vlan interface that we need create.
VLAN_ID_LIST="2000,2001"


# lshw -class network -businfo -notime | grep pci@0000:8a:00.1 | awk '{print $2}'

# num huge pages for 2k and 1Gbe
# make sure this number is same or less than what I do for mus_rt profile.
# i.e. cross-check /proc/cmdline if you need more adjust config at the bottom.
PAGES="2048"
PAGES_1GB="8"

# PTP adapter. i.e 810 or PCI_PT
PTP_ADAPTER="eth7"

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


VLAN_ID_LIST="2000,2001"
ADAPTER_LIST=""
SRIOV_PCI_LIST="pci@0000:8a:00.0,pci@0000:8a:00.1"
BUILD_SRIOV="yes"

# remove all spaces from a string
function remove_all_spaces {
  local str=$1
  echo "${str//[[:blank:]]/}"
}
# return 0 if ubuntu os
function is_ubuntu_os {
  local -r ver="$1"
  grep -q "Ubuntu $ver" /etc/*release
}
# return 0 if centos os.
function is_centos_os {
  local -r ver="$1"
  grep -q "CentOS Linux release $ver" /etc/*release
}
# return 0 if target machine photon os.
function is_photon_os {
  local -r ver="$1"
  grep -q "VMware Photon OS $ver" /etc/*release
}
# return 0 if command installed
function is_cmd_installed {
  local -r cmd_name="$1"
  command -v "$cmd_name" > /dev/null
}

# trim spaces from int str and filters pci device tree
# by type network and return name of adapter.
# pci_to_adapter arg pci@0000:8a:00.0 return eth3
pci_to_adapter() {
  local var="$*"
  local adapter
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  adapter=$(lshw -class network -businfo -notime | grep "$var" | awk '{print $2}')
  echo "$adapter"
}

# neat way to split string
# call my_arr=( $(split_array "," "a,b,c") )
function split_array {
  local -r sep="$1"
  local -r str="$2"
  local -a ary=()
  IFS="$sep" read -r -a ary <<<"$str"
  echo "${ary[*]}"
}

# return true 0 if the given file exists
function file_exists {
  local -r a_file="$1"
  [[ -f "$a_file" ]]
}

# return true (0) if the first arg contains the second arg
function string_contains {
  local -r _s1="$1"
  local -r _s2="$2"
  [[ "$_s1" == *"$_s2"* ]]
}

# Strip the prefix from the string.
# Example:
#   pci@0000:8a:00.0,pci@0000:8a:00.1
#   strip_prefix "pci@0000:8a:00.0" "pci@0000:"  return "8a:00.0"
#   strip_prefix "pci@0000:8a:00.0" "*@" return "0000:8a:00.0"
function strip_prefix {
  local -r src_str="$1"
  local -r prefix="$2"
  echo "${src_str#"$prefix"}"
}

# Example:
#   pci@0000:8a:00.0, pci@0000:8a:00.1
#   strip_suffix "pci@0000:8a:00.0" ":8a:00.0"  return "pci@0000"
function strip_suffix {
  local -r src_str="$1"
  local -r suffix="$2"
  echo "${src_str%"$suffix"}"
}

function is_null_or_empty {
  local -r source_str="$1"
  [[ -z "$source_str" || "$source_str" == "null" ]]
}

# "pci@0000:8a:00.1" -> 0000
function pci_domain() {
    local -r src_str="$1"
    echo "$src_str" | awk -F'@' '{print $2}' | awk -F':' '{print $1}'
}

# Takes "pci@0000:8a:00.1" -> 8a
function pci_bus() {
    local -r src_str="$1"
    echo "$src_str" | awk -F':' '{print $2}'
}
# Takes "pci@0000:8a:00.1" -> 00
function pci_device() {
    local -r src_str="$1"
    echo "$src_str" | awk -F':' '{print $3}' | awk -F'.' '{print $1}'
}
# Takes "pci@0000:8a:00.1" -> 1
function pci_function() {
    local -r src_str="$1"
    echo "$src_str" | awk -F':' '{print $3}' | awk -F'.' '{print $2}'
}

# Takes pci@0000:8a:00.1 -> 0000:8a
function pci_domain_and_bus() {
    local -r src_str="$1"
    if is_null_or_empty "$src_str"; then
      echo ""
    else
      echo "$src_str" | awk -F'@' '{print $2}' | awk -F'.' '{print $1}' | awk -F':' '{print $1":"$2}'
    fi
}

function array_append {
  local -r _content="$1"
  local -ar ary=("$@")
  local final_aray
  final_aray=( "${ary[@]/#/$_content}" )
  echo "${final_aray[*]}"
}


# takes array X and comma seperated list of pci devices
# populate array X with resolved network adapters.
# Mus
function adapters_from_pci_list() {
  # array that will store ethernet names
  local -n eth_name_array=$1
  # a command separated string of pci devices.
  local sriov_pci_devices=$2

  local separator=','
  eth_name_array=$(declare -p sriov_pci_devices)
  # read
  IFS=$separator read -ra sriov_pci_array <<<"$sriov_pci_devices"
  (( j == 0)) || true
  for sriov_device in "${sriov_pci_array[@]}"; do
    local domain_bus
    domain_bus=$(pci_domain_and_bus "$sriov_device")
    local sysfs_device_path="/sys/class/pci_bus/$domain_bus/device/enable"
    if [ -r "$sysfs_device_path" ]; then
      local adapter_name
      echo "Reading from $sysfs_device_path"
      adapter_name=$(pci_to_adapter "$sriov_device")
      echo "Resolve $sriov_device to ethernet adapter $adapter_name"
      eth_name_array[j]=$adapter_name
      (( j++ )) || true
    else
      echo "failed to read sys path $sysfs_device_path"
    fi
  done
}

# usage log "msg"
function log_console_and_file() {
  printf "%b %s. %b\n" "${GREEN}" "$@" "${NC}"
  echo "$@" >> /builder/build_sriov.log
}

# Take list of PCI device, and number of target VFs,
# Check each PCI adapter via sysfs,
# Resolves each PCI address from format pci@0000:BB:AA.0 to eth name.
# Enable sriov if num vfs will reset to target num VFs.
function enable_sriov() {
  local eth_array
  local list_of_pci_devices=$1
  local target_num_vfs=$2
  adapters_from_pci_list eth_array "$list_of_pci_devices"
  log_console_and_file "Enabling SRIOV ${eth_array[*]} target num vfs $target_num_vfs"

  if [ -z "$BUILD_SRIOV" ]; then
    log_console_and_file "Skipping SRIOV phase."
    return 0
  fi

  log_console_and_file "Loading vfio and vfio-pci."
  modprobe vfio
  modprobe vfio-pci enable_sriov=1
  # First enable num VF on interface Check that we have correct number of vs and
  # adjust if needed then for each VF set to trusted mode and enable disable spoof check
  echo "Building sriov config for $eth_array"
  for sriov_eth_name in "${eth_array[@]}"; do
    local sysfs_eth_path
    sysfs_eth_path="/sys/class/net/$sriov_eth_name/device/sriov_numvfs"
    if [ -r "$sysfs_eth_path" ]; then
      echo "Reading from $SYS_DEV_PATH" >>/builder/build_sriov.log
      local if_status
      if_status=$(ip link show "$sriov_eth_name" | grep UP)
      [ -z "$if_status" ] && {
        log_console_and_file "Error: Interface $sriov_eth_name either down or invalid."
        break
      }
      if [ ! -e "$sysfs_eth_path" ]; then
        touch "$sysfs_eth_path" 2>/dev/null
      fi
      local num_cur_vfs
      num_cur_vfs=$(cat "$sysfs_eth_path")
      if [ "$target_num_vfs" -ne "$num_cur_vfs" ]; then
        log_console_and_file "Error: Expected number of sriov vfs for adapter" \
                     "$sriov_eth_name vfs=$target_num_vfs, "\
                      "found $num_cur_vfs"
        # note if adapter bounded we will not be able to do that.
        log_console_and_file "$target_num_vfs" >"$SYS_DEV_PATH" 2>/dev/null
      fi
      #  set to trusted mode and enable disable spoof check
      for ((i = 1; i <= target_num_vfs; i++)); do
        log_console_and_file "Enabling trust on $sriov_eth_name vf $i"
        ip link set "$sriov_eth_name" vf "$i" trust on 2>/dev/null
        ip link set "$sriov_eth_name" vf "$i" spoof off 2>/dev/null
      done
    else
      log_console_and_file "Failed to read $sysfs_eth_path"
      log_console_and_file "$target_num_vfs" >"$sysfs_eth_path" 2>/dev/null
      log_console_and_file "Adjusting number of vf $target_num_vfs in $sysfs_eth_path"
    fi
  done
}

mkdir -p $MLX_DIR
mkdir -p $INTEL_DIR
mkdir -p /builder/

if [ -z "$LOAD_DOCKER_IMAGE" ]
then
    echo "Skipping docker load phase." &> /builder/build_docker_load.log
else
  echo "Enabling docker services." &> /builder/build_docker_load.log
  systemctl enable docker; systemctl start docker
  is_docker_running=$(systemctl status docker | grep running)
  if [ -z "$is_docker_running" ]
  then
    echo "Skipping docker load since it down."
  else
    docker load < $DOCKER_IMAGE_PATH &>> /builder/build_docker_load.log
    docker image ls &>> /builder/build_docker_load.log
  fi
fi

yum --quiet -y install python3-libcap-ng python3-devel rdma-core-devel util-linux-devel \
zip zlib zlib-devel libxml2-devel libudev-devel &> /builder/build_rpms_pull.log

if [ -z "$IPSEC_BUILD" ]
then
    echo "Skipping ipsec lib build." > /build_ipsec.log
else
  cd /root || exit; mkdir -p build; git clone $IPSEC_LIB_LOCATION > /build_ipseclib_clone.log
  cd intel-ipsec-mb || exit; make -j 8 &> /builder/build_ipseclib.log
  make install &> /builder/build_ipseclib_install.log; ldconfig
fi

if [ -z "$MLX_BUILD" ]
then
    echo "Skipping Mellanox driver build."
else
  MLX_IMG=http://www.mellanox.com/downloads/ofed/MLNX_OFED-"$MLNX_VER"/MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  MLX_FILE_NAME=MLNX_OFED_SRC-debian-"$MLNX_VER".tgz
  echo "Pulling Mellanox ofed from $MLX_IMG to $MLX_FILE_NAME" > /builder/build_mlx_driver.log
  cd /tmp || exit; wget --quiet $MLX_IMG --directory-prefix=$MLX_DIR -O $MLX_FILE_NAME &>> /builder/build_mlx_driver.log
  tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1 &>> /builder/build_mlx_driver.log
fi

if [ -z "$INTEL_BUILD" ]
then
    echo "Skipping intel driver build" > /builder/build_intel_driver_install.log
else
  INTEL_IMG=https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz
  cd /tmp || exit; wget --quiet $INTEL_IMG --directory-prefix=$INTEL_DIR -O iavf-$AVX_VERSION.tar.gz &> /builder/build_intel_driver.log
  tar -zxvf iavf-* -C iavf --strip-components=1 >> /builder/build_intel_driver.log
  cd $INTEL_DIR/src || exit; make &>> /builder/build_intel_driver.log && make install &> /builder/build_intel_driver_install.log
fi

# we add shared lib to ld.so.conf
SHARED_LIB_LINE='/usr/local/lib'
SHARED_LD_FILE='/etc/ld.so.conf'
grep -qF -- "$SHARED_LIB_LINE" "$SHARED_LD_FILE" || echo "$SHARED_LIB_LINE" >> "$SHARED_LD_FILE"
ldconfig

pip3 install pyelftools &> /builder/build_pip_pull.log
pip3 install sphinx &>> /builder/build_pip_pull.log
pip3 install -U pyelftools &>> /builder/build_pip_pull.log

# build and install libnl
if [ -z "$LIBNL_BUILD" ]
then
    echo "Skipping libnl driver build" > /builder/build_nl.log
else
  echo "Pulling libnl from build $NL_LIB_LOCATION" > /builder/build_nl.log
  rm -rf $LIB_NL_TARGET_DIR_BUILD; cd /root/build || exit; wget --quiet $NL_LIB_LOCATION
  mkdir libnl || exit; tar -zxvf libnl-*.tar.gz -C libnl --strip-components=1
  cd $LIB_NL_TARGET_DIR_BUILD || exit; ./configure --prefix=/usr &> /builder/configure_nl.log; make -j 8 &> /builder/build_nl.log && make install &> /builder/install_nl.log
  ldconfig; ldconfig /usr/local/lib
fi

# build and install isa
if [ -z "$LIBNL_ISA" ]
then
    echo "Skipping isa-l driver build" > /builder/build_isa.log
else
  rm -rf $LIB_ISAL_TARGET_DIR_BUILD > /build_isa.log
  cd /root/build || exit; git clone https://github.com/intel/isa-l
  cd $LIB_ISAL_TARGET_DIR_BUILD || exit; chmod 700 autogen.sh && ./autogen.sh &> /builder/autogen_isa.log; ./configure &> /builder/configure_isa.log; make -j 8 &> /builder/build_isa.log && make install &> /builder/install_isa.log
  ldconfig; ldconfig /usr/local/lib
fi

# kernel source and DPDK, we're building with Intel and Mellanox driver.
yum --quiet -y install stalld dkms linux-devel linux-rt-devel openssl-devel libmlx5 &> /builder/build_yum_kernel.log

if [ -z "$DPDK_BUILD" ]
then
    echo "Skipping DPDK build." /builder/build_dpdk_install.log
else
  export PATH="$PATH":/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
  TARGET_SYSTEM=$(uname -r)
  pip3 install pyelftools sphinx &> /builder/dpdk_pip.log
  /usr/bin/python3 -c "import importlib.util; import sys; from elftools.elf.elffile import ELFFile" &>> /builder/dpdk_pip.log
  ln -s /usr/src/linux-headers-"$TARGET_SYSTEM"/ /usr/src/linux 2>/dev/null
  rm $DPDK_TARGET_DIR_BUILD 2>/dev/null
  cd /root || exit; wget --quiet -nc -O dpdk.tar.gz $DPDK_URL_LOCATION; tar xf dpdk.tar.gz &> /builder/dpkd_pull.log
  ldconfig
  cd $DPDK_TARGET_DIR_BUILD || exit; meson -Dplatform=native -Dexamples=all -Denable_kmods=true -Dkernel_dir=/lib/modules/"$TARGET_SYSTEM" -Dibverbs_link=shared -Dwerror=true build &> /builder/dpdk_meson.log; ninja -C build -j 8 &> /builder/dpkd_build.log
  cd $DPDK_TARGET_DIR_BUILD/build || exit; ninja install &> /builder/dpdk_install.log && ldconfig;  ldconfig /usr/local/lib
fi

# adjust config and load VFIO
MODULES_VFIO_PCI_FILE='/etc/modules-load.d/vfio-pci.conf'
MODULES_VFIO_FILE='/etc/modules-load.d/vfio.conf'

mkdir -p /etc/modules-load.d 2>/dev/null
if [[ ! -e $MODULES_VFIO_PCI_FILE ]]; then
    touch $MODULES_VFIO_PCI_FILE
fi

if [[ ! -e $MODULES_VFIO_FILE ]]; then
    touch $MODULES_VFIO_FILE
fi

MODULES_VFIO_PCI_LINE='vfio-pci'
MODULES_VFIO_PCI_FILE='/etc/modules-load.d/vfio-pci.conf'
grep -qF -- "$MODULES_VFIO_PCI_LINE" "$MODULES_VFIO_PCI_FILE" || echo "$MODULES_VFIO_PCI_LINE" >> "$MODULES_VFIO_PCI_FILE"

MODULES_VFIO_LINE='vfio'
MODULES_VFIO_FILE='/etc/modules-load.d/vfio.conf'
grep -qF -- "$MODULES_VFIO_LINE" "$MODULES_VFIO_FILE" || echo "$MODULES_VFIO_LINE" >> "$MODULES_VFIO_FILE"

#### create tuned profile.
if [ -z "$TUNED_BUILD" ]; then
    echo "Skipping tuned optimization." > /builder/build_tuned.log
else

  mkdir -p /usr/lib/tuned/mus_rt 2>/dev/null
  # create vars
  rm /etc/tuned/realtime-variables.conf 2>/dev/null; touch /etc/tuned/realtime-variables.conf
  cat > /etc/tuned/realtime-variables.conf << 'EOF'
  isolated_cores=${f:calc_isolated_cores:2}
  isolate_managed_irq=Y
EOF
  # create profile
  rm  /usr/lib/tuned/mus_rt/tuned.conf 2>/dev/null; touch /usr/lib/tuned/mus_rt/tuned.conf
  echo "generating tuned." > /builder/build_tuned.log
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
  rm /usr/lib/tuned/mus_rt/script.sh 2>/dev/null; touch /usr/lib/tuned/mus_rt/script.sh
  echo "generating script.sh." >> /builder/build_tuned.log
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

  echo "restarting tuned" >> /builder/build_tuned.log
  # enabled tuned and load profile we created.
  systemctl enable tuned
  systemctl daemon-reload
  systemctl start tuned
  tuned-adm profile mus_rt
fi


#trim white spaces
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

if [ -z "$WITH_QAT" ]
then
	echo "Skipping QAT phase."
else
    modprobe intel_qat &> /builder/qat_loder.log
fi

####### SRIOV and Hugepages
yum install libhugetlbfs libhugetlbfs-devel > /dev/null 2>&1
if [ -z "$BUILD_SRIOV" ]
then
	echo "Skipping SRIOV phase." > /builder/build_sriov.log
else
  echo "Loading vfio and vfio-pci." > /builder/build_sriov.log
  modprobe vfio
  modprobe vfio-pci enable_sriov=1
	# First enable num VF on interface
	# Check that we have correct number adjust if needed
	# then for each VF set to trusted mode and enable disable spoof check
	SRIOV_NICS=$(trim $SRIOV_NIC_LIST)
	echo "Building sriov config for $SRIOV_NICS" >> /builder/build_sriov.log
  IFS=',' read -ra SRIOV_NIC_ARRAY <<< "$SRIOV_NICS"
  for SRIOV_NIC in "${SRIOV_NIC_ARRAY[@]}"
  do
    SYS_DEV_PATH="/sys/class/net/$SRIOV_NIC/device/sriov_numvfs"
    if [ -r "$SYS_DEV_PATH" ];
    then
      echo "Reading from $SYS_DEV_PATH" >> /builder/build_sriov.log
      interface_status=$(ip link show "$SRIOV_NIC" | grep UP)
      [ -z "$interface_status" ] && { echo "Error: Interface $SRIOV_NIC either down or invalid."; break; }
      if [ ! -e "$SYS_DEV_PATH" ]; then
        touch "$SYS_DEV_PATH"
      fi
      num_cur_vfs=$(cat "$SYS_DEV_PATH")
      if [ "$NUM_VFS" -ne "$num_cur_vfs" ]; then
        echo "Error: Expected number of sriov vfs for adapter $SRIOV_NIC vfs=$NUM_VFS, found $num_cur_vfs" >> /builder/build_sriov.log;
        # note if adapter bouded we will not be able to do that.
        echo $NUM_VFS > "$SYS_DEV_PATH" 2>/dev/null
      fi
      #  set to trusted mode and enable disable spoof check
      for (( i=1; i<=NUM_VFS; i++ ))
      do
        echo "Enabling trust on $SRIOV_NIC vf $i" >> /builder/build_sriov.log
        ip link set "$SRIOV_NIC" vf "$i" trust on 2>/dev/null;
        ip link set "$SRIOV_NIC" vf "$i" spoof off 2>/dev/null;
      done
    else
      echo "Failed to read $SYS_DEV_PATH" >> /builder/build_sriov.log
      echo $NUM_VFS > "$SYS_DEV_PATH" 2>/dev/null
      echo "Adjusting num vfs $NUM_VFS in $SYS_DEV_PATH" >> /builder/build_sriov.log
    fi
  done
fi

if [ -z "$BUILD_HUGEPAGES" ]
then
    echo "Skipping hugepages allocation." > /builder/build_hugepages.log
else
  # Huge pages for each NUMA NODE
  echo "Adjusting numa pages." > /builder/build_hugepages.log
  IS_SINGLE_NUMA=$(numactl --hardware | grep available | grep 0-1)
  if [ -z "$IS_SINGLE_NUMA" ]
  then
          echo "Target system with single socket num 2k $PAGES num 1GB $PAGES_1GB." >> /builder/build_hugepages.log
          echo $PAGES > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES_1GB > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

  else
          echo "Target system with dual socket num 2k $PAGES num 1GB $PAGES_1GB." >> /builder/build_hugepages.log
          echo $PAGES > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
          echo $PAGES_1GB  > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
          echo $PAGES_1GB > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
  fi
  echo "Adjusting /etc/fstab mount hugetlbfs" >> /builder/build_hugepages.log
  FSTAB_FILE='/etc/fstab'
  HUGEPAGES_MOUNT_LINE='nodev /mnt/huge hugetlbfs pagesize=1GB 0 0'
  mkdir /mnt/huge &>> /builder/build_hugepages.log
  mount -t hugetlbfs nodev /mnt/huge &>> /builder/build_hugepages.log
  grep -qF -- "$HUGEPAGES_MOUNT_LINE" "$FSTAB_FILE" || echo "$HUGEPAGES_MOUNT_LINE" >> "$FSTAB_FILE"
fi


#### enable ptp4l
if [ -z "$BUILD_PTP" ]
then
    echo "Skipping ptp configuration." > /builder/build_ptp.log
else
  # enable ptp4l start and create config, restart.
  echo "Enabling ptp4l ptp4l." > /builder/build_ptp.log
  systemctl enable ptp4l
  systemctl enable phc2sys
  systemctl daemon-reload
  systemctl start ptp4l
  systemctl start phc2sys
  systemctl ptp4l >> /builder/build_ptp.log
  systemctl phc2sys >> /builder/build_ptp.log

  # generate config.
  rm /etc/ptp4l.conf 2>/dev/null; touch /etc/ptp4l.conf
  echo "Adjusting ptp4l config /etc/ptp4l.conf" >> /builder/build_ptp.log
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

  # adjust /etc/sysconfig/ptp4l
  rm /etc/sysconfig/ptp4l 2>/dev/null; touch /etc/sysconfig/ptp4l
  echo "Adjusting /etc/sysconfig/ptp4l and setting ptp for adapter $PTP_ADAPTER" >> /builder/build_ptp.log
  cat > /etc/sysconfig/ptp4l << EOF
OPTIONS="-f /etc/ptp4l.conf -i $PTP_ADAPTER"
EOF
  # restart everything.
  echo "Restarting ptp4l " >> /builder/build_ptp.log
  systemctl daemon-reload
  systemctl restart ptp4l
  systemctl restart phc2sys
  systemctl status ptp4l >> /builder/build_ptp.log
fi

cat > /etc/ptp4l.conf  << 'EOF'
[Match]
Name=eth1
Type=ether

[Network]
Description=The unconfigured physical ethernet device

# Make eth1 member of these three VLANs and create virtual
# interfaces on it:
VLAN=myvlan
VLAN=othervlan
VLAN=yetanother

# In case of 'tagged only' setups, you probably don't need any IP
# configuration on the link without VLAN (or: default VLAN).
# For that just omit an [Address] section and disable all the
# autoconfiguration magic like this:
LinkLocalAddressing=no
LLDP=no
EmitLLDP=no
IPv6AcceptRA=no
IPv6SendRA=no

systemctl restart systemd-networkd


#reboot
