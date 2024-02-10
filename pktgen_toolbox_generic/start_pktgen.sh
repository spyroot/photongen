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

# This function spread all cores expect allocate to master
# to all ports note it spread evently so each tx and rx get
# same number of cores on each port.
generate_core_mapping() {
    local NUM_PORTS=$1
    local SELECTED_CORES=$2
    local CORES_ARRAY CORES_PER_PORT CORES_PER_TASK CORE_MAPPING START_IDX RX_CORES TX_CORES RX_CORES_STR TX_CORES_STR

    #  to an array
    read -ra CORES_ARRAY <<< "$SELECTED_CORES"

    CORES_PER_PORT=$(( ${#CORES_ARRAY[@]} / NUM_PORTS ))
    # Half for RX, half for TX
    CORES_PER_TASK=$(( CORES_PER_PORT / 2 ))

    CORE_MAPPING=""

    # Generate core mapping for each port
    for (( port=0; port<NUM_PORTS; port++ )); do
        START_IDX=$(( port * CORES_PER_PORT ))
        RX_CORES=("${CORES_ARRAY[@]:$START_IDX:$CORES_PER_TASK}")
        TX_CORES=("${CORES_ARRAY[@]:$START_IDX + CORES_PER_TASK:$CORES_PER_TASK}")

        RX_CORES_STR=$(IFS='/'; echo "${RX_CORES[*]}"; IFS=' ')
        TX_CORES_STR=$(IFS='/'; echo "${TX_CORES[*]}"; IFS=' ')

        # Adjust formatting for single port scenario
        if [ "$NUM_PORTS" -eq 1 ]; then
            CORE_MAPPING+="[${RX_CORES_STR}:${TX_CORES_STR}]"
        else
            CORE_MAPPING+="[${RX_CORES_STR}:${TX_CORES_STR}].$port"
        fi

        if [ "$((port + 1))" -lt "$NUM_PORTS" ]; then
            CORE_MAPPING+=", "
        fi
    done

    echo "$CORE_MAPPING"
}

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
echo "Hugepages allocated and mounted successfully:"
echo "Number of hugepages: $(< /sys/kernel/mm/hugepages/hugepages-"${HUGEPAGE_SIZE}"kB/nr_hugepages)"
echo "Total size of hugepages: $(( $(< /sys/kernel/mm/hugepages/hugepages-"${HUGEPAGE_SIZE}"kB/nr_hugepages) * HUGEPAGE_SIZE / 1024 )) MB"

# Additionally, you can show the current hugepages settings from /proc/meminfo
echo "Current hugepages settings from /proc/meminfo:"
grep -i hugepages /proc/meminfo

# Bind each target VF to the specified PMD
for vf in $TARGET_VFS; do
	echo "Binding $vf to $DPDK_PMD_TYPE"
	dpdk-devbind.py --bind="$DPDK_PMD_TYPE" "$vf"
done

PCI_LIST=()
for vf in $TARGET_VFS; do PCI_LIST+=("-a" "$vf")
done
NUM_PORTS=$(( ${#PCI_LIST[@]} / 2 ))

echo "Num ports mapping: $NUM_PORTS"
read -ra CORES_ARRAY <<<"$SELECTED_CORES"
IFS=$'\n' SORTED_CORES=($(sort -n <<<"${CORES_ARRAY[*]}"))
unset IFS

NUM_WORKER_CORES=$((${#SORTED_CORES[@]} - 1))
WORKER_CORES=("${SORTED_CORES[@]:1:$NUM_WORKER_CORES}")
SELECTED_WORKER_CORES=$(IFS=' '; echo "${WORKER_CORES[*]}"; IFS=$'\n')
CORE_MAPPING=$(generate_core_mapping "$NUM_PORTS" "$SELECTED_WORKER_CORES")

echo "Num worker cores mapping: $NUM_WORKER_CORES"
echo "Core mapping: $CORE_MAPPING"

CORE_LIST=$(echo "${SORTED_CORES[*]}" | tr ' ' ',')

echo "calling pktgen with CORE_LIST: \
$CORE_LIST, PCI_LIST: ${PCI_LIST[*]}, LOG_LEVEL: $LOG_LEVEL"

cmd=(pktgen -l "$CORE_LIST" -n 1 --proc-type auto --log-level "$LOG_LEVEL" "${PCI_LIST[@]}")

if [[ -n "$SOCKET_MEMORY" ]]; then
    cmd+=(--socket-mem="$SOCKET_MEMORY")
fi

if [[ -n "$ALLOCATE_SOCKET_MEMORY" ]]; then
    cmd+=(-m="$ALLOCATE_SOCKET_MEMORY")
fi

cmd+=(-- -T)
cmd+=(-m "$CORE_MAPPING")

if [[ -n "$EXTRA_ARGS" ]]; then
    read -ra EXTRA_ARGS_ARR <<< "$EXTRA_ARGS"
    cmd+=("${EXTRA_ARGS_ARR[@]}")
fi

echo "Executing command: ${cmd[*]}"
"${cmd[@]}"

