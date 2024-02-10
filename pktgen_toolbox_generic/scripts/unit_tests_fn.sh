#!/bin/bash

source shared_functions.sh

# Function to test vf_mac_address function
test_vf_mac_address() {
    local test_passed=true

    # list of inputs
    local pci_addresses=(
        # PCI address corresponds to MAC address: 74:56:3c:42:f9:88
        "0000:03:02.2"  # MAC Address: 74:56:3c:42:f9:88
        # PCI address corresponds to MAC address: 74:56:3c:42:f9:89
        "0000:03:02.0"  # MAC Address: 74:56:3c:42:f9:89
        # PCI address corresponds to MAC address: 5e:d3:25:e5:6c:f0
        "0000:03:02.4"  # MAC Address: 5e:d3:25:e5:6c:f0
        ""
      )

    # expected MAC addresses corresponding to the PCI addresses above
    local expected_mac_addresses=(
        "da:07:79:7a:69:54"
        "1a:50:a2:68:75:0b"
        "c2:3a:01:e2:c0:9c"
        ""
        ""  # Empty string for non-existing PCI address
    )


    for ((i = 0; i < ${#pci_addresses[@]}; i++)); do

        local pci_address="${pci_addresses[$i]}"
        local expected_mac="${expected_mac_addresses[$i]}"
        local actual_mac
        actual_mac=$(vf_mac_address "$pci_address")

        # Check if the actual MAC address matches the expected MAC address
        if [ "$actual_mac" != "$expected_mac" ]; then
            echo "vf_mac_address test failed: Expected MAC address '$expected_mac'
            but got '$actual_mac' for PCI address '$pci_address'"
            test_passed=false
        fi
    done

    if [ "$test_passed" = true ]; then
        echo "vf_mac_address test passed: All tests passed successfully"
    else
        echo "vf_mac_address test failed: Some tests failed"
    fi
}

# Run the test
test_vf_mac_address