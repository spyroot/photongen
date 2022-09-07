#!/bin/bash
# create hashi corp vault where we store all secrets including VC pass.
# token.txt contains a token for a vault. Make sure you set right tf env.
# Author Mustafa Bayramov 

current_os=$(uname -a)
if [[ ! $current_os == *"xnu"* ]]; 
then
echo "This script for mac os."
exit 2
fi

brew_info_out=$(brew info vault | grep bottled)
if [[ $brew_info_out == *"vault: stable"* ]]; 
then
	echo "Vault already installed! Version $brew_info_out"
else
	brew tap hashicorp/tap
	brew install hashicorp/tap/vault
	brew install hashicorp/tap/packer
	brew upgrade hashicorp/tap/packer
	brew install cdrtools
fi

vault_pid=$(pgrep "vault")
if [ -n "$vault_pid" ] && [ "$vault_pid" -eq "$vault_pid" ] 2>/dev/null; 
then
	echo "Killing vault pid $vault_pid"
	kill $vault_pid
fi

vault server -dev > vault.log &
TOKEN=$(cat vault.log | grep Root | awk '{print $3}')
echo $TOKEN > token.txt
