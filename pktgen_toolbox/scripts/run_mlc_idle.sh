docker run \
-e BUFFER_SIZE="8 16" \
-e STRIDE="24 32" \
-e CONSOLE_OUT="true" \
-it --privileged --rm spyroot/pktgen_toolbox:latest /bin/bash -c "/mlc_idle_latency.sh"
