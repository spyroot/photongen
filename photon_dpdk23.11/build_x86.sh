docker buildx build \
	--platform linux/amd64 \
	--build-arg MESON_ARGS="-Dplatform=generic" \
	-t cnfdemo.io/spyroot/dpdk_generic_tester:latest . > build.generic.log 2>&1

docker buildx build --platform linux/amd64 \
	--build-arg MESON_ARGS="-Dplatform=native" \
	-t cnfdemo.io/spyroot/dpdk_native_tester:latest . > build_native.log 2>&1
