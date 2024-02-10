# Function to return mac address of device
# Note: If the device is already bound to DPDK, this is the most reliable way to get its MAC address
function vf_mac_address() {
    local _pci_address=$1
    local _mac_address

    # Check if the PCI address matches the expected format (0000:XX:XX.X)
    if [[ $_pci_address =~ ^0000:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]{1}$ ]]; then
        _mac_address=$(dmesg | grep "$_pci_address" | grep 'MAC' | awk '{print $NF}' | grep -Eo '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}' | tail -n 1)
        echo "$_mac_address"
    else
        echo "Invalid PCI address format: $_pci_address"
        return 1
    fi
}
