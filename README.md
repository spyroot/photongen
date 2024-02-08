# photongen

This repository hosts several container-build systems tailored for local Docker 
and Kubernetes environments. Each repository includes a separate README file for 
detailed instructions.

All builds are based on VMware Photon OS, utilizing either the regular or real-time kernel. 
Each base container is compiled with different versions of DPDK (Data Plane Development Kit) 
and toolchains.

For instance, photon_dpdk23.11 serves as the base container, providing capabilities to run Packet Gen 
and DPDK 23.11 LTS. It includes DPDK test PMD, iperf, and several other packet generation tools. 

The container image encompasses nearly all PMD drivers, including those for cryptography and FPGA.
Similarly, this build offers two flavors optimized for Intel Xeon 4/5 Gen and generic x86 architectures. 

These containers cater to diverse hardware environments, ensuring flexibility 
and performance across different setups. You can find the repository 
at docker/spyroot/dpdk_native_tester.

There is also separate set of container specifically focus on real time kernel.

Photon OS DPDK and packet generator, cyclictest , TF2 with CUDA docker image.

## Using as baseline container.

pktgen_toolbox a container that primarily targeted for testing and developing cycles.
As minimum implementation it sufficient to use base image dpdk_native_tester:latest 
or dpdk_generic_tester:latest

```Docker
FROM spyroot/dpdk_native_tester:latest
LABEL maintainer="Mustafa Bayramov <spyroot@gmail.com>"
LABEL description="A packet generation and dev toolbox"
```

This container is designed to be versatile, catering to both virtual machine (VM) 
and bare-metal setups. A build and container images  provides the necessary components 
and configurations to support your deployment needs.

In photon_dpdk23.11 I include detail step by step process.

## DPDK libs

* The build process builds and installs all shared libs in /usr/local/lib
* The docker image build process builds all example apps test-pmd etc.
* PktGen installed globally and linked to LTS DPDK build.
* The DPDK compiled with github.com/intel/intel-ipsec-mb.git support.
* All Melanox PMD and libs included as part of build. (Don't forget install all dependencies in OS itself)


# Generic Build Instruction

build_and_exec.sh build container locally and land to local bash session.

```
sudo docker build -t photon_dpdk20.11:v1 .
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 bash
```
# Post Build re-compilation

All source inside /root/build

```
root [ /usr/local ]# cd /root/build/
root [ ~/build ]# ls
dpdk-20.11.3.tar.xz  dpdk-stable-20.11.3  pktgen-dpdk  rt-tests
```

# Running Cyclictest

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 cyclictest
```

# Running PktGen

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 pktgen
```

# Running testpmd

Regular setup requires hugepage 

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 dpdk-testpmd
```

Test run

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 dpdk-testpmd --no-huge
```


# Tenorflow

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 python3
Python 3.9.1 (default, Aug 19 2021, 02:58:42)
[GCC 10.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import tensorflow as tf
>>> model = tf.keras.models.Sequential([
...   tf.keras.layers.Flatten(input_shape=(28, 28)),
...   tf.keras.layers.Dense(128, activation='relu'),
...   tf.keras.layers.Dropout(0.2),
...   tf.keras.layers.Dense(10)
... ])
>>>
```

* Make sure GPU attached to worker node or bare metal where you run a container.

In order to check GPU,   open python3 repl import tf and check list_physical_devices 

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 python3
print("Num GPUs Available: ", len(tf.config.experimental.list_physical_devices('GPU')))
Num GPUs Available:  0
```
