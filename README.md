# photongen

Photon OS DPDK and packet generator , cyclictest , TF2 with CUDA docker image.


## DPKD libs

* The build proccess build and install all libs in /usr/local/lib
* The docker image build poccess build all example apps test-pmd etc.
* PktGen installed globally and linked to LTS DPKD build.
* The DPKD compiled with github.com/intel/intel-ipsec-mb.git support.
* All Melanox libs included.  (Don't foget install all dependancies in OS itself)

# Build Instruction

build_and_exec.sh build container locally and land to local bash session.

```
sudo docker build -t photon_dpdk20.11:v1 .
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 bash
```
