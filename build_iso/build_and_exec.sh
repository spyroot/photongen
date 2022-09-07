#!/bin/bash
# Pull reference iso.
# Creates container and pull all requested packages.
# Container will run buld_iso script and generate new iso file.
# The new iso file generate to be a reference kick start unattended installer.
# Note: that docker run use current dir as volume make sure if you run on macos you
# current dir added to resource.    Docker -> Preference -> Resource and add dir.
# Author Mustafa Bayramov 

current_os=$(uname -a)
if [[ $current_os == *"xnu"* ]]; 
then
    brew_info_out=$(brew info wget | grep bottled)
    if [[ $brew_info_out == *"vault: stable"* ]]; 
    then
	    echo "wget already installed."
    else
	    brew install wget
    fi
fi

if [[ $current_os == *"linux"* ]];
then
	apt-get update
	apt-get install ca-certificates curl gnupg lsb-release
	FILE=/etc/apt/keyrings/docker.gpg
	if [ -f "$FILE" ]; then
    	echo "$FILE exists."
	else
		mkdir -p /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  		$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

if [[ $current_os == *"linux"* ]];
then
	apt-get update
	apt-get install -y aufs-tools cgroupfs-mount docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

wget -nc http://10.241.11.28/iso/photon/ph4-rt-refresh.iso
docker rm -f /photon_iso_builder
docker build -t photon_iso_builder:v1 .
docker run -v `pwd`:`pwd` -w `pwd` --privileged --name photon_iso_builder --rm -i -t photon_iso_builder:v1 bash
