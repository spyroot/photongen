#!/bin/bash

output="$(docker run \
-e BUFFER_SIZE="8 16" \
-e STRIDE="24 32" \
-e CORES="2-3" \
-e CONSOLE_OUT="true" \
-it --privileged --rm \
spyroot/pktgen_toolbox_generic:latest:latest dpdk-devbind.py -s)"
readarray -t pci_devices <<< "$(echo "$output" | awk '/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]/ {print $1}')"

for pci in "${pci_devices[@]}"; do
    echo "$pci"
done
