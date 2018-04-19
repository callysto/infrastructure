# Build a Hub for Callysto

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.

 * m1.large
 * CentOS 7
 * 2 * 50G volumes for user homedir backing
 * 1 * 100G volume used for /var/lib/docker

### Setup
You will need to ensure your OpenStack `openrc.sh` file is sourced before running
 terraform.
```
  $ source openrc.sh
```

The SSH public key from your $HOME/.ssh/id_rsa.pub will be attached to the instance.
Ensure that you have the associated key ($HOME/.ssh/id_rsa) as well. If you need to
create one then run:
```
ssh-keygen -t rsa -f ~/.ssh/id_rsa
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

## Prep
Create local_vars.yml file and fill in needed values:
```
  $ cd ansible
  $ cp local_vars.yml.example group_vars/all/local_vars.yml
  $ vi group_vars/all/local_vars.yml
```

Create deploy keys. Each of these must be registered on Github by their respected projects.
```
  $ ssh-keygen -t rsa -f .hostfiles/secret/deploy_keys/id_callysto_html_deploy
  $ ssh-keygen -t rsa -f .hostfiles/secret/deploy_keys/id_syzygyauthenticator_callysto_deploy
```

Update Ansible inventory file and replace hostname under "google" section:
```
  $ vi inventory.yml
```

Download needed external Ansible roles
Where possible we want to use roles from [ansible
galaxy](https://galaxy.ansible.com). New roles from galaxy can be added to
`ansible/roles/roles_requirements.yml` and a setup script at
`ansible/scripts/role_update.sh` will download them.

```
  $ ./ansible/scripts/role_update.sh
```

## Ansible

The instance must be initialized the first time. This will update all packages,
and use a suitable kernel to run zfs with. When finished, the instance will reboot
to use the newly installed kernel.
```
  $ cd ansible
  $ ansible-playbook plays/init.yml
```

After a successful initialization, you can finish configuring with this command:
```
  $ ansible-playbook plays/jupyter.yml
```
