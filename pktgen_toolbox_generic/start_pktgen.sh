#!/bin/bash
# This a generic ELA wrapper receiver side.
#
# Most of all DPDK app require
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

# Check for environment variables and use defaults if not provided
NUM_HUGEPAGES=${NUM_HUGEPAGES:-1024}
HUGEPAGE_SIZE=${HUGEPAGE_SIZE:-2048}  # Size in kB
HUGEPAGE_MOUNT=${HUGEPAGE_MOUNT:-/mnt/huge}
LOG_LEVEL=${LOG_LEVEL:-7}

# Check if hugepage mount directory exists, if not create it
if [ ! -d "$HUGEPAGE_MOUNT" ]; then
	mkdir -p "$HUGEPAGE_MOUNT"
fi

# Allocate hugepages
echo "$NUM_HUGEPAGES" > /sys/kernel/mm/hugepages/hugepages-"${HUGEPAGE_SIZE}"kB/nr_hugepages

# Check if hugetlbfs is already mounted at the specified directory
if ! mountpoint -q "$HUGEPAGE_MOUNT"; then
	# Mount the hugetlbfs
	mount -t hugetlbfs nodev "$HUGEPAGE_MOUNT"
fi

echo "Hugepages allocated and mounted successfully:"

# Bind each target VF to the specified PMD
for vf in $TARGET_VFS; do
	echo "Binding $vf to $DPDK_PMD_TYPE"
	dpdk-devbind.py --bind="$DPDK_PMD_TYPE" "$vf"
done

CORE_LIST=$(echo "$SELECTED_CORES" | tr ' ' ',')
PCI_LIST=""
for vf in $TARGET_VFS; do
	PCI_LIST+="-a $vf "
done

echo "pktgen -l "$CORE_LIST" \
-n 4 \
--proc-type auto \
--log-level "$LOG_LEVEL" \
-a "$PCI_LIST" \
-- -T"

