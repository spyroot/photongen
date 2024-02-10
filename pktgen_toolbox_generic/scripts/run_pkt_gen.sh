#!/bin/bash
# Set of utility function to work with NUMA , DPDK and pktgen
#
# Autor Mus spyroot@gmail.com

# Select vf based on PMD driver and PMD BUS
# Note this function uses container ( you change to dpdk-devbind.py
function select_vf_dpdk {
    local DPDK_PMD_TYPE="vfio-pci"
    local BUS_FILTER="$1"

    local output="$(docker run -it --privileged --rm \
                    spyroot/pktgen_toolbox_generic:latest dpdk-devbind.py -s | grep $DPDK_PMD_TYPE | grep Virtual)"

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

# from numa 0, select 4 cores at random
numa_node=0
num_cores_to_select=4
num_vf_to_select=2
BUS_FILTER="0000:03"

declare -a selected_target_vf

core_list=$(core_list)
selected_cores=$(cores_from_numa $numa_node $num_cores_to_select)
readarray -t selected_vf < <(select_vf_dpdk "$BUS_FILTER")

for i in $(shuf -i 0-$((${#selected_vf[@]}-1)) -n "$num_vf_to_select"); do
  selected_target_vf+=("${selected_vf[$i]}")
done

echo "cores from node $numa_node:"
for cpu in $selected_cores; do echo "$cpu"
done

echo "available cores:"
for core in "${core_list[@]}"; do echo "$core"
done

echo "Selected VF(s):"
for vf in "${selected_target_vf[@]}"; do echo "$vf"; done

SELECTED_VF=$(printf "%s " "${selected_target_vf[@]}")
SELECTED_VF=${SELECTED_VF% }
export SELECTED_VF

SELECTED_CORES=$(printf "%s " "${selected_cores[@]}")
SELECTED_CORES=${SELECTED_CORES% }
export SELECTED_CORES

ALL_CORES=$(printf "%s " "${core_list[@]}")
ALL_CORES=${ALL_CORES% }
export ALL_CORES


echo "Starting pkt gen selected cores $SELECTED_CORES selected VFs $SELECTED_VF"

#echo "$selected_target_vf"
#docker run \
#-e SELECTED_CORES=""$selected_cores"" \
#-e TARGET_VFS="$selected_vfs"
#-it --privileged --rm \
#spyroot/pktgen_toolbox_generic:latest:latest run_pktgen.sh

#pktgen \
#-l 2-14 -n 4 --proc-type auto --log-level 7 --file-prefix pg -a 0000:23:02.0 -- -T -m "[4-7:10-13].0"
