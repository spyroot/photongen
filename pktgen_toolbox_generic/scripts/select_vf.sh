#!/bin/bash
# Select a VF DPDK.

DPDK_PMD_TYPE="vfio-pci"
BUS_FILTER="$1"

output="$(docker run -it --privileged --rm spyroot/pktgen_toolbox_generic:latest dpdk-devbind.py -s | grep $DPDK_PMD_TYPE | grep Virtual)"
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
