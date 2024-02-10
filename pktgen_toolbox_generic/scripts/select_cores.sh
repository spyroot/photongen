#!/bin/bash

select_random_cores() {
    local -n _core_list=$1
    local _num_cores=$2
    local _selected_cores=()

    # shuffle the array and pick the first N elements
    _selected_cores=($(shuf -e "${_core_list[@]}" -n $_num_cores))

    echo "${_selected_cores[*]}"
}

# Get the list of all available cores from numactl
core_list_str=$(numactl -s | grep "physcpubind:" | sed 's/physcpubind: //')
read -r -a core_list <<< "$core_list_str" # Convert string to array

# Define NUMA nodes you're interested in
numa_nodes=("0" "1" "2" "3")

# Define how many cores you want to select randomly
num_cores_to_select=4

# Call the function to select random cores
selected_cores=$(select_random_cores core_list num_cores_to_select)

echo "Selected cores: $selected_cores"
