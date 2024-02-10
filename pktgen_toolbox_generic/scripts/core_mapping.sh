#!/bin/bash


generate_core_mapping() {
    local NUM_PORTS=$1
    local SELECTED_CORES=$2
    local CORES_ARRAY CORES_PER_PORT CORES_PER_TASK CORE_MAPPING START_IDX RX_CORES TX_CORES RX_CORES_STR TX_CORES_STR

    # Convert selected cores to an array
    read -ra CORES_ARRAY <<< "$SELECTED_CORES"

    # Calculate cores per port
    CORES_PER_PORT=$(( ${#CORES_ARRAY[@]} / NUM_PORTS ))
    CORES_PER_TASK=$(( CORES_PER_PORT / 2 )) # Half for RX, half for TX

    # Initialize CORE_MAPPING
    CORE_MAPPING=""

    # Generate core mapping for each port
    for (( port=0; port<NUM_PORTS; port++ )); do
        START_IDX=$(( port * CORES_PER_PORT ))
        RX_CORES=("${CORES_ARRAY[@]:$START_IDX:$CORES_PER_TASK}")
        TX_CORES=("${CORES_ARRAY[@]:$START_IDX + CORES_PER_TASK:$CORES_PER_TASK}")

        # Convert arrays to strings
        RX_CORES_STR=$(IFS='/'; echo "${RX_CORES[*]}"; IFS=' ')
        TX_CORES_STR=$(IFS='/'; echo "${TX_CORES[*]}"; IFS=' ')

        # Adjust formatting for single port scenario
        if [ "$NUM_PORTS" -eq 1 ]; then
            CORE_MAPPING+="[${RX_CORES_STR}:${TX_CORES_STR}]"
        else
            CORE_MAPPING+="[${RX_CORES_STR}:${TX_CORES_STR}].$port"
        fi

        # Append comma between ports if not the last port
        if [ "$((port + 1))" -lt "$NUM_PORTS" ]; then
            CORE_MAPPING+=", "
        fi
    done

    echo "$CORE_MAPPING"
}

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <num_ports> <selected_cores>"
    echo "Example: $0 2 \"1 2 3 4 5 6 7 8\""
    exit 1
fi

NUM_PORTS=$1 # First argument: Number of ports
SELECTED_CORES=$2 # Second argument: Space-separated list of cores

# Convert selected cores to an array
read -ra CORES_ARRAY <<< "$SELECTED_CORES"
CORE_MAPPING=$(generate_core_mapping "$NUM_PORTS" "$SELECTED_CORES")
echo "Core mapping: -m $CORE_MAPPING"