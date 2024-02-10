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

read -ra CORES_ARRAY <<<"$SELECTED_CORES"
IFS=$'\n' SORTED_CORES=($(sort -n <<<"${CORES_ARRAY[*]}"))
unset IFS

PCI_LIST=()
for vf in $TARGET_VFS; do PCI_LIST+=("-a" "$vf")
done

NUM_PORTS=${#PCI_LIST[@]}
echo "Num ports mapping: $NUM_PORTS"
NUM_WORKER_CORES=$((${#SORTED_CORES[@]} - 1))
echo "Num worker cores mapping: $NUM_WORKER_CORES"

CORES_PER_PORT=$((NUM_WORKER_CORES / NUM_PORTS))
EXTRA_CORES=$((NUM_WORKER_CORES % NUM_PORTS))

for (( port=0; port<NUM_PORTS; port++ )); do
    # Calculate the end core index for this port
    END_CORE=$((START_CORE + CORES_PER_PORT - 1))

    # Add an extra core to this port if there are any leftovers
    if (( EXTRA_CORES > 0 )); then
        END_CORE=$((END_CORE + 1))
        EXTRA_CORES=$((EXTRA_CORES - 1))
    fi

    # Construct the core mapping for this port
    if (( port > 0 )); then
        CORE_MAPPING+=" "
    fi
    CORE_MAPPING+="[${SORTED_CORES[@]:START_CORE:END_CORE-START_CORE+1}].$port"

    # Update START_CORE for the next port
    START_CORE=$((END_CORE + 1))
done

echo "Core mapping: $CORE_MAPPING"
echo "NUM_WORKER_CORES mapping: $NUM_WORKER_CORES"

CORE_LIST=$(echo "${SORTED_CORES[*]}" | tr ' ' ',')

echo "calling pktgen with CORE_LIST: \
$CORE_LIST, PCI_LIST: ${PCI_LIST[*]}, LOG_LEVEL: $LOG_LEVEL"

#pktgen -l "$CORE_LIST" \
#-n 4 \
#--proc-type auto \
#--log-level "$LOG_LEVEL" \
#"${PCI_LIST[@]}" \
#--socket-mem
#-- -T

cmd=(pktgen -l "$CORE_LIST" -n 4 --proc-type auto --log-level "$LOG_LEVEL" "${PCI_LIST[@]}")

if [[ -n "$SOCKMEM" ]]; then
    cmd+=(--socket-mem="$SOCKMEM")
fi

cmd+=(-- -T)

if [[ -n "$EXTRA_ARGS" ]]; then
    read -ra EXTRA_ARGS_ARR <<< "$EXTRA_ARGS"
    cmd+=("${EXTRA_ARGS_ARR[@]}")
fi

echo "Executing command: ${cmd[*]}"
"${cmd[@]}"

