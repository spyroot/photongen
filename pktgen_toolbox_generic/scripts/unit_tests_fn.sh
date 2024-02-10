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


function test_validate_numa() {
    local test_passed=true

    # positive case all adapter in numa 0 for numa 0 ok for any other numa not ok
    local positive_case_pci01=(
        "0000:03:00.0"  # pf
        "00003:00.1"    # vf
    )

    # single device in numa 2, for numa 2 should be ok for other numa not ok
    local positive_case_pci02=(
        "0000:40:00.1"  # gpu in numa 2
    )

    # negative case one device in numa 2, for numa 0 should be not ok
    local negative_case_pci01=(
        "0000:03:00.0"  # pf
        "00003:00.1"    # vf
        "0000:40:00.1"  # gpu in numa 2
    )

    # negative case one device empty for numa 0 should return error
    local negative_case_pci02=(
        "0000:03:00.0"  # pf
        "00003:00.1"    # vf
        ""
    )

    # negative case array empty for numa should return 0
    local negative_case_pci03=(
        ""
    )

    local positive_case_numa_numa01="0"  # Expected NUMA node for positive case 1
    local positive_case_numa_numa02="2"  # Expected NUMA node for positive case 2

    local negative_case_numa="0"  # NUMA node for negative cases

    # Test validate_numa function for positive cases
    validate_numa "$positive_case_numa_numa01" "${positive_case_pci01[@]}"
    if [ $? -ne 0 ]; then
        echo "validate_numa test failed: Expected success for positive case 1 but function returned error"
        test_passed=false
    fi

    validate_numa "$positive_case_numa_numa02" "${positive_case_pci02[@]}"
    if [ $? -ne 0 ]; then
        echo "validate_numa test failed: Expected success for positive case 2 but function returned error"
        test_passed=false
    fi

    # Test validate_numa function for negative cases
    validate_numa "$negative_case_numa" "${negative_case_pci01[@]}"
    if [ $? -eq 0 ]; then
        echo "validate_numa test failed: Expected error for negative case 1 but function returned success"
        test_passed=false
    fi

    validate_numa "$negative_case_numa" "${negative_case_pci02[@]}"
    if [ $? -eq 0 ]; then
        echo "validate_numa test failed: Expected error for negative case 2 but function returned success"
        test_passed=false
    fi

    validate_numa "$negative_case_numa" "${negative_case_pci03[@]}"
    if [ $? -ne 0 ]; then
        echo "validate_numa test failed: Expected success for negative case 3 but function returned error"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        echo "validate_numa test passed: All tests passed successfully"
    else
        echo "validate_numa test failed: Some tests failed"
    fi
}


function test_validate_numa() {
    local test_passed=true

    # positive case all adapter in numa 0 for numa 0 ok for any other numa not ok
    local positive_case_pci01=(
        "000003000"  # pf
        "000003001"  # vf
    )

    local positive_case_numa_numa01="0"  # Expected NUMA node for positive case 1

    local selected_pci=("${positive_case_pci01[@]}")

    # Test validate_numa function for positive case
    validate_numa "$positive_case_numa_numa01" "${selected_pci[@]}"
    if [ $? -ne 0 ]; then
        echo "validate_numa test failed: Expected success for positive case 1 but function returned error"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        echo "validate_numa test passed: All tests passed successfully"
    else
        echo "validate_numa test failed: Some tests failed"
    fi
}


test_validate_numa
##test_vf_mac_address
##test_adapter_numa
##test_validate_numa
#
## positive case all adapter in numa 0 for numa 0 ok for any other numa not ok
#positive_case_pci01=(
#    "000003000"  # pf
#    "000003001"  # vf
#)
#
#
#positive_case_numa_numa01="0"  # Expected NUMA node for positive case 1
#validate_numa "$positive_case_numa_numa01" "${positive_case_pci01[@]}"
