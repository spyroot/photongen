docker rmi cnfdemo.io/spyroot/pktgen_toolbox > build.generic.log 2>&1

docker buildx build \
	--platform linux/amd64 \
	--build-arg MESON_ARGS="-Dplatform=native" \
	-t cnfdemo.io/spyroot/pktgen_toolbox:latest .

docker tag cnfdemo.io/spyroot/pktgen_toolbox:latest spyroot/pktgen_toolbox:latest