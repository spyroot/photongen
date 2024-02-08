#!/bin/bash
# Invoke mlc idle latency test for different buffer size and strides
# spyroot@gmail.com
# Author Mustafa Bayramov

# Clear the output file
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

# collect for over each stride and buffer size
for stride in "${STRIDE[@]}"
do
  for size in "${BUFFER_SIZE[@]}"
  do
    latency=$(/root/mlc/Linux/mlc --idle_latency -t10 -b"${size}"m -l"${stride}" | grep -oP '(?<=\().*(?=ns)' | sed 's/ //g') && \
      echo "${latency}ns - ${size}MB stride:${stride}" >> "/output_idle_latency.txt"
  done
done

cat /output_idle_latency.txt