#!/bin/bash
# This a generic ELA wrapper.  Most of all DPDK app require
# a) list of core
# b) list of DPDK device
# c) huge pages allocated for app
# d) some sort of mapping core to port , or nxCore to TX and RX etc
#
# Hence this a generic wrapper that you can call before ELA
# - to select N random core from a given NUMA
# - to select N random VF from a some PF ( or consider all PFs)
# - pass to a container original MAC ( note container doesn't need to bind to DPDK)
#   if OS already did bind ( Multus etc) do that. it a bit hard to get MAC hence we need
#   to see initial what kernel located via kernel driver
#   hence based on SELECTED VF we construct SELECTED MAC
#
# - Memory that we want to pass. i.e a memory for particular
#   socket from where we selected cores
# Autor Mus spyroot@gmail.com

# from numa 0, select 4 cores at random
numa_node=0
num_cores_to_select=9
num_vf_to_select=2

# our PF
BUS_FILTER="0000:03"
ALLOCATE_SOCKET_MEMORY=64
DPDK_PMD_TYPE=vfio-pci

NUM_HUGEPAGES=${NUM_HUGEPAGES:-1024}
HUGEPAGE_SIZE=${HUGEPAGE_SIZE:-2048}  # Size in kB
HUGEPAGE_MOUNT=${HUGEPAGE_MOUNT:-/mnt/huge}


# Display help message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n <numa_node>                 NUMA node to select cores from (default: $numa_node)"
    echo "  -c <num_cores_to_select>       Number of cores to select (default: $num_cores_to_select)"
    echo "  -v <num_vf_to_select>          Number of VFs to select (default: $num_vf_to_select)"
    echo "  -b <BUS_FILTER>                BUS filter for selecting VFs (default: $BUS_FILTER)"
    echo "  -m <ALLOCATE_SOCKET_MEMORY>    Memory to allocate per socket in MB (default: $ALLOCATE_SOCKET_MEMORY)"
    echo "  -p <DPDK_PMD_TYPE>             DPDK PMD type (default: $DPDK_PMD_TYPE)"
    echo "  -h                             Display this help and exit"
    exit 1
}

# Parse command-line options
while getopts "n:c:v:b:m:p:h" opt; do
    case ${opt} in
        n) numa_node=${OPTARG} ;;
        c) num_cores_to_select=${OPTARG} ;;
        v) num_vf_to_select=${OPTARG} ;;
        b) BUS_FILTER=${OPTARG} ;;
        m) ALLOCATE_SOCKET_MEMORY=${OPTARG} ;;
        p) DPDK_PMD_TYPE=${OPTARG} ;;
        h) usage ;;
        \?) echo "Invalid option: $OPTARG" 1>&2; usage ;;
        :) echo "Invalid option: $OPTARG requires an argument" 1>&2; usage ;;
    esac
done

# Shift off the options and optional --
shift $((OPTIND -1))
EXTRA_ARGS="$*"

echo "Selected configurations:"
echo "NUMA Node: $numa_node"
echo "Number of Cores to Select: $num_cores_to_select"
echo "Number of VFs to Select: $num_vf_to_select"
echo "BUS Filter: $BUS_FILTER"
echo "Socket Memory to Allocate: $ALLOCATE_SOCKET_MEMORY MB"
echo "DPDK PMD Type: $DPDK_PMD_TYPE"

# Select vf based on PMD driver and PMD BUS
# Note this function uses container ( you change to dpdk-devbind.py
function select_vf_dpdk {
    local BUS_FILTER="$1"

    local output="$(docker run -it --privileged --rm \
                    spyroot/pktgen_toolbox_generic:latest dpdk-devbind.py -s \
                    | grep $DPDK_PMD_TYPE | grep Virtual)"

    local pci_devices
    readarray -t pci_devices <<< "$(echo "$output" | awk \
    '/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]/ {print $1}')"

    for pci in "${pci_devices[@]}"; do
        if [[ -n "$BUS_FILTER" ]]; then
            if [[ "$pci" == "$BUS_FILTER"* ]]; then
                echo "$pci"
            fi
        else
            # If no bus filter is provided, show all VFs.
            echo "$pci"
        fi
    done
}

# This function retrieves a list of all CPU cores that
# are currently bound to the system's physical CPUs.
core_list() {
	core_list_str=$(numactl -s | grep "physcpubind:" | sed 's/physcpubind: //')
	read -r -a core_list <<< "$core_list_str"
	echo "${core_list[@]}"
}

# This function selects a specified number
# of random CPU cores from a given NUMA node.
# Args:
#   $1: The NUMA node from which to select cores.
#   $2: The number of cores to select from that NUMA node.
cores_from_numa(){
	local _numa_node=$1
	local _num_cores_to_select=$2
	local cpu_list_str=$(numactl -H | grep -E "^node $_numa_node cpus:" | cut -d: -f2)
	local core_list=()
	read -r -a core_list <<< "$cpu_list_str" # Convert string to array

    # if core is less than or equal to available cores
    if [ "${#core_list[@]}" -lt "$_num_cores_to_select" ]; then
	    echo "Error: Requested more cores than available." >&2
	    return 1
    fi

    local selected_cores=()
    # Select random cores
    for i in $(shuf -i 0-$((${#core_list[@]}-1)) -n "$_num_cores_to_select"); do
	    selected_cores+=("${core_list[$i]}")
    done

    echo "${selected_cores[@]}"
}

# this function return mac address of device
# note if device already bounded to DPDK this most
# reliable way to get it
function vf_mac_address() {
    local _pci_address=$1
    local _mac_address=$(dmesg | grep "$_pci_address" | \
    grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
    echo "$_mac_address"
}

declare -a selected_target_vf
declare -a device_mac_addresses

core_list=$(core_list)
selected_cores=$(cores_from_numa $numa_node $num_cores_to_select)
readarray -t selected_vf < <(select_vf_dpdk "$BUS_FILTER")

for i in $(shuf -i 0-$((${#selected_vf[@]}-1)) -n "$num_vf_to_select"); do
  selected_target_vf+=("${selected_vf[$i]}")
done

SELECTED_VF=$(printf "%s " "${selected_target_vf[@]}")
SELECTED_VF=${SELECTED_VF% }
export SELECTED_VF

SELECTED_CORES=$(printf "%s " "${selected_cores[@]}")
SELECTED_CORES=${SELECTED_CORES% }
export SELECTED_CORES

ALL_CORES=$(printf "%s " "${core_list[@]}")
ALL_CORES=${ALL_CORES% }
export ALL_CORES

for vf_pci_addr in "${selected_target_vf[@]}"; do
  device_mac_addresses+=("$(vf_mac_address "$vf_pci_addr")")
done

DEVICE_MAC_ADDRESSES=$(printf "%s " "${device_mac_addresses[@]}")
DEVICE_MAC_ADDRESSES=${DEVICE_MAC_ADDRESSES% }
export DEVICE_MAC_ADDRESSES

echo "Starting pkt gen selected cores \
$SELECTED_CORES selected VFs \
$SELECTED_VF device macs: \
$DEVICE_MAC_ADDRESSES"

docker run \
-e SELECTED_CORES="$SELECTED_CORES" \
-e TARGET_VFS="$SELECTED_VF" \
-e DEVICE_MAC_ADDRESSES="$DEVICE_MAC_ADDRESSES" \
-e ALLOCATE_SOCKET_MEMORY="$ALLOCATE_SOCKET_MEMORY" \
-e NUM_HUGEPAGES="$NUM_HUGEPAGES" \
-e HUGEPAGE_SIZE="$HUGEPAGE_SIZE" \
-e HUGEPAGE_MOUNT="HUGEPAGE_MOUNT" \
-e DPDK_APP="pkt_gen" \
-e DPDK_PMD_TYPE="$DPDK_PMD_TYPE" \
-e EXTRA_ARGS="$EXTRA_ARGS" \
-it --privileged --rm spyroot/pktgen_toolbox_generic:latest /start_pktgen.sh