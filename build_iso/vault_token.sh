#!/bin/bash
TOKEN=$(cat vault.log | grep Root | awk '{print $3}')
echo $TOKEN > token.txt
echo "export VAULT_ADDR='http://127.0.0.1:8200'"
echo "export VAULT_TOKEN=$TOKEN"
