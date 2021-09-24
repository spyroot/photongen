#!/bin/bash

# Script start container with test-pmd.
# 
# - it gets list of all cores and construct a range from low to hi
# - if interface bounded by kernel driver will shutdown and bind dpdk
# - it passed device to container
# - it check hugepages and passed dev to container
#
# Author Mustafa Bayramov 

default_device0="/dev/uio0"
default_peer_mac="00:50:56:b6:0d:dc"
default_forward_mode="txonly"
default_img_name="photon_dpdk20.11:v1"
default_dev_hugepage="/dev/hugepages"

command -v numactl >/dev/null 2>&1 || \
	{ echo >&2 "Require numactl but it's not installed.  Aborting."; exit 1; }
command -v ifconfig >/dev/null 2>&1 || \
	{ echo >&2 "Require ifconfig but it's not installed.  Aborting."; exit 1; }
command -v lspci >/dev/null 2>&1 || \
	{ echo >&2 "Require lspci but it's not installed.  Aborting."; exit 1; }
command -v lshw >/dev/null 2>&1 || \
	{ echo >&2 "Require lshs but it's not installed.  Aborting."; exit 1; }
command -v dpdk-devbind.py >/dev/null 2>&1 || \
	{ echo >&2 "Require foo but it's not installed.  Aborting."; exit 1; }

# get list of all cores and numa node
# pass entire range of lcores to DPKD
nodes=$(numactl --hardware | grep cpus | tr -cd "[:digit:] \n")
[[ -z "$nodes" ]] && { echo "Error: numa nodes string empty"; exit 1; }

IFS=', ' read -r -a nodelist <<< "$nodes"
numa_node="${nodelist[0]}"
numa_lcores="${nodelist[@]:1}"
numa_low_lcore="${nodelist[0]}"
numa_hi_lcore="${nodelist[-1]}"

echo "Using" "$numa_node"
echo "$numa_lcores" "lcore range $numa_low_lcore - $numa_hi_lcore"

[[ -z "$numa_node" ]] && { echo "Error: numa node value empty"; exit 1; }
[[ -z "$numa_low_lcore" ]] && { echo "Error: numa lower bound for num lcore is empty"; exit 1; }
[[ -z "$numa_hi_lcore" ]] && { echo "Error: numa upper bound for num lcore is empty"; exit 1; }

echo -n "Do wish to use default peer mac address program (y/n)? "
read -r default_mac

if [ "$default_mac" != "${default_mac#[Yy]}" ] ;then
    echo "Using default peer mac" $default_peer_mac
else
	echo -n "Provide peer mac address: "
    read -r "$default_mac"
fi

[[ -z "$default_mac" ]] && { echo "Error: mac address is empty"; exit 1; }

echo -n "Using peer mac address: " "$default_mac"


# Take first VF and use it
pci_dev=$(lspci -v | grep "Virtual Function" | awk '{print $1}')
eth_dev=$(lshw -class network -businfo | grep "$pci_dev" | awk '{print $2}')

if [ "$eth_dev" == "network" ]; then
	echo " A pci device $pci_dev already unbounded from kernel."
	eth_up="DOWN"
else
	eth_up=$(ifconfig eth1 | grep BROADCAST | awk '{print $1}')
fi

if [ "$eth_up" == "UP" ]; then
	echo "A pci device $pci_dev $eth_dev is bounded by kernel as $eth_up"
	ifconfig "$eth_dev" down
	/usr/local/bin/dpdk-devbind.py -b uio_pci_generic "$pci_dev"
else
	#is_loadded=$(/usr/local/bin/dpdk-devbind.py -s | grep $pci_dev | grep drv=uio_pci_generic)
	/usr/local/bin/dpdk-devbind.py -b uio_pci_generic "$pci_dev"
fi

if [ -c "$default_device0" ]; then
	echo "Attaching $default_device0."
fi

if [ -d "$default_dev_hugepage" ]; then
	docker run --privileged --name photon_testpmd --device=/sys/bus/pci/devices/* \
		-v "$default_dev_hugepage":/dev/hugepages  \
		--cap-add=SYS_RAWIO --cap-add IPC_LOCK \
		--cap-add NET_ADMIN --cap-add SYS_ADMIN \
		--cap-add SYS_NICE \
		--rm \
		-i -t $default_img_name /usr/local/bin/dpdk-testpmd -l "$numa_low_lcore-$numa_hi_lcore" \
		-- -i --disable-rss --rxq=4 --txq=4 \
		--disable-device-start \
	    --forward-mode=$default_forward_mode --eth-peer=0,$default_peer_mac
else
	"Warrning. Create hugepages in respected numa node."
fi