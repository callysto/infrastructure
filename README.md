# Build a Hub for Callysto

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.
 
 * deb21990-9256-4ac3-ac7c-b7cb5275d619: m1.8c32g
 * deb21990-9256-4ac3-ac7c-b7cb5275d619: CentOS 7
 * 2 * 50G volumes for user homedir backing

### Setup
You will need to ensure your OpenStack `openrc.sh` file is in the top level folder.
Ensure you source it before proceeding:
```
  $ source openrc.sh
```


### First Time
You will need the openstack plugin and some other bits and pieces so run
`terraform init` in the terraform directory
```
  $ cd terraform
  $ terraform init
```

### Terraform apply
`terraform apply` will create the resources for you
```
  $ cd terraform
  $ terraform apply

...
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

ip = 162.246.156.221
```
That IP address should be associated with some DNS name before the ansible
playbooks are run.


## Ansible

We have encoded most of the setup for creating our JupyterHub instances as
ansible playbooks. Before actually running the playbooks, I usually run some
ad-hoc commands to get the system to a known state
```
  $ cd ansible
  $ ansible --become -i inventory.yml \ 
    -m 'yum' -a 'name=* state=latest exclude=dhclient' \
    hub-dev.callysto.ca
  $ ansible --become -i inventory.yml \
    -m 'command' -a 'reboot' \
    hub-dev.callysto.ca
```

Additionally, we want to use an updated kernel which means we will involve a
reboot before we can compile kernel modules against it (zfs). This can be done
by rebooting after running the setup tasks
```
  $ cd ansible
  $ ansible-playbook plays/jupyter.yml --tags setup
  $ ansible --become -i inventory.yml \
    -m 'command' -a 'reboot' \
    hub-dev.callysto.ca
```

Where possible we want to use roles from [ansible
galaxy](https://galaxy.ansible.com). New roles from galaxy can be added to
`ansible/roles/roles_requirements.yml` and a setup script at
`ansible/scripts/role_update.sh` will download them.

```
  $ ./ansible/scripts/role_update.sh
```
