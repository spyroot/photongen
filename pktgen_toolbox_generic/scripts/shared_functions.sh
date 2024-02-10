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

    if [[ $_pci_address =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{1,2}$ ]]; then
        # Prepend "0000" to the PCI address
        _pci_address="0000:${_pci_address}"
    fi

    _mac_address=$(dmesg | grep "$_pci_address" | \
    grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
    echo "$_mac_address"
}
