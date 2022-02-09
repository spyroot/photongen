docker build -t photon_dpdk21.11:v1 .
docker run --privileged --name photon_bash --rm -i -t photon_dpdk21.11:v1 bash
