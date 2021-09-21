# photongen

Photon OS DPDK and packet generator , cyclictest , TF2 with CUDA docker image.


## DPKD libs

* All libs are in /usr/local/lib
* The docker image build poccess build all example apps test-pmd etc.
* PktGen installed globally and linked to LTS DPKD build.

# Build Instruction

build_and_exec.sh build container locally and land to local bash session.

```
sudo docker build -t photon_dpdk20.11:v1 .
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 bash
```
