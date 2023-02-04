#!/bin/bash
# Create hash corp vault where we store all secrets including VC pass.
# token.txt contains a token for a vault. Make sure you set right tf env.
# Author Mustafa Bayramov 

VAULT_LOG="vault.log"

CURRENT_OS=$(uname -a)
if [[ ! $CURRENT_OS == *"Linux"* ]];
then
  echo "This script for linux os."; exit 2
fi

apt-get install wget; wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo \
		"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
		https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update; apt-get install vault

VAULT_PID=$(pgrep "vault")
if [ -n "$VAULT_PID" ] && [ "$VAULT_PID" -eq "$VAULT_PID" ] 2>/dev/null;
then
	echo "Killing vault pid $VAULT_PID"
	kill "$VAULT_PID"
fi

vault server -dev > vault.log &
TOKEN=$(cat $VAULT_LOG | grep Root | awk '{print $3}')
echo "$TOKEN" > token.txt
export VAULT_ADDR='http://127.0.0.1:8200'"
export VAULT_TOKEN=$TOKEN"

vault secrets enable -path=vcenter kv
vault kv put vcenter/vcenterpass password="DEFAULT"
