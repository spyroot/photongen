#!/bin/bash

# Script start container with test-pmd
# Author Mustafa Bayramov 

default_device0="/dev/uio0"
default_peer_mac="00:50:56:b6:0d:dc"
default_forward_mode="txonly"
default_img_name="photon_dpdk20.11:v1"
default_dev_hugepage="/dev/hugepages"

command -v ifconfig >/dev/null 2>&1 || \
	{ echo >&2 "Require ifconfig but it's not installed.  Aborting."; exit 1; }
command -v lspci >/dev/null 2>&1 || \
	{ echo >&2 "Require lspci but it's not installed.  Aborting."; exit 1; }
command -v lshw >/dev/null 2>&1 || \
	{ echo >&2 "Require lshs but it's not installed.  Aborting."; exit 1; }
command -v dpdk-devbind.py >/dev/null 2>&1 || \
	{ echo >&2 "Require foo but it's not installed.  Aborting."; exit 1; }

# Take first VF and use it
pci_dev=$(lspci -v | grep "Virtual Function" | awk '{print $1}')
eth_dev=$(lshw -class network -businfo | grep "$pci_dev" | awk '{print $2}')

if [ "$eth_dev" == "network" ]; then
	echo " $pci_dev unbounded from kernel"
	eth_up="DOWN"
else
	eth_up=$(ifconfig eth1 | grep BROADCAST | awk '{print $1}')
fi

if [ "$eth_up" == "UP" ]; then
	echo "$pci_dev $eth_dev is kernel bounded $eth_up"
	ifconfig "$eth_dev" down
	/usr/local/bin/dpdk-devbind.py -b uio_pci_generic "$pci_dev"
else
	#is_loadded=$(/usr/local/bin/dpdk-devbind.py -s | grep $pci_dev | grep drv=uio_pci_generic)
	/usr/local/bin/dpdk-devbind.py -b uio_pci_generic "$pci_dev"
fi

if [ -c "$default_device0" ]; then
	echo "Attaching $default_device0."
fi

if [ -c "$default_dev_hugepage" ]; then
	docker run --privileged --name photon_testpmd --device=/sys/bus/pci/devices/* \
		-v "$default_dev_hugepage":/dev/hugepages  \
		--cap-add=SYS_RAWIO --cap-add IPC_LOCK \
		--cap-add NET_ADMIN --cap-add SYS_ADMIN \
		--cap-add SYS_NICE \
		--rm \
		-i -t $default_img_name /usr/local/bin/dpdk-testpmd \
		-- -i --forward-mode=$default_forward_mode --eth-peer=0,$default_peer_mac
else
	"Warrning. Create hugepages in respected numa node."
fi