#!/bin/bash
# set of utility function to work with NUMA , DPDK.
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
selected_cores=$(cores_from_numa $numa_node $num_cores_to_select)

echo "cores from node $numa_node:"
for cpu in $selected_cores; do echo "$cpu"
done

core_list=$(core_list)

echo "available cores:"
for core in "${core_list[@]}"; do echo "$core"
done

