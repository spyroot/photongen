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
