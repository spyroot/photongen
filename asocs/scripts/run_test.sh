# export ANSIBLE_NET_USERNAME=XXXXX
# export ANSIBLE_NET_PASSWORD=XXXXX

# mac os 
# sudo launchctl limit maxfiles unlimited
#conda activate asocs
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_CONNECTION=local
export ANSIBLE_INVENTORY=./hosts

ansible-galaxy collection install cisco.nxos

# upgrade 
#sudo pip install --ignore-installed --upgrade ansible

ansible-playbook test.yml --syntax-check
ansible-playbook test.yml
