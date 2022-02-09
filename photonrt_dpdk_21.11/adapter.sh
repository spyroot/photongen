# return pci - nic mapping
lshw -c network -businfo

IFS=: read -ra arr < <(grep "Hugepagesize:" /proc/meminfo)
for a in "${arr[@]}"; do echo "[$a]"; done

