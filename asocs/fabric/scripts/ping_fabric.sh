export ANSIBLE_CONNECTION=local
export ANSIBLE_INVENTORY=./hosts
ansible leaf -m ping -i ./hosts
