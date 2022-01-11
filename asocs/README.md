# Playbook creates ASOCS stack.

- It populates all required DVS.
- Create required Port-groups on separate DVS, dedicated for all SRIOV.
- Take reference to OVA, upload it as a master template.
- Re-create two templates, each template for CU and DU.
- Create new network adapters and map each to SRIOV.
- Serialize back all VM as templates.

In case of issue mbayramo@vmware.com

## Requirements.

- Single ESXi host.
- Note you will need to manually add physical PNIC 
- to a target DVS that you are going to use for SRIOV, the rest is automated.

## Instruction

* First create the environment,  we keep separate python environment
```bash
conda create --name asocs python=3.8
conda activate asocs
```

* Second pull ansible integration

```bash
pip3 install ansible
ansible-galaxy collection install community.vmware
ansible-galaxy install vmware.govc
```

* Second pull ansible integration

```bash
ansible-playbook cu.yaml --syntax-check
```
