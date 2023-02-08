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
export LANG=en_US.UTF-8
export LC_ALL=$LANG
export PATH="$PATH":/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

AVX_VERSION=4.5.3
MLNX_VER=5.4-1.0.3.0
DOCKER_IMAGE_PATH="/vcu1.tar.gz"
DOCKER_IMAGE_NAME="vcu1"

# all require tools
REQUIRED_TOOLS=("wget" "tar" "lshw" "awk")
# dirs that we expect to hold tar.gz
EXPECTED_DIRS=("/direct" "/mnt/cdrom/direct" "/")
# list of required pip packages.
PIP_PKG_REQUIRED=("pyelftools" "sphinx")

# What we are building, all flags on by default.
# i.e. by default we build all.
MLX_BUILD="yes"
INTEL_BUILD="yes"
DPDK_BUILD="yes"
IPSEC_BUILD="yes"
LIBNL_BUILD="yes"
LIBNL_ISA="yes"
BUILD_TUNED="yes"
BUILD_SRIOV="yes"
BUILD_HUGEPAGES="yes"
BUILD_SRIOV="yes"
BUILD_PTP="yes"
BUILD_LOAD_DOCKER_IMAGE="yes"
WITH_QAT=yes
SKIP_CLEANUP="yes"

# SRIOV NIC make sure it up.
# SRIOV_NIC_LIST="eth4,eth5"
SRIOV_PCI_LIST="pci@0000:51:00.0,pci@0000:51:00.1"
NUM_VFS=8
# list of PCI device that we use for SRIOV.
# SRIOV_PCI_LIST="pci@0000:8a:00.0,pci@0000:8a:00.1"
# SRIOV_PCI_LIST="pci@0000:51:00.0,pci@0000:51:00.1"
# number of VFS we need.

# list of vlan interface that we need create.
VLAN_ID_LIST="2000,2001"

# number of huge pages for 2k and 1GB
# make sure this number is same or less than what I do for mus_rt tuned profile.
# i.e. cross-check /proc/cmdline if you need more adjust config at the bottom.
PAGES="2048"
PAGES_1GB="8"

# PTP adapter. i.e 810 or PCI_PT
PTP_ADAPTER="pci@0000:8a:00.1"

# All links and directories
ROOT_BUILD="/root/build"
IPSEC_LIB_LOCATION="https://github.com/intel/intel-ipsec-mb.git"

# mirror for all online files.
# drivers etc.
DPDK_URL_LOCATIONS=(
  "http://fast.dpdk.org/rel/dpdk-21.11.tar.xz" "https://drive.google.com/u/0/uc?id=1EllCI6gkZ3O70CXAXW9F4QCFD6IrGgZx&export=download&confirm=1e-b")
# Lib NL
LIB_NL_LOCATION=(
  "https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz" "https://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz"
)
# Mellanox IAVF driver
IAVF_LOCATION=(
  "https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz" "https://downloadmirror.intel.com/738727/iavf-$AVX_VERSION.tar.gz"
)
# Mellanox OFED driver
MELLANOX_LOCATION=(
  "http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_VER/MLNX_OFED_SRC-debian-$MLNX_VER.tgz"
  "http://www.mellanox.com/downloads/ofed/MLNX_OFED-$MLNX_VER/MLNX_OFED_SRC-debian-$MLNX_VER.tgz"
)

DPDK_TARGET_DIR_BUILD="$ROOT_BUILD/dpdk-21.11"
LIB_NL_TARGET_DIR_BUILD="$ROOT_BUILD/libnl"
LIB_ISAL_TARGET_DIR_BUILD="$ROOT_BUILD/isa-l"

# DRIVER TMP DIR where we are building.
MLX_DIR=/tmp/mlnx_ofed_src
INTEL_DIR=/tmp/iavf

# all logs
BUILD_MELLANOX_LOG="/build/build_mellanox_driver.log"
BUILD_INTEL_LOG="/build/build_intel_driver.log"
BUILD_DOCKER_LOG="/build/build_docker_images.log"
BUILD_IPSEC_LOG="/build/build_ipsec_lib.log"
BUILD_PIP_LOG="/build/build_pip_deps.log"
BUILD_NL_LOG="/build/build_nl.log"
BUILD_ISA_LOG="/build/build_isa.log"
BUILD_DPDK_LOG="/build/build_dpdk.log"
BUILD_TUNED_LOG="/build/build_tuned.log"
BUILD_HUGEPAGES_LOG="/build/build_hugepages.log"
BUILD_PTP_IPSEC_BUILD_LOG="/build/build_ptp.log"
DEFAULT_BUILDER_LOG="/build/build_main.log"

# list of vlan we need create
VLAN_ID_LIST="2000,2001"
# list of adapter
ADAPTER_LIST=""

# Functions definition,  scroll down to main.

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

# trim spaces from input str, filters pci device tree
# by type network and return name of all adapter.
# pci_to_adapter pci@0000:8a:00.0 return -> eth3
function pci_to_adapter() {
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

# append to array
function array_append {
  local -r _content="$1"
  local -ar ary=("$@")
  local final_aray
  final_aray=( "${ary[@]/#/$_content}" )
  echo "${final_aray[*]}"
}

# takes array X and comma seperated list of pci devices
# populate array X with resolved network adapters.
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

# Function create create log dir.
function create_log_dir() {
  local log_dir
  local default_log=$1
  log_dir=$(dirname "$default_log")
  if ! mkdir "$log_dir"; then
    echo "The $log_dir target directory probably is read-only."
  fi
}

# log message to console and file.
# if log dir not present it will create it.
# if log file already present, log msg will be appended.

# log message to console and file.
function log_console_and_file() {
  local log_dir
  local default_log=$DEFAULT_BUILDER_LOG
  printf "%b %s %b\n" "${GREEN}" "$@" "${NC}"

  log_dir=$(extrac_dir $default_log)
  if [ ! -d log_dir ]; then
    mkdir -p "$log_dir"
  fi

  if file_exists "$default_log"; then
    echo "$@" >>"$default_log"
  else
    echo "$@" >"$default_log"
  fi
}

# Function take list of PCI devices, and number of target VFs,
# Checks each PCI address in sysfs,
# Resolves each PCI address from format the input pci@0000:BB:AA.0 to
# respected eth name.
# Enables sriov if num vfs will reset to target num VFs.
function enable_sriov() {
  local eth_array
  local list_of_pci_devices=$1
  declare -i target_num_vfs=$2
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
    local sysfs_path
    sysfs_path="/sys/class/net/$sriov_eth_name/device/sriov_numvfs"
    log_console_and_file "sysfs path $sysfs_path"
    if [ -r "$sysfs_path" ]
    then
        log_console_and_file "Reading from $sysfs_path"
        local if_status
        if_status=$(ip link show "$sriov_eth_name" | grep UP)
        [ -z "$if_status" ] && {
          log_console_and_file "Error: Interface $sriov_eth_name either down or invalid."
          break
        }
        if [ ! -e "$sysfs_eth_path" ]; then
          touch "$sysfs_eth_path" 2>/dev/null
        fi
        local current_num_vfs
        current_num_vfs=$(cat "$sysfs_path" | grep $target_num_vfs)
        if [ "${target_num_vfs:-0}" -ne "${current_num_vfs:-0}" ]
        then
            log_console_and_file "Error: Expected number of sriov vfs for adapter=$sriov_eth_name vfs=$target_num_vfs found $current_num_vfs"
            # note if adapter bounded we will not be able to do that.
            log_console_and_file "num vfs $target_num_vfs"
            echo "$target_num_vfs" > "$sysfs_path"
        fi
        #  set to trusted mode and enable disable spoof check
        for ((i = 1; i <= target_num_vfs; i++)); do
          log_console_and_file "Enabling trust on $sriov_eth_name vf $i"
          ip link set "$sriov_eth_name" vf "$i" trust on 2>/dev/null
          ip link set "$sriov_eth_name" vf "$i" spoof off 2>/dev/null
        done
    else
        log_console_and_file "Failed to read $sysfs_eth_path"
        log_console_and_file "Adjusting number of vf $target_num_vfs in $sysfs_eth_path"
        echo "$target_num_vfs" > "$sysfs_path"
    fi
  done
}

# Functon load docker image
# First argument is log file, docker image name, image path.
# load_docker_image /builder/build_docker.log image_name, image_path
function build_docker_images() {
  local log_file=$1
  local docker_image_path=$2
  local docker_image_name=$3

  if file_exists "$docker_image_path"; then
    log_console_and_file "Loading docker image $docker_image_path"
  else
    echo "File $file_exists not found."
  fi

  if [ -z "$BUILD_LOAD_DOCKER_IMAGE" ]; then
    log_console_and_file "Skipping docker load phase."
  else
    if [ -z "$docker_image_name" ]; then
      log_console_and_file "Skipping docker load phase."
    else
      log_console_and_file "Enabling docker services."
      systemctl enable docker
      systemctl start docker
      local is_docker_running
      is_docker_running=$(systemctl status docker | grep running)
      if [ -z "$is_docker_running" ]; then
        log_console_and_file "Skipping docker load, failed to start docker."
      else
        log_console_and_file "Loading docker image from $docker_image_path"
        docker load <"$docker_image_path"
        docker image ls > "$log_file" 2>&1
      fi
    fi
  fi
}

# function builds an ipsec lib, required for DPDK.
function build_ipsec_lib() {
  local log_file=$1
  local suffix
  local repo_name
  touch "$log_file" 2>/dev/null
  suffix=".git"
  if [ -z "$IPSEC_BUILD" ]
  then
      log_console_and_file "Skipping ipsec lib build."
  else
    log_console_and_file "Building ipsec lib."
    cd $ROOT_BUILD || exit; git clone "$IPSEC_LIB_LOCATION" > "$log_file" 2>&1
    repo_name=${IPSEC_LIB_LOCATION/%$suffix/}
    repo_name=${repo_name##*/}
    cd $ROOT_BUILD/"$repo_name" || exit; make -j 8 > "$log_file" 2>&1
    make install &> "$log_file"; ldconfig
  fi
}

# Function builds mellanox driver
# args log file, file_name, mlx_ver
function build_mellanox_driver() {
  local log_file=$1
  local build_dir=$2
  echo "" > "$log_file"

  if [ -z "$MLX_BUILD" ]
  then
      log_console_and_file "Skipping Mellanox driver build."
  else
    cd "$build_dir" || exit; tar -zxvf MLNX_OFED_SRC-debian-* -C  mlnx_ofed_src --strip-components=1 > "$log_file" 2>&1
  fi
}

# Function builds intel iavf
# args log_file , download dir
function build_intel_iavf() {
  local log_file=$1
  local build_dir=$2
  echo "" >"$log_file"
  if [ -z "$INTEL_BUILD" ]
  then
      log_console_and_file "Skipping intel driver build"
  else
    cd "$build_dir" || exit; tar -zxvf iavf-* -C iavf --strip-components=1 > "$log_file" 2>&1
    cd "$build_dir"/src || exit; make > "$log_file" 2>&1; make install > "$log_file" 2>&1
  fi
}

# Function adjust shared libs
function adjust_shared_libs() {
  log_console_and_file "Adjusting shared libs."
  # we add shared lib to ld.so.conf
  local SHARED_LIB_LINE='/usr/local/lib'
  local SHARED_LD_FILE='/etc/ld.so.conf'
  grep -qF -- "$SHARED_LIB_LINE" "$SHARED_LD_FILE" || echo "$SHARED_LIB_LINE" >>"$SHARED_LD_FILE"
  ldconfig
}

# Function install requires pips
# first args a log file , second array of package names
function build_install_pips_deb() {
  local log_file=$1
  shift
  local pip_array=("$@")
  touch "$log_file" 2>/dev/null
  for pip_pkg_name in "${pip_array[@]}"; do
    log_console_and_file "Install pip $pip_pkg_name"
    pip3 install "$pip_pkg_name" > "$log_file" 2>&1
  done
}

# Function builds lib nl
#  First argument a path to log file.
function build_lib_nl() {
  local log_file=$1
  local build_dir=$2
  touch "$log_file" 2>/dev/null

  # build and install libnl
  if [ -z "$LIBNL_BUILD" ]; then
    log_console_and_file "Skipping libnl driver build"
  else
    log_console_and_file "Extracting libnl to $build_dir"
    cd "$build_dir" || exit; tar -zxvf libnl-*.tar.gz -C libnl --strip-components=1 > "$log_file" 2>&1
    cd "$build_dir" || exit
    ./configure --prefix=/usr &>/build/configure_nl.log
    make -j 8 > "$log_file" 2>&1; make install > "$log_file" 2>&1
    ldconfig; ldconfig /usr/local/lib
  fi
}

# Function builds lib isa
#  First argument a path to log file.
#  it downloads only.
function build_lib_isa() {
  local log_file=$1
  touch "$log_file" 2>/dev/null

  # build and install isa
  if [ -z "$LIBNL_ISA" ]; then
    log_console_and_file "Skipping isa-l driver build"
  else
    rm -rf $LIB_ISAL_TARGET_DIR_BUILD
    cd $ROOT_BUILD || exit
    git clone https://github.com/intel/isa-l
    cd $LIB_ISAL_TARGET_DIR_BUILD || exit
    chmod 700 autogen.sh && ./autogen.sh > "$log_file" 2>&1
    ./configure > "$log_file" 2>&1
    make -j 8 > "$log_file" 2>&1; make install > "$log_file" 2>&1
    ldconfig
    ldconfig /usr/local/lib
  fi
}

# Function builds DPDK
#  First arg a path to log file.
#  Second optional arg path to a kernel headers.
function build_dpdk() {
    local log_file=$1
    local direct_file
    local suffix
    local prefix
    local build_dir
    suffix=".tar.xz"
    prefix="dpdk-"

    touch "$log_file" 2>/dev/null

    local default_kernel_prefix="/usr/src/linux-headers-"
    local custom_kern_prefix=$2
    if [ -z "$default_kernel_prefix" ]; then
      log_console_and_file "Using default kernel header prefix $default_kernel_prefix"
    else
      log_console_and_file "Using user supplied prefix $default_kernel_prefix"
      default_kernel_prefix=$custom_kern_prefix
    fi

    # kernel source and DPDK, we're building with Intel and Mellanox driver.
    yum --quiet -y install stalld dkms linux-devel linux-rt-devel \
    openssl-devel libmlx5 > "$log_file" 2>&1

    if [ -z "$DPDK_BUILD" ]; then
      log_console_and_file "Skipping DPDK build."
    else
      log_console_and_file "Building DPDK."
      local target_system
      local meson_build_dir
      target_system=$(uname -r)
      # in case pip wasn't called , we need install pyelftools
      pip3 install pyelftools sphinx > "$log_file" > "$log_file" 2>&1
      /usr/bin/python3 -c "import importlib.util; import sys; from elftools.elf.elffile import ELFFile" > "$log_file" 2>&1
      ln -s /usr/src/linux-headers-"$target_system"/ /usr/src/linux 2>/dev/null
      ldconfig; ldconfig /usr/local/lib
      meson_build_dir=$build_dir/build
      log_console_and_file "Using dir $meson_build_dir as build staging"
      mkdir -p "$meson_build_dir"; cd "$meson_build_dir" || exit
      meson -Dplatform=native -Dexamples=all -Denable_kmods=true -Dkernel_dir=/lib/modules/"$target_system" -Dibverbs_link=shared -Dwerror=true build > "$log_file" 2>&1
      log_console_and_file "Finished building DPDK."
      ninja -C build -j 8 > "$log_file" 2>&1
      cd "$meson_build_dir" || exit;
      ninja install > "$log_file" 2>&1
      log_console_and_file "Installing DPDK."
      ldconfig; ldconfig /usr/local/lib
    fi
}

# Functions load vfio and vfio_pci
function load_vfio_pci() {

  log_console_and_file "Loading vfio and vfio_pci."

  # adjust config and load VFIO
  local MODULES_VFIO_PCI_FILE='/etc/modules-load.d/vfio-pci.conf'
  local MODULES_VFIO_FILE='/etc/modules-load.d/vfio.conf'

  mkdir -p /etc/modules-load.d 2>/dev/null
  if [[ ! -e $MODULES_VFIO_PCI_FILE ]]; then
    touch $MODULES_VFIO_PCI_FILE 2>/dev/null
  fi

  if [[ ! -e $MODULES_VFIO_FILE ]]; then
    touch $MODULES_VFIO_FILE 2>/dev/null
  fi

  local MODULES_VFIO_PCI_LINE='vfio-pci'
  local MODULES_VFIO_PCI_FILE='/etc/modules-load.d/vfio-pci.conf'
  grep -qF -- "$MODULES_VFIO_PCI_LINE" "$MODULES_VFIO_PCI_FILE" || echo "$MODULES_VFIO_PCI_LINE" >>"$MODULES_VFIO_PCI_FILE"

  local MODULES_VFIO_LINE='vfio'
  local MODULES_VFIO_FILE='/etc/modules-load.d/vfio.conf'
  grep -qF -- "$MODULES_VFIO_LINE" "$MODULES_VFIO_FILE" || echo "$MODULES_VFIO_LINE" >>"$MODULES_VFIO_FILE"
}

# Function fix tuned and some build in, generate a new tuned profile
# updates tuned python and make it active.
function build_tuned() {
  local log_file=$1
  touch "$log_file" 2>/dev/null
  #### create tuned profile.
  if [ -z "$BUILD_TUNED" ]; then
    log_console_and_file "Skipping tuned optimization."
  else
    rm -rf $ROOT_BUILD/tuned 2>/dev/null
    mkdir -p $ROOT_BUILD/tuned 2>/dev/null
    git clone https://github.com/spyroot/tuned.git; cd tuned || exit;
    cp -Rf tuned /usr/lib/python3.10/site-packages

    # profile
    mkdir -p /usr/lib/tuned/mus_rt 2>/dev/null
    # create vars
    rm /etc/tuned/realtime-variables.conf 2>/dev/null
    touch /etc/tuned/realtime-variables.conf 2>/dev/null
    cat >/etc/tuned/realtime-variables.conf <<'EOF'
  isolated_cores=${f:calc_isolated_cores:2}
  isolate_managed_irq=Y
EOF
  # create profile
    rm /usr/lib/tuned/mus_rt/tuned.conf 2>/dev/null
    touch /usr/lib/tuned/mus_rt/tuned.conf 2>/dev/null
    log_console_and_file "Generating tuned.conf config."
    cat >/usr/lib/tuned/mus_rt/tuned.conf <<'EOF'
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

    # create script used for a tuned.
    rm /usr/lib/tuned/mus_rt/script.sh 2>/dev/null
    touch /usr/lib/tuned/mus_rt/script.sh 2>/dev/null
    log_console_and_file "Generating tuned script.sh."
    cat >/usr/lib/tuned/mus_rt/script.sh <<'EOF'
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
    return $retval
}
process $@
EOF

    log_console_and_file "Enabling and restarting tuned."
    # enabled tuned and load profile we created.
    systemctl enable tuned
    systemctl daemon-reload
    systemctl start tuned
    log_console_and_file "Activating mus_rt profile."
    tuned-adm profile mus_rt
    systemctl status tuned
  fi
}

# Function trims white spaces
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Function enables Intel QAT.
function build_qat() {
  if [ -z "$WITH_QAT" ]; then
    log_console_and_file "Skipping QAT phase."
  else
    modprobe intel_qat
  fi
}

# Function builds huge pages
#
function build_hugepages() {
  local log_file=$1
  local pages=$2
  local page_1gb=$3

  touch "$log_file" > /dev/null 2>&1

  yum install libhugetlbfs libhugetlbfs-devel > /dev/null 2>&1
  if [ -z "$BUILD_HUGEPAGES" ]
  then
      log_console_and_file "Skipping hugepages allocation."
  else
    # Huge pages for each NUMA NODE
    log_console_and_file "Adjusting numa pages."
    local IS_SINGLE_NUMA
    IS_SINGLE_NUMA=$(numactl --hardware | grep available | grep 0-1)
    if [ -z "$IS_SINGLE_NUMA" ]
    then
            log_console_and_file "Target system with single socket num 2k $PAGES num 1GB $PAGES_1GB."
            echo "$pages" > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
            echo "$page_1gb" > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
    else
            log_console_and_file "Target system with dual socket num 2k $PAGES num 1GB $PAGES_1GB."
            echo "$pages" > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
            echo "$pages" > /sys/devices/system/node/node1/hugepages/hugepages-2048kB/nr_hugepages
            echo "$page_1gb"  > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
            echo "$page_1gb" > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
    fi
    log_console_and_file "Adjusting /etc/fstab mount hugetlbfs"
    local FSTAB_FILE='/etc/fstab'
    local HUGEPAGES_MOUNT_LINE='nodev /mnt/huge hugetlbfs pagesize=1GB 0 0'
    mkdir /mnt/huge > /dev/null 2>&1
    mount -t hugetlbfs nodev /mnt/huge > "$log_file" 2>&1
    grep -qF -- "$HUGEPAGES_MOUNT_LINE" "$FSTAB_FILE" || echo "$HUGEPAGES_MOUNT_LINE" >> "$FSTAB_FILE"
  fi
}

# mainly for debug to re-run during dev phase
function cleanup() {
    rm /build/*
    rm -rf $DPDK_TARGET_DIR_BUILD/build
    docker volume prune -f

}

## build configs and start ptp
function build_ptp() {
  local log_file=$1
  touch "$log_file" 2>/dev/null

  if [ -z "$BUILD_PTP" ]
  then
      log_console_and_file "Skipping ptp configuration."
  else
    # enable ptp4l start and create config, restart.
    log_console_and_file "Enabling ptp4l ptp4l."
    systemctl enable ptp4l
    systemctl enable phc2sys
    systemctl daemon-reload
    systemctl start ptp4l
    systemctl start phc2sys
    systemctl ptp4l > "$log_file" 2>&1
    systemctl phc2sys > "$log_file" 2>&1

    # generate config.
    rm /etc/ptp4l.conf 2>/dev/null; touch /etc/ptp4l.conf 2>/dev/null
    echo "Adjusting ptp4l config /etc/ptp4l.conf" >> /build/build_ptp.log
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
    ptp_adapter_name=$(pci_to_adapter "$PTP_ADAPTER")
    # adjust /etc/sysconfig/ptp4l
    rm /etc/sysconfig/ptp4l 2>/dev/null; touch /etc/sysconfig/ptp4l 2>/dev/null
    log_console_and_file "Adjusting /etc/sysconfig/ptp4l and setting ptp for adapter $ptp_adapter_name"
    cat > /etc/sysconfig/ptp4l << EOF
OPTIONS="-f /etc/ptp4l.conf -i $PTP_ADAPTER"
EOF
    # restart everything.
    log_console_and_file "Restarting ptp4l "
    systemctl daemon-reload
    systemctl restart ptp4l
    systemctl restart phc2sys
    systemctl status ptp4l >> $BUILD_PIP_LOG
  fi
}

# build required dirs
function build_dirs() {
  mkdir -p $MLX_DIR > /dev/null 2>&1
  mkdir -p $INTEL_DIR > /dev/null 2>&1
  mkdir -p /build/ > /dev/null 2>&1
}

# Function create vlan interface
function build_vlans_ifs() {
  local vlan_id=$1
  local if_name=$2
  cat > /etc/systemd/network/00-vlanid_"$vlan_id".network << EOF
[Match]
Name=$if_name
Type=ether
[VLAN]
Id=$vlan_id
[Network]
Description=physical ethernet device
VLAN=vlan_"$vlan_id"
LinkLocalAddressing=no
LLDP={}
EmitLLDP={}
IPv6AcceptRA={}
IPv6SendRA={}
EOF
  systemctl restart systemd-networkd
}

# Function checks if required mandatory tools installed.
function check_installed() {
  local  result_var_name=$1
  declare -i errors=0
  shift
  local array_tools=("$@")
  for tool in "${array_tools[@]}"
  do
    if is_cmd_installed "$tool"
    then
      log_console_and_file "tools $tool installed."
    else
      log_console_and_file "tool $tool not installed."
      errors+=1
    fi
  done
  eval "$result_var_name"="'$errors'"
}


# /mnt/cdrom/direct/dpdk-21.11.3.tar.xz
# Function extract version from
# filename, url , or full path
# "dpdk-21.11.3.tar.xz" -> 21.11.3
# "/mnt/cdrom/direct/dpdk-21.11.3.tar.xz" -> 21.11.3
# http://fast.dpdk.org/rel/dpdk-21.11.tar.xz" -> 21.11
function extrac_version() {
  local file_path=$1
  local pref=$2
  local suffix=$3
  local version
  version=""

  if [ -z "$file_path" ] || [ -z "$pref" ] || [ -z "$suffix" ]; then
    version=""
  else
    file_path=$(trim "$file_path")
    local file_name
    file_name=$(basename "$file_path")
    version=${file_name/#$pref/}
    version=${version/%$suffix/}
  fi

  echo "$version"
}

# Extract directory
function extrac_dir() {
  local dir_path=$1
  local dir_name
  dir_name=""

  if [ -z "$dir_path" ]; then
    dir_name=""
  else
    local dir_name
    dir_path=$(trim "$dir_path")
    dir_name=$(dirname "$dir_path")
  fi

  echo "$dir_name"
}

# extrac filename
function extrac_filename() {
  local file_path=$1
  local file_name
  file_name=""

  if [ -z "$file_path" ]; then
    file_name=""
  else
    local file_name
    file_path=$(trim "$file_path")
    file_name=$(basename "$file_path")
  fi

  echo "$file_name"
}

# Function search a file in array of dirs
# first argument is suffix for a file
# second argument is prefix.
# suffix and prefix used to extrac version.
# third argument a pattern dpdk, iavf etc.
# last argument what we search, for logging purpose.
function search_file() {
  local search_pattern=$1
  local target_name=$2
  local suffix=$3
  local  __resul_search_var=$4
  local found_file=""
  local found_dir=""

  # first check all expected dirs
  for expected_dir in "${EXPECTED_DIRS[@]}"; do
    log_console_and_file "Searching $target_name in $expected_dir"
    found_file=$(ls "$expected_dir" 2>/dev/null | grep "$search_pattern*")
    if [ -n "$found_file" ]; then
      log_console_and_file "Found $target_name in $expected_dir"
      found_dir=expected_dir
      break
    fi
  done

  # mount cdrom and check
  if [ -z "$found_file" ]; then
    log_console_and_file "Mounting cdrom and searching $target_name"
    mount /dev/cdrom 2>/dev/null
    found_file=$(ls /mnt/cdrom/direct 2>/dev/null | grep "$search_pattern*")
  else
    log_console_and_file "Found local copy $direct_file"
  fi

  # mount cdrom and check
  if [ -z "$found_file" ]; then
    local search_regex
    search_regex=".*$search_pattern.*.$suffix"
    log_console_and_file "File not found, doing deep search pattern $search_regex"
    found_file="$(cd / || exit; find / -type f -regex "$search_regex" -maxdepth 10 2>/dev/null | head -n 1)"
    log_console_and_file "Result of deep search $found_file"
  fi

  if file_exists "$found_file"; then
    log_console_and_file "Deep search found a file $found_file"
  fi

  if [[ "$__resul_search_var" ]]; then
    eval "$__resul_search_var"="'$found_file'"
  else
    echo "$found_file"
  fi
}


# Function takes target dir where to store a file
# and list of location mirror for a given file.
function fetch_file() {
  local target_dir=$1
  local  __result_fetch_var=$2
  shift 2
  local urls=("$@")
  local remote_file_name
  local full_path

  if [ ! -d target_dir ]; then
    mkdir -p "$target_dir"
  fi

  log_console_and_file "File will be saved in $target_dir"

  for url in "${urls[@]}"; do
    remote_file_name=$(extrac_filename "$url")
    log_console_and_file "Fetching file $remote_file_name from $url"
    full_path=$target_dir"/"$remote_file_name
    wget --quiet -nc "$url" -O "$remote_file_name" || rm -f "$remote_file_name"
    if file_exists "$remote_file_name"; then
      log_console_and_file "Downloaded file to $remote_file_name"
      break
    else
      log_console_and_file "Failed to fetch $remote_file_name from $url"
    fi
  done

  if file_exists "$remote_file_name"; then
    log_console_and_file "Copy file to $remote_file_name to $full_path"
    cp "$remote_file_name" "$full_path"
  fi

  if [[ "$__result_fetch_var" ]]; then
    eval "$__result_fetch_var"="'$full_path'"
  else
    echo "$full_path"
  fi
}

#unpack_all_files
function unpack_all_files() {
  local search_criterion=$1
  local file_name=$2
  local suffix=$3
  local  __result_loc_var=$4
  shift 4
  local mirrors=("$@")
  local build_location=$ROOT_BUILD/$file_name
  local search_result
  search_file "$search_criterion" "$file_name" "$suffix" search_result
  if file_exists "$search_result"; then
    log_console_and_file "Found existing file $search_result"
    mkdir -p "$build_location"
    tar -xf "$search_result" --directory "$build_location" --strip-components=1
  else
    local download_result=""
    log_console_and_file "File not found need downloading $file_name"
    fetch_file $ROOT_BUILD download_result "${mirrors[@]}"
    if file_exists "$download_result"; then
      log_console_and_file "File successfully downloaded $file_name location $download_result"
      mkdir -p "$build_location"
      tar -xf "$download_result" --directory "$build_location" --strip-components=1
    fi
  fi

  if [[ "$__result_loc_var" ]]; then
    eval "$__result_loc_var"="'$build_location'"
  else
    echo "$build_location"
  fi
}

function clean_up() {
  if [ -z "$SKIP_CLEANUP" ] || [ $SKIP_CLEANUP == "yes" ]; then
    log_console_and_file "Skipping clean up"
    rm -rf dpdk*
    rm -rf iavf-*
    rm -rf libnl-*.tgz
    rm -rf MLNX_OFED_SRC-*.tgz
    rm -rf "${ROOT_BUILD:?}/"*
  fi
}

# main entry for a script
#
function main() {
  local log_main_dir
  log_main_dir=$(dirname "$DEFAULT_BUILDER_LOG")
  rm -rf "$log_main_dir"
  rm -rf $ROOT_BUILD
  create_log_dir "$DEFAULT_BUILDER_LOG"

  declare -i errs=0
  check_installed errs "${REQUIRED_TOOLS[@]}"
  if [[ $errs -gt 0 ]]; then
    echo "Please check required commands."
  fi

  # fix-up all vars in case of mistake.
  SRIOV_PCI_LIST=$(remove_all_spaces "$SRIOV_PCI_LIST")
  VLAN_ID_LIST=$(remove_all_spaces "$VLAN_ID_LIST")
  NUM_VFS=$(remove_all_spaces "$NUM_VFS")
  AVX_VERSION=$(remove_all_spaces "$AVX_VERSION")
  MLNX_VER=$(remove_all_spaces "$MLNX_VER")
  DOCKER_IMAGE_PATH=$(remove_all_spaces "$DOCKER_IMAGE_PATH")
  PAGES=$(remove_all_spaces "$PAGES")

  yum --quiet -y install python3-libcap-ng python3-devel \
  rdma-core-devel util-linux-devel \
  zip zlib zlib-devel libxml2-devel \
  libudev-devel &> /build/build_rpms_pull.log

  # installed.before and after our diff
  yum list installed > /installed.after.log
  rpm -qa > /rpm.installed.after.log

  build_dirs

    # all location updated
  local dpdk_build_location=""
  local iavf_build_location=""
  local libnl_build_location=""
  local mellanox_build_location=""

  clean_up

  # either fetch from local or remote
  unpack_all_files "dpdk" "dpdk-21.11" "tar.xz" dpdk_build_location "${DPDK_URL_LOCATIONS[@]}"
  unpack_all_files "iavf-$AVX_VERSION" "iavf-$AVX_VERSION" "tar.gz" iavf_build_location "${IAVF_LOCATION[@]}"
  unpack_all_files "libnl-3.2.25" "libnl-3.2.25" "tar.gz" libnl_build_location "${LIB_NL_LOCATION[@]}"
  unpack_all_files "MLNX_OFED_SRC" "MLNX_OFED_SRC-debian-$MLNX_VER" "tgz" mellanox_build_location "${MELLANOX_LOCATION[@]}"

  echo "DPDK Build location $dpdk_build_location"
  echo "IAVF Build location $iavf_build_location"
  echo "LIBNL Build location $libnl_build_location"
  echo "Mellanox Build location $mellanox_build_location"

  build_mellanox_driver "$BUILD_MELLANOX_LOG" "$mellanox_build_location"
  build_intel_iavf "$BUILD_INTEL_LOG" "$iavf_build_location"
  build_docker_images $BUILD_DOCKER_LOG "$DOCKER_IMAGE_PATH" "$DOCKER_IMAGE_NAME"
  build_ipsec_lib "$BUILD_IPSEC_LOG"
  adjust_shared_libs
  build_install_pips_deb "$BUILD_PIP_LOG" "${PIP_PKG_REQUIRED[@]}"
  build_lib_nl "$BUILD_NL_LOG" "$libnl_build_location"
  build_lib_isa "$BUILD_ISA_LOG"
  build_dpdk "$BUILD_DPDK_LOG" "$dpdk_build_location"
  load_vfio_pci
  build_tuned "$BUILD_TUNED_LOG"

  build_qat
  enable_sriov "$SRIOV_PCI_LIST" "$NUM_VFS"
  build_hugepages "$BUILD_HUGEPAGES_LOG" "$PAGES" "$PAGES_1GB"
  build_ptp "$BUILD_PTP_IPSEC_BUILD_LOG"
}

main
#
##reboot
