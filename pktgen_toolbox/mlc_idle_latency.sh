#!/bin/bash
# invoke mlc idle latency
# buffer sizes
BUFFER_SIZE=(16 32 64 128)
# Loop through each buffer size
for size in "${BUFFER_SIZE[@]}"
do
    /root/mlc/Linux/mlc --idle_latency -t10 -b"${size}"m | grep -oP '(?<=\().*(?=ns)' >> "output_idle_latency.txt"
done
