# photongen

Photon OS DPDK with all shared libs includes packet generator, cyclictest, 
TF2 with CUDA docker image.

The DPDK build with Mellanox and Intel PMD support.  It also includes all crypto toolkits.
As part of the build, it updates Linux PTP implementation to the latest version.  
It also builds a respected intel driver for 8xx card. Photon OS DPDK with all shared libs 
it includes packet generator , cyclictest,  TF2 with CUDA docker image.

Note currently I don't do any cleanup.  if you need 
'''
yum clean all
'''

And you can delete entire /root/build dir post install, it will strip down entire build.
Lastly everything mostly build from source, you want re-adjust CPU count on docker desktop
if build on desktop system. For speedup you can adjust paraller build for 
cmake and ninja.

## DPKD libs

* The build proccess builds and installs all shared libs in /usr/local/lib
* The docker image build poccess builds all example apps test-pmd etc.
* PktGen installed globally and linked to LTS DPKD build.
* The DPKD compiled with github.com/intel/intel-ipsec-mb.git support.
* The DPKD include MLX4/5 PMD and iverbs.  All kernel model in usual place.
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

* Make sure GPU attached to worker node or baremetal where you run a container.

In order to check GPU,   open python3 repl import tf and check list_physical_devices 

```
sudo docker run --privileged --name photon_bash --rm -i -t photon_dpdk20.11:v1 python3
print("Num GPUs Available: ", len(tf.config.experimental.list_physical_devices('GPU')))
Num GPUs Available:  0
```
