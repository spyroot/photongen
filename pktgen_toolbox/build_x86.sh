docker buildx build \
	--platform linux/amd64 \
	--build-arg MESON_ARGS="-Dplatform=native" \
	-t cnfdemo.io/spyroot/dpdk_pktgen_iperf_native:latest .
