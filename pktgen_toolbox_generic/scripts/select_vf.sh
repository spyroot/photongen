#!/bin/bash

DPDK_PMD_TYPE="vfio-pci"

# select vf DPDK cable
output="$(docker run -it --privileged --rm spyroot/pktgen_toolbox_generic:latest dpdk-devbind.py -s | grep $DPDK_PMD_TYPE | grep Virtual)"
readarray -t pci_devices <<< "$(echo "$output" | awk '/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]/ {print $1}')"

for pci in "${pci_devices[@]}"; do
	echo "$pci"
done

