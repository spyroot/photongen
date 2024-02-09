#!/bin/bash
# Invoke max bandwidth test for different buffer sizes, strides,
# and on specific cores or all cores
#
# Description:
#   This script runs the MLC max bandwidth test with customizable
#   buffer sizes, stride sizes, and core lists. Users can set these parameters
#   through environment variables before running the script to tailor the test
#   according to their needs.
#
# Environment Variables:
#   BUFFER_SIZE - A space-separated list of buffer sizes in megabytes.
#                 Example: "8 16 32 64"
#   STRIDE      - A space-separated list of stride sizes. The stride size
#                 determines the gap between successive memory accesses.
#                 Example: "8 16 24 32"
#   cores       - A space-separated list of CPU cores on which the test should
#                 be run. This controls the core affinity for the test.
#                 Example: "0 1 2 3"
#
#   If these variables are not set, the script uses default values for buffer sizes,
#   stride sizes, and will run the test without specific core affinity.
#
# Usage:
#   To run the test with custom settings, export the desired environment variables
#   before executing this script. For example:
#
#   export BUFFER_SIZE="8 16 32 64"
#   export STRIDE="8 16 24 32"
#   export cores="0 1 2 3"
#   ./this_script_name.sh
#
#   Replace "this_script_name.sh" with the actual name of this script.
#
# Output:
#   The script saves the test results to "/output_peak_injection_bandwidth.txt".
#
# spyroot@gmail.com
# Author Mustafa Bayramov

OUTPUT_PATH_FILE="/output_max_bandwidth.txt"
> "$OUTPUT_PATH_FILE"

CSV_FILE="/output_max_bandwidth.csv"
> "$CSV_FILE"

if [[ -n "$BUFFER_SIZE" ]]; then
    IFS=' ' read -r -a BUFFER_SIZE <<< "$BUFFER_SIZE"
else
    BUFFER_SIZE=(8 16 24 32 64 128 512 1024)
fi

if [[ -n "$STRIDE" ]]; then
    IFS=' ' read -r -a STRIDE <<< "$STRIDE"
else
    STRIDE=(8 16 24 32 64 128)
fi

if [[ -n "$cores" ]]; then
    IFS=' ' read -r -a cores <<< "$cores"
    cores_str="${cores[*]}"
    if_per_cores="-k$cores_str"
else
    cores_str=""
    if_per_cores=""
fi

echo "Running max bandwidth tests for buffer sizes: \
${BUFFER_SIZE[*]} and strides: ${STRIDE[*]} with cores: ${cores_str}"
for stride in "${STRIDE[@]}"
do
  for bs in "${BUFFER_SIZE[@]}"
  do
    echo "Running for buffer ${bs}m stride ${stride} cores ${cores_str}"
    mlc_command="/root/mlc/Linux/mlc --max_bandwidth -t1 -b${bs}m ${if_per_cores}"
    rw=$(eval "$mlc_command" | awk -v bs="$bs" \
    -v cores="$cores_str" '/ALL Reads/ {flag=1} flag {print "size " bs ", cores " cores ", " $0}')
    echo "$rw" | awk '/size [0-9]+, cores [^,]+, .+:/ {print}' >> "$OUTPUT_PATH_FILE"
  done
done

awk '{
# Match lines and extract parts
if (match($0, /size ([0-9]+), cores ([^,]+), (.+):[[:space:]]+([0-9.]+)/, arr)) {
	# Write to CSV format: Test Type, Buffer Size, Cores, Value
	print arr[3] ", " arr[1] ", " arr[2] ", " arr[4]
}
}' "$OUTPUT_PATH_FILE" > "$CSV_FILE"

echo "CSV file created: $CSV_FILE"
cat "$CSV_FILE"