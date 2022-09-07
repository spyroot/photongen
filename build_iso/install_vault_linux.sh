#!/bin/bash
# create hashi corp vault where we store all secrets including VC pass.
# token.txt contains a token for a vault. Make sure you set right tf env.
# Author Mustafa Bayramov 

current_os=$(uname -a)
if [[ ! $current_os == *"Linux"* ]]; 
then
echo "This script for linux os."
exit 2
fi

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo \
		"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
		https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update && sudo apt install vault

vault_pid=$(pgrep "vault")
if [ -n "$vault_pid" ] && [ "$vault_pid" -eq "$vault_pid" ] 2>/dev/null; 
then
	echo "Killing vault pid $vault_pid"
	kill $vault_pid
fi

vault server -dev > vault.log &
TOKEN=$(cat vault.log | grep Root | awk '{print $3}')
echo $TOKEN > token.txt

vault secrets enable -path=vcenter kv
vault kv put vcenter/vcenterpass password="DEFAULT
