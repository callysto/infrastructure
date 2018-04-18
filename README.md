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

The instance must be initialized the first time. This will update all packages,
and use a suitable kernel to run zfs with.
```
  $ cd ansible
  $ ansible-playbook plays/init.yml
```


Where possible we want to use roles from [ansible
galaxy](https://galaxy.ansible.com). New roles from galaxy can be added to
`ansible/roles/roles_requirements.yml` and a setup script at
`ansible/scripts/role_update.sh` will download them.

```
  $ ./ansible/scripts/role_update.sh
```
