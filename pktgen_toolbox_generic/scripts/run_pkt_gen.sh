docker run \
-e BUFFER_SIZE="8 16" \
-e STRIDE="24 32" \
-e CORES="2-3" \
-e CONSOLE_OUT="true" \
-it --privileged --rm \
spyroot/pktgen_toolbox_generic:latest:latest pktgen \
-l 2-14 -n 4 --proc-type auto --log-level 7 --file-prefix pg -a 0000:23:02.0 -- -T -m "[4-7:10-13].0"
