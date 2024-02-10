# Function return mac address of device
# note if device already bounded to DPDK this is most reliable way to get it
function vf_mac_address() {
    local _pci_address=$1
    local _mac_address

    if [ -z "$_pci_address" ]; then
        # Return an empty string
        echo ""
        return
    fi

    # Validate full PCI address format (0000:XX:XX.X)
    if [[ $_pci_address =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]{1}$ ]]; then
        _mac_address=$(dmesg | grep -E "${_pci_address}(\.[0-9a-fA-F]{2}){2}\b" | \
        grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
    # Validate partial PCI address format (XX:XX.X)
    elif [[ $_pci_address =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]{1}$ ]]; then
        _pci_address="0000:$_pci_address"
        _mac_address=$(dmesg | grep -E "${_pci_address}(\.[0-9a-fA-F]{2}){2}\b" | \
        grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
    else
        echo "Invalid PCI address format: $_pci_address"
        return 1
    fi

    echo "$_mac_address"

}
