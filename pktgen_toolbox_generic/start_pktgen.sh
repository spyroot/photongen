#!/bin/bash

TARGET_VFS="0000:03:02.6 0000:03:02.7"
SELECTED_CORES="58 53 9 2"
DPDK_PMD_TYPE="vfio-pci"

# Bind each target VF to the specified PMD
for vf in $TARGET_VFS; do
    echo "Binding $vf to $DPDK_PMD_TYPE"
    dpdk-devbind.py --bind="$DPDK_PMD_TYPE" "$vf"
done

CORE_LIST=$(echo "$SELECTED_CORES" | tr ' ' ',')
# Construct the PCI device list for pktgen
PCI_LIST=""
for vf in $TARGET_VFS; do
    PCI_LIST+="-a $vf "
done

echo "$CORE_LIST"
echo "$PCI_LIST"
