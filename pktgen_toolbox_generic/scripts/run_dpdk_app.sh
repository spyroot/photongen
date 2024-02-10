#!/bin/bash
# This a generic ELA wrapper.  Most of all DPDK app require
#
# a) list of core
# b) list of DPDK device
# c) huge pages allocated for app
# d) some sort of mapping core to port , or nxCore to TX and RX etc
# e) number of memory channel
# f) NUMA mapping.
#
# Hence this a generic wrapper that you can call before ELA
# - to select N random core from a given NUMA
# - to select N random VF from a some PF ( or consider all PFs)
# - pass to a container original MAC ( note container doesn't need to bind to DPDK)
#   if OS already did bind ( Multus CNI etc) do that. it a bit hard to get MAC hence we need
#   to see initial what kernel located via kernel driver
#   hence based on SELECTED VF we construct SELECTED MAC
#
# - Memory that we want to pass. i.e a memory for particular
#   socket from where we selected cores
#
# if you want to enable NUMA pass in extra -N
# if you want to enable socket support using default server values localhost:0x5606 pass -G
# Autor Mus spyroot@gmail.com

# from numa 0, select 4 cores at random
numa_node=0
num_cores_to_select=9
num_vf_to_select=2

# our PF
BUS_FILTER="0000:03"
ALLOCATE_SOCKET_MEMORY=1024
DPDK_PMD_TYPE=vfio-pci

# since we using 2 port we allocate
NUM_HUGEPAGES=${NUM_HUGEPAGES:-8192}
HUGEPAGE_SIZE=${HUGEPAGE_SIZE:-2048}
NUM_CHANNELS=${HUGEPAGE_SIZE:-2}
HUGEPAGE_MOUNT=${HUGEPAGE_MOUNT:-/mnt/huge}
SOCKET_MEMORY=1024,0,0,0
DPDK_APP=${DPDK_APP:-pktgen}

source shared_functions.sh

# Display help message
usage() {
    echo "Usage: $0 [options] [-- extra_arguments]"
    echo "Options:"
    echo "  -a <DPDK_APP>                  DPDK application (default: $DPDK_APP)"
    echo "  -n <numa_node>                 NUMA node to select cores from (default: $numa_node)"
    echo "  -c <num_cores_to_select>       Number of cores to select (default: $num_cores_to_select)"
    echo "  -v <num_vf_to_select>          Number of VFs to select (default: $num_vf_to_select)"
    echo "  -b <BUS_FILTER>                BUS filter for selecting VFs (default: $BUS_FILTER)"
    echo "  -m <ALLOCATE_SOCKET_MEMORY>    Memory to allocate per socket in MB (default: $ALLOCATE_SOCKET_MEMORY)"
    echo "  -p <DPDK_PMD_TYPE>             DPDK PMD type (default: $DPDK_PMD_TYPE)"
    echo "  -g <NUM_HUGEPAGES>             Number of hugepages (default: $NUM_HUGEPAGES)"
    echo "  -s <HUGEPAGE_SIZE>             Hugepage size in kB (default: $HUGEPAGE_SIZE)"
    echo "  -t <HUGEPAGE_MOUNT>            Hugepage mount point (default: $HUGEPAGE_MOUNT)"
    echo "  -h                             Display this help and exit"
    echo "You can specify extra arguments to be passed to the DPDK application"
    echo "using '--' followed by the arguments, or by setting the EXTRA_ARGS"
    echo "Example we want pass -N to pkt gen '-- -N' or we set an EXTRA_ARGS"
    echo "export EXTRA_ARGS=\"-n\"  we want pass -N to pkt gen '-- -N' or we set an EXTRA_ARGS"
    echo "environment variable."

    exit 1
}

# parse command-line options
while getopts "a:n:c:v:b:m:p:g:s:t:h" opt; do
    case ${opt} in
        n) numa_node=${OPTARG} ;;
        c) num_cores_to_select=${OPTARG} ;;
        v) num_vf_to_select=${OPTARG} ;;
        b) BUS_FILTER=${OPTARG} ;;
        m) ALLOCATE_SOCKET_MEMORY=${OPTARG} ;;
        a) DPDK_APP=${OPTARG} ;;
        p) DPDK_PMD_TYPE=${OPTARG} ;;
        g) NUM_HUGEPAGES=${OPTARG} ;;
        s)
            if [[ ${OPTARG} == "1G" || ${OPTARG} == "2048" ]]; then
                HUGEPAGE_SIZE=${OPTARG}
            else
                echo "Error: Invalid hugepage size specified. Please use either '1G' or '2048'." >&2
                exit 1
            fi
            ;;
          t) HUGEPAGE_MOUNT=${OPTARG} ;;
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
                    | grep "$DPDK_PMD_TYPE" | grep Virtual)"

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

# Function to retrieve NUMA node information for a given PCI address
# Args:
#   $1: PCI address of the adapter
# Outputs:
#   Prints the NUMA node information for the adapter
function adapter_numa() {
    local _pci_addr=$1
    local adapter_numa_node=$(lspci -v -s "$_pci_addr" 2>/dev/null | grep "NUMA node" | awk '{print $6}' | tr -d ',')
    if [ -z "$adapter_numa_node" ]; then
        echo "-1"
    elif [[ "$adapter_numa_node" =~ ^[0-4]$ ]]; then
        echo "$adapter_numa_node"
    else
        echo "-1"
    fi
}

# This function selects a specified number
# of random CPU cores from a given NUMA node.
# Use prefect multiplier for example one core per TX and RX on each port
# for 2 port it 9 core total 1 for master 8 spread 1/2:3/4 and port 2 5/6:7/8
function cores_from_numa() {
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

# Function to check if all network adapters are in the specified NUMA node
# Args:
#   $1: Selected NUMA node
#   $2: Array of selected network adapter PCI addresses
# Outputs:
#   Prints an error message if any adapter is not in the specified NUMA node
function validate_numa() {
    local selected_numa=$1
    local -n adapters=$2

    for adapter in "${adapters[@]}"; do
        local adapter_numa=$(adapter_numa "$adapter")
        if [[ "$adapter_numa" != "$selected_numa" ]]; then
            echo "Error: Adapter $adapter is not in NUMA node $selected_numa" >&2
            exit 1
        fi
    done
}

if [[ ! $numa_node =~ ^[0-9]+$ ]]; then
    echo "Error: NUMA node must be a positive integer." >&2
    usage
fi

if [[ ! $num_cores_to_select =~ ^[0-9]+$ || $num_cores_to_select -lt 1 ]]; then
    echo "Error: Number of cores to select must be a positive integer." >&2
    usage
fi

if [[ ! $num_vf_to_select =~ ^[0-9]+$ || $num_vf_to_select -lt 1 ]]; then
    echo "Error: Number of VFs to select must be a positive integer." >&2
    usage
fi

if [[ ! $NUM_HUGEPAGES =~ ^[0-9]+$ || $NUM_HUGEPAGES -lt 1 ]]; then
    echo "Error: Number of hugepages must be a positive integer." >&2
    usage
fi

if [[ $HUGEPAGE_SIZE != "1G" && $HUGEPAGE_SIZE != "2048" ]]; then
    echo "Error: Invalid hugepage size specified. Please use either '1G' or '2048'." >&2
    usage
fi

if ! numactl -H | grep -q "node $numa_node "; then
    echo "Error: NUMA node $numa_node does not exist on the system." >&2
    exit 1
fi

declare -a selected_target_vf
declare -a device_mac_addresses

core_list=$(core_list)
selected_cores=$(cores_from_numa "$numa_node" "$num_cores_to_select")
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

# we pass mac address downstream
DEVICE_MAC_ADDRESSES=$(printf "%s " "${device_mac_addresses[@]}")
DEVICE_MAC_ADDRESSES=${DEVICE_MAC_ADDRESSES% }
export DEVICE_MAC_ADDRESSES

echo "Starting pkt gen selected cores \
$SELECTED_CORES selected VFs \
$SELECTED_VF device macs: \
$DEVICE_MAC_ADDRESSES"

if ! command -v dmidecode &> /dev/null; then
    echo "Error: dmidecode is not installed. Please install dmidecode and try again."
    exit 1
fi

# calculate number of memory channel
NUM_CHANNELS=$(dmidecode -t memory dmidecode -t memory 2>/dev/null \
| grep "Locator:" | grep Bank | sort -u | wc -l)

#read -ra NUMAS_ARRAY <<<"$NUMAS"

# re-adjust memory
case $numa_node in
    0)
        SOCKET_MEMORY="$ALLOCATE_SOCKET_MEMORY,0,0,0"
        ;;
    1)
        SOCKET_MEMORY="0,$ALLOCATE_SOCKET_MEMORY,0,0"
        ;;
    2)
        SOCKET_MEMORY="0,0,$ALLOCATE_SOCKET_MEMORY,0"
        ;;
    3)
        SOCKET_MEMORY="0,0,0,$ALLOCATE_SOCKET_MEMORY"
        ;;
    *)
        echo "Error: Unsupported NUMA node: $numa_node" >&2
        exit 1
        ;;
esac

if (( numa_node > 0 )); then
    case $numa_node in
        1) SOCKETS="1" ;;
        2) SOCKETS="2" ;;
        3) SOCKETS="3" ;;
        *) echo "Warning: Unsupported NUMA node value. Defaulting to original SOCKET_MEMORY." ;;
    esac
fi


validate_numa "$numa_node" selected_target_vf

docker_run_command=(docker run \
-e SELECTED_CORES="$SELECTED_CORES" \
-e TARGET_VFS="$SELECTED_VF" \
-e DEVICE_MAC_ADDRESSES="$DEVICE_MAC_ADDRESSES" \
-e ALLOCATE_SOCKET_MEMORY="$ALLOCATE_SOCKET_MEMORY" \
-e NUM_HUGEPAGES="$NUM_HUGEPAGES" \
-e HUGEPAGE_SIZE="$HUGEPAGE_SIZE" \
-e HUGEPAGE_MOUNT="$HUGEPAGE_MOUNT" \
-e DPDK_APP="$DPDK_APP" \
-e DPDK_PMD_TYPE="$DPDK_PMD_TYPE" \
-e SOCKET_MEMORY="$SOCKET_MEMORY" \
-e EXTRA_ARGS="$EXTRA_ARGS" \
-e NUM_CHANNELS="$NUM_CHANNELS" \
-e NUMAS="$SOCKETS" \
-it --privileged \
--rm spyroot/pktgen_toolbox_generic:latest /start_dpdk_app.sh)

# Execute the docker run command
"${docker_run_command[@]}"