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

> "/output_idle_latency.txt"

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

echo "Running idle latency tests for \
buffer sizes: ${BUFFER_SIZE[*]} and strides: ${STRIDE[*]}"

for stride in "${STRIDE[@]}"
do
  for size in "${BUFFER_SIZE[@]}"
  do
    echo "- Running for buffer ${size}m stride ${stride}"
    latency=$(/root/mlc/Linux/mlc --idle_latency -t10 -b"${size}"m -l"${stride}" | grep -oP '(?<=\().*(?=ns)' | sed 's/ //g') && \
      echo "${latency}ns - ${size}MB - ${stride}" >> "/output_idle_latency.txt"
  done
done

cat /output_idle_latency.txt