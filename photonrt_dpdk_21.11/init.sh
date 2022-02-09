#!/bin/bash

hpagesize=1024

mkdir -p /dev/hugepages
mountpoint -q /dev/hugepages || mount -t hugetlbfs nodev /dev/hugepages
echo $hpagesize > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages

numastat
