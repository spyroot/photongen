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
    for adapter in "${adapters[@]}"; do
        local adapter_numa
        adapter_numa=$(adapter_numa "$adapter")
        if [[ "$adapter_numa" != "$selected_numa" ]]; then
            echo "Error: Adapter $adapter is not in NUMA node $selected_numa" >&2
            exit 1
        fi
    done
}


# This function selects a specified number
# of random CPU cores from a given NUMA node.
# Use prefect multiplier for example one core per TX and RX on each port
# for 2 port it 9 core total 1 for master 8 spread 1/2:3/4 and port 2 5/6:7/8
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