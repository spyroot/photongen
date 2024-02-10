#!/bin/bash

source shared_functions.sh

# Function to test vf_mac_address function
# for edge cases
test_vf_mac_address() {
    local test_passed=true

    # list of inputs
    local pci_addresses=(
        "0000:03:02.2"
        "0000:03:02.0"
        "0000:03:02.4"
        ""
        "0000:03"  # partial pci
        "03:02.4"  # without 0000
      )

    # expected MAC addresses corresponding to the PCI addresses above
    local expected_mac_addresses=(
        "da:07:79:7a:69:54"
        "1a:50:a2:68:75:0b"
        "c2:3a:01:e2:c0:9c"
        ""
        ""
        "c2:3a:01:e2:c0:9c"
    )

    for ((i = 0; i < ${#pci_addresses[@]}; i++)); do

        local pci_address="${pci_addresses[$i]}"
        local expected_mac="${expected_mac_addresses[$i]}"
        local actual_mac
        actual_mac=$(vf_mac_address "$pci_address")

        # Check if the actual MAC address matches the expected MAC address
        if [ "$actual_mac" != "$expected_mac" ]; then
            echo "vf_mac_address test failed: Expected MAC address '$expected_mac' for '$pci_address'
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

# Function to test the adapter_numa function
# for edge case postive / negative etc
function test_adapter_numa() {
    local test_passed=true

    # Define an array of PCI addresses to test
    local pci_addresses=(
        "0000:03:00.0"
        "bd:00.1"
        "3f:01.0"
        "0000:44:00.0"  # Non-existing PCI address for negative test
        "0000:03"       # Partial PCI address for negative test
        "0000:03:02:"   # Invalid PCI address for negative test
        "" # Invalid NUMA node for negative test
    )

    # Define expected NUMA nodes corresponding to the PCI addresses above
    local expected_numa_nodes=(
        "0"  # NUMA node not available
        "1"  # NUMA node not available
        "2"  # NUMA node not available
        "-1" # NUMA node not available
        "-1" # NUMA node not available
        "-1" # NUMA node not available
        "-1" # NUMA node not available
        "-1"  # NUMA node not available
     )

    for ((i = 0; i < ${#pci_addresses[@]}; i++)); do
        local pci_address="${pci_addresses[$i]}"
        local expected_numa="${expected_numa_nodes[$i]}"

        local actual_numa
        actual_numa=$(adapter_numa "$pci_address")

        # Check if the actual NUMA node matches the expected NUMA node
        if [ "$actual_numa" != "$expected_numa" ]; then
            echo "adapter_numa test failed: Expected NUMA node '$expected_numa'
            but got '$actual_numa' for PCI address '$pci_address'"
            test_passed=false
        fi
    done

    if [ "$test_passed" = true ]; then
        echo "adapter_numa test passed: All tests passed successfully"
    else
        echo "adapter_numa test failed: Some tests failed"
    fi
}

# function test
function test_validate_numa() {
    local test_passed=true

    # Define an array of PCI addresses to test
    local selected_pci_addresses=(
        "0000:03:00.0"  # pf
        "00003:00.1"    # vf
        "0000:40:00.1"  # gpu in numa 2
        "0000:44:00.0"  # Non-existing PCI address for negative test
        "0000:03"       # Partial PCI address for negative test
        "0000:03:02:"   # Invalid PCI address for negative test
        "" # Invalid NUMA node for negative test
    )

    local selected_numa_nodes=(
        "0"  # Expected NUMA node for "0000:03:00.0"
        "0"  # Expected NUMA node for "bd:00.1"
        "2"  # Expected NUMA node for "3f:01.0"
        "-1" # Expected NUMA node for "0000:44:00.0"
        "-1" # Expected NUMA node for "0000:03"
        "-1" # Expected NUMA node for "0000:03:02:"
        "-1" # Expected NUMA node for ""
    )

    # Test validate_numa function
    for ((i = 0; i < ${#selected_pci_addresses[@]}; i++)); do
        local selected_pci="${selected_pci_addresses[$i]}"
        local selected_numa="${selected_numa_nodes[$i]}"

        local selected_pci_array=("$selected_pci")

        # Call the validate_numa function and capture its return code
        validate_numa "$expected_numa" selected_pci_array
        local return_code=$?

        # Check if the return code matches the expected behavior
        if [ "$expected_numa" == "-1" ] && [ $return_code -eq 0 ]; then
            echo "validate_numa test failed: Expected error for selected PCI address '$selected_pci' but function returned success"
            test_passed=false
        elif [ "$expected_numa" != "-1" ] && [ $return_code -ne 0 ]; then
            echo "validate_numa test failed: Unexpected success for selected PCI address '$selected_pci' but function returned error"
            test_passed=false
        fi
    done

    if [ "$test_passed" = true ]; then
        echo "validate_numa test passed: All tests passed successfully"
    else
        echo "validate_numa test failed: Some tests failed"
    fi

}

test_vf_mac_address
test_adapter_numa
test_validate_numa