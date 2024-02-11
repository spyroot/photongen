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

    local empty_array=()  # Empty array of network adapters
    local invalid_numa="invalid_numa"  # Invalid NUMA node
    local mixed_numa=(
        "0000:03:00.0"  # pf in numa 0
        "0000:40:00.1"  # gpu in numa 2
    )

    local mixed_numa2=(
        "0000:40:00.1"  # gpu in numa 2
        "0000:03:00.0"  # pf in numa 0
    )

    # Test validate_numa function for positive cases
    if ! validate_numa "$positive_case_numa_numa01" positive_case_pci01; then
        echo "validate_numa test failed: Expected success for positive case 1 but function returned error"
        test_passed=false
    fi

    if ! validate_numa "$positive_case_numa_numa02" positive_case_pci02; then
        echo "validate_numa test failed: Expected success for positive case 2 but function returned error"
        test_passed=false
    fi

    # Test validate_numa function for negative cases
    if validate_numa "$negative_case_numa" negative_case_pci01; then
        echo "validate_numa test failed: Expected error for negative case 1 but function returned success"
        test_passed=false
    fi

    if validate_numa "$negative_case_numa" negative_case_pci02; then
        echo "validate_numa test failed: Expected error for negative case 2 but function returned success"
        test_passed=false
    fi

    validate_numa "$negative_case_numa" negative_case_pci03
    if validate_numa "$negative_case_numa" negative_case_pci03; then
        echo "validate_numa test failed: Expected success for negative case 3 but function returned error"
        test_passed=false
    fi

    if validate_numa "$negative_case_numa" empty_array; then
        echo "validate_numa test failed: Expected error for empty array case 4 but function returned success"
        test_passed=false
    fi

    if validate_numa "$invalid_numa" positive_case_pci01; then
        echo "validate_numa test failed: Expected error for invalid NUMA node case 5 but function returned success"
        test_passed=false
    fi

    if validate_numa "$invalid_numa" positive_case_pci01; then
        echo "validate_numa test failed: Expected error for invalid NUMA node case 6 but function returned success"
        test_passed=false
    fi

    if validate_numa "$positive_case_numa_numa01" mixed_numa; then
        echo "validate_numa test failed: Expected error for mixed NUMA nodes case 7 but function returned success"
        test_passed=false
    fi

    if validate_numa "$positive_case_numa_numa01" mixed_numa2; then
        echo "validate_numa test failed: Expected error for mixed NUMA nodes case 8 but function returned success"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        echo "validate_numa test passed: All tests passed successfully"
    else
        echo "validate_numa test failed: Some tests failed"
    fi
}

# test list of core note it platform specific
#
function test_all_cores_from_numa {
    local test_passed=true

    local expected_cores=(
        "0 1 2 3 4 5 6 7 8 9 10 11 48 49 50 51 52 53 54 55 56 57 58 59"
        "12 13 14 15 16 17 18 19 20 21 22 23 60 61 62 63 64 65 66 67 68 69 70 71"
        "24 25 26 27 28 29 30 31 32 33 34 35 72 73 74 75 76 77 78 79 80 81 82 83"
        "36 37 38 39 40 41 42 43 44 45 46 47 84 85 86 87 88 89 90 91 92 93 94 95"
    )

    for numa_node in {0..3}; do
        local expected=${expected_cores[$numa_node]}
        local actual
        actual=$(cores_in_numa "$numa_node")
        if [ "$actual" != "$expected" ]; then
            echo "test_all_cores_from_numa failed: Expected cores $expected
            for NUMA node $numa_node but got $actual"
            test_passed=false
        fi
    done

    # Negative test cases for invalid NUMA nodes
    local invalid_numa=(10 "")
    for numa_node in "${invalid_numa[@]}"; do
      cores=$(cores_in_numa "$numa_node")
      if [ -n "$cores" ]; then
          echo "test_all_cores_from_numa failed: Expected empty result for invalid NUMA node $numa_node but got cores: $cores"
          test_passed=false
      fi
    done

    if [ "$test_passed" = true ]; then
        echo "test_all_cores_from_numa passed: All tests passed successfully"
    else
        echo "test_all_cores_from_numa failed: Some tests failed"
    fi

}

function test_cores_from_numa() {

    local test_passed=true
    # Test case: Select 4 cores from NUMA node 0
    local selected_cores=$(cores_from_numa 0 4)
    local num_selected_cores=$(echo "$selected_cores" | wc -w)
    if [ "$num_selected_cores" -ne 4 ]; then
        echo "test_cores_from_numa failed: Expected 4 cores but got $num_selected_cores"
        test_passed=false
    fi

    # Test case: Select 8 cores from NUMA node 1
    selected_cores=$(cores_from_numa 1 8)
    num_selected_cores=$(echo "$selected_cores" | wc -w)
    if [ "$num_selected_cores" -ne 8 ]; then
        echo "test_cores_from_numa failed: Expected 8 cores but got $num_selected_cores"
        test_passed=false
    fi

    # Test case: Select 10 cores from NUMA node 2 (more than available)
    selected_cores=$(cores_from_numa 2 10)
    if [ "$selected_cores" != "Error: Requested more cores than available." ]; then
        echo "test_cores_from_numa failed: Expected error message but got: $selected_cores"
        test_passed=false
    fi

    if [ "$test_passed" = true ]; then
        echo "test_cores_from_numa passed: All tests passed successfully"
    else
        echo "test_cores_from_numa failed: Some tests failed"
    fi
}

function test_is_cores_in_numa() {

    local test_passed=true
    local positive_cases=(
        "0 1 2 3 4 5 6 7 8 9 10 11 48 49 50 51 52 53 54 55 56 57 58 59"
        "12 13 14 15 16 17 18 19 20 21 22 23 60 61 62 63 64 65 66 67 68 69 70 71"
        "24 25 26 27 28 29 30 31 32 33 34 35 72 73 74 75 76 77 78 79 80 81 82 83"
        "36 37 38 39 40 41 42 43 44 45 46 47 84 85 86 87 88 89 90 91 92 93 94 95"
    )

    local negative_cases=(
        "0 1 2 3 4 5 6 7 8 9 10 11 12"  # Negative: Some cores from NUMA 0, some from NUMA 1
        "24 25 26 27 28 29 30 31 32 33 34 35 36"  # Negative: Cores from NUMA 2 and NUMA 3 mixed
        "60 61 62 63 64 65 66 67 68 69 70 71 72"  # Negative: Cores from NUMA 1 and NUMA 2 mixed
        ""  # Negative: Empty core list
    )

    local selected_numa=(0 1 2 3)

    # Test positive cases
    for i in "${!selected_numa[@]}"; do
        if ! is_cores_in_numa "${selected_numa[$i]}" "${positive_cases[$i]}"; then
            echo "Test failed: Expected success for cores ${positive_cases[$i]} in NUMA ${selected_numa[$i]}"
            test_passed=false
        fi
    done

    for i in "${!negative_cases[@]}"; do
        if is_cores_in_numa "${selected_numa[$i]}" "${negative_cases[$i]}"; then
            echo "Test failed: Expected failure for cores ${negative_cases[$i]} in NUMA ${selected_numa[$i]}"
            test_passed=false
        else
            echo "Correctly identified negative case: ${negative_cases[$i]} for NUMA ${selected_numa[$i]}"
        fi
    done

    echo "Test passed: $test_passed"
}

function test_mask_cores_from_numa() {
    local positive_cases=(
        "0 1 2 3 4 5 6 7 8 9 10 11 48 49 50 51 52 53 54 55 56 57 58 59"
        "12 13 14 15 16 17 18 19 20 21 22 23 60 61 62 63 64 65 66 67 68 69 70 71"
        "24 25 26 27 28 29 30 31 32 33 34 35 72 73 74 75 76 77 78 79 80 81 82 83"
        "36 37 38 39 40 41 42 43 44 45 46 47 84 85 86 87 88 89 90 91 92 93 94 95"
    )
    local test_passed=true

    # Iterate over each NUMA node and its corresponding cores
    for numa_node in "${!positive_cases[@]}"; do
        local cores_to_mask="${positive_cases[$numa_node]}"
        local masked_cores=$(mask_cores_from_numa $numa_node "$cores_to_mask")

        # Convert masked cores to an array to check if any core from the current NUMA node is present
        local -a masked_cores_array=($masked_cores)

        # Check each core in the original list for the current NUMA node
        for core in $cores_to_mask; do
            if [[ " ${masked_cores_array[*]} " =~ " ${core} " ]]; then
                echo "Test failed: Core $core from NUMA $numa_node was not masked correctly."
                test_passed=false
                break
            fi
        done
    done

    if $test_passed; then
        echo "All tests passed: Cores are correctly masked for each NUMA node."
    else
        echo "Some tests failed: Check the output for details."
    fi
}


test_vf_mac_address
test_adapter_numa
test_validate_numa
test_all_cores_from_numa
test_is_cores_in_numa
test_mask_cores_from_numa


# Mask cores from NUMA Node 0
numa_node_to_mask=0
core_list1="0 1 2 3 4 5 6 7 8 9 10 11 48 49 50 51 52 53 54 55 56 57 58 59"
# Call mask_cores_from_numa function
masked_cores=$(mask_cores_from_numa $numa_node_to_mask "$core_list1")
echo "Masked Cores from NUMA Node $numa_node_to_mask: $masked_cores"

#test_cores_from_numa
