#!/bin/bash

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


SRIOV_PCI_LIST="  pci@0000:8a:00.0,    pci@0000:8a:00.1   "
SRIOV_PCI_LIST=$(remove_all_spaces "$SRIOV_PCI_LIST")
NUM_VFS=8
enable_sriov "$SRIOV_PCI_LIST" $NUM_VFS

#use_array $SRIOV_PCI_LIST

#adapters=( "$(adapters_from_pci_list $SRIOV_PCI_LIST)" )
#for adapter in "${adapters[@]}"
#do
#  echo "Adapter ret $adapter"
#done

#
#pci_devices_array=( $(split_array "," $SRIOV_PCI_LIST) )
#cnt=${#pci_devices_array[@]}
#for ((i=0; i < cnt; i++)); do
#    adapter_name=$(pci_to_adapter pci_devices_array[i])
#    pci_devices_array[i]="${pci_devices_array[i]}, $adapter_name"
#    echo "${pci_devices_array[i]}"
#done
