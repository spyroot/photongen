docker run \
-e BUFFER_SIZE="8 16" \
-e STRIDE="24 32" \
-it --privileged --rm \
spyroot/pktgen_toolbox:latest /bin/bash -c "/mlc_peak_inject_bw.sh"
