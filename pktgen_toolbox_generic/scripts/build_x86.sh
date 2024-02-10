docker rmi cnfdemo.io/spyroot/pktgen_toolbox_generic > build.generic.log 2>&1

docker buildx build \
	--platform linux/amd64 \
	--build-arg BUILD_ARGS="-Dplatform=generic" \
	-t cnfdemo.io/spyroot/pktgen_toolbox_generic:latest ../

docker tag cnfdemo.io/spyroot/pktgen_toolbox_generic:latest spyroot/pktgen_toolbox_generic:latest
docker rmi cnfdemo.io/spyroot/pktgen_toolbox_generic