docker run \
-e BUFFER_SIZE="8 16" \
-e STRIDE="24 32" \
-e CORES="2-3" \
-e CONSOLE_OUT="true" \
-it --privileged --rm \
spyroot/pktgen_toolbox_generic:latest:latest /bin/bash -c "/mlc_peak_inject_bw.sh"
