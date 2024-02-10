#!/bin/bash

function select_vf_dpdk {
    local DPDK_PMD_TYPE="vfio-pci"
    local BUS_FILTER="$1"

    local output="$(docker run -it --privileged --rm spyroot/pktgen_toolbox_generic:latest dpdk-devbind.py -s | grep $DPDK_PMD_TYPE | grep Virtual)"
    local pci_devices
    readarray -t pci_devices <<< "$(echo "$output" | awk '/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]/ {print $1}')"

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

# Usage example:
# To call this function without filter
# select_vf_dpdk

# To call this function with a bus filter, e.g., 0000:03
select_vf_dpdk 0000:03
