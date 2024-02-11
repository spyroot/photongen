# Function to return mac address of device, it resolve from dmesg
# initial how kernel detected adapter.
# Args:
#   $1: adapter pci address
# Outputs:
#   adapter mac address
# Note: If the device is already bound to DPDK, this is the most reliable way to get its MAC address
function vf_mac_address() {
    local _pci_address=$1
    local _mac_address

    if [[ $_pci_address =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]{1}$ ]]; then
        _pci_address="0000:$_pci_address"
    fi

    # Check if the PCI address matches the expected format (0000:XX:XX.X)
    if [[ $_pci_address =~ ^0000:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]{1}$ ]]; then
        _mac_address=$(dmesg | grep "$_pci_address" | grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
        echo "$_mac_address"
    else
        echo ""
    fi
}

# Function to retrieve NUMA node information for a given PCI address
# Args:
#   $1: PCI address of the adapter
# Outputs:
#   Prints the NUMA node information for the adapter
function adapter_numa() {
    local _pci_addr=$1
    local adapter_numa_node
    adapter_numa_node=$(lspci -v -s "$_pci_addr" 2>/dev/null | sed -n '/NUMA node/{s/.*NUMA node \([0-9]\{1,\}\).*/\1/p}')
    if [ -z "$adapter_numa_node" ]; then
        echo "-1"
    elif [[ "$adapter_numa_node" =~ ^[0-4]$ ]]; then
        echo "$adapter_numa_node"
    else
        echo "-1"
    fi
}

# Function to check if all network adapters are in the specified NUMA node
# Args:
#   $1: Selected NUMA node
#   $2: Array of selected network adapter PCI addresses
# Outputs:
#   Prints an error message if any adapter is not in the specified NUMA node
function validate_numa() {
    local selected_numa=$1
    local -n adapters=$2

    # if the array of adapters is empty
    if [ ${#adapters[@]} -eq 0 ]; then
        echo "Error: Empty array of network adapters" >&2
        return 1
    fi


    for adapter in "${adapters[@]}"; do
        local adapter_numa
        adapter_numa=$(adapter_numa "$adapter")
        if [[ "$adapter_numa" != "$selected_numa" ]]; then
            echo "Error: Adapter $adapter is not in NUMA node $selected_numa" >&2
            return 1
        fi
    done

  return 0
}

# Function to retrieve the list of CPU cores belonging to a specific NUMA node.
#
# Arguments:
#   $1: The NUMA node to retrieve CPU cores for.
#
# Returns:
#   On success, it returns an array containing the CPU cores.
#   On failure, it prints an error message and exits with status 1.
#
# Example Usage:
#   get_cores_for_numa 0  # Retrieve CPU cores for NUMA node 0.
#   get_cores_for_numa 1  # Retrieve CPU cores for NUMA node 1.
function cores_in_numa() {
    local _numa_node=$1
    local numa_cores

    if [[ ! "$_numa_node" =~ ^[0-9]+$ ]]; then
      echo "Error: Invalid NUMA node argument '$_numa_node'. NUMA node must be a non-negative integer." >&2
      return 1
    fi

    numa_cores=$(numactl -H | grep -E "^node $_numa_node cpus:" | cut -d: -f2)

    local numa_core_array=()
    read -r -a numa_core_array <<< "$numa_cores"
    echo "${numa_core_array[@]}"
}

# Function to retrieve a list of all NUMA nodes available on the system.
#
# Usage: numa_nodes
#
# Returns:
#   An array containing the list of all NUMA nodes available on the system.
#
# Example Usage:
#   numa_nodes=($(get_numa_nodes))
#   echo "Available NUMA nodes: ${numa_nodes[@]}"
function numa_nodes() {
    local numa_nodes_str
    numa_nodes_str=$(numactl -H | grep -oP '(?<=node )\d+' | uniq)
    read -r -a numa_nodes <<< "$numa_nodes_str"
    echo "${numa_nodes[@]}"
}

# This function selects a specified number cores
# at random from a given CPU numa node.
#
# Use prefect multiplier for example one core per TX and RX on each port
# for 2 port it 9 core total 1 for master 8 spread 1/2:3/4 and port 2 5/6:7/8
# Arguments:
#   $1: The NUMA node from which to select CPU cores.
#   $2: The number of CPU cores to select.
#
# Returns:
#   On success, it returns a space-separated string of selected CPU cores.
#   On failure, it returns an error message and exits with status 1.
#
# Example Usage:
#   cores_from_numa 0 4  # Select 4 random CPU cores from NUMA node 0.
#   cores_from_numa 1 8  # Select 8 random CPU cores from NUMA node 1.

function cores_from_numa() {
	local _numa_node=$1
	local _num_cores_to_select=$2
	local cpu_list_str

	cpu_list_str=$(numactl -H | grep -E "^node $_numa_node cpus:" | cut -d: -f2)
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

function array_contains() {
    local element="$1"
    shift
    local array=("$@")

    for item in "${array[@]}"; do
        if [ "$item" == "$element" ]; then
            return 0 # true
        fi
    done

    return 1 # false
}


# Function to check if all CPU cores belong to a specific NUMA node
# Args:
#   $1: Selected NUMA node
#   $2: Array of selected CPU cores
# Outputs:
#   Returns true (0) if all cores belong to the specified NUMA node, otherwise false (1)
function is_cores_in_numa() {
    local selected_numa=$1
    local -a cores=(${2}) # Assuming $2 is a space-separated string of cores

    # Handle empty core list scenario
    if [[ -z "$cores_string" ]]; then
        echo "Error: Empty core list for NUMA $selected_numa"
        return 1 # false
    else
        read -r -a cores <<< "$cores_string"
    fi

    local numa_cores
    numa_cores=$(cores_in_numa "$selected_numa")
    IFS=' ' read -r -a numa_cores_arr <<< "$numa_cores"

    for core in "${cores[@]}"; do
        if ! [[ " ${numa_cores_arr[*]} " =~ " ${core} " ]]; then
            return 1 # false
        fi
    done

    return 0 # true
}


# Function to mask CPU cores that belong to a specific NUMA node.
#
# Arguments:
#   $1: The NUMA node to check against.
#   $2: An array of CPU cores to be masked.
#
# Returns:
#   On success, it returns a space-separated string of CPU cores after masking.
#   On failure, it prints an error message and exits with status 1.
#
# Example Usage:
#   mask_cores_from_numa 0 "${core_list[@]}"  # Mask CPU cores in NUMA node 0.
#   mask_cores_from_numa 1 "${core_list[@]}"  # Mask CPU cores in NUMA node 1.

function mask_cores_from_numa() {
    local _numa_node=$1
    shift  # Remove the NUMA node argument from the parameter list
    local _core_list=("$@")


    local numa_core_array=($(cores_in_numa "$_numa_node"))
    IFS=' ' read -r -a numa_cores_arr <<< "$numa_cores"

    # Iterate through the given CPU core list and mask the cores that belong to the NUMA node
    local masked_cores=()
    for core in "${_core_list[@]}"; do
        local core_in_numa=false
        for numa_core in "${numa_core_array[@]}"; do
            if [[ "$core" == *"$numa_core"* ]]; then
                core_in_numa=true
                break
            fi
        done
        # Add the core to the masked_cores array if it does not belong to the NUMA node
        if ! $core_in_numa; then
            masked_cores+=("$core")
        fi
    done

    echo "${masked_cores[@]}"
}