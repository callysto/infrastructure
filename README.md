# Build a Hub for Callysto

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.

 * m1.large
 * CentOS 7
 * 2 * 50G volumes for user homedir backing
 * 1 * 100G volume used for /var/lib/docker

### Terraform Prep
You will need to ensure your OpenStack `openrc.sh` file is sourced before running
 terraform.
```
  $ source openrc.sh
```

The SSH public key from your $HOME/.ssh/id_rsa.pub will be attached to the instance.
Ensure that you have the associated key ($HOME/.ssh/id_rsa) as well. If you need to
create one then run:
```
  $ ssh-keygen -t rsa -f ~/.ssh/id_rsa
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

## Ansible Prep
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
and use a suitable kernel to run zfs with. The instance will reboot once during
the process to use a new kernel version and automatically continue the deployment
of the `jupyter.yml` playbook.
```
  $ cd ansible
  $ ansible-playbook plays/init.yml
```

After a successful initialization, you can maintain the installation with this command:
```
  $ ansible-playbook plays/jupyter.yml
```

## Identity Proxy

An identity proxy [SimpleSAMLphp](https://simplesamlphp.org/) is used to manage multiple
login sources from Google, Microsoft, and other SAML/OIDC providers.
All configuration is done via the `local_vars.yml` file.

### Initial Configuration
The following variables will need to be configured in the `local_vars.yml` file before deployment:
```
  ssp_idp_multi_salt
  ssp_idp_multi_admin_password
  ssp_refresh_key
  ssp_idp_multi_saml_cert
  ssp_idp_multi_saml_key
```

The salt, admin password, and refresh key can be set to any secure values.

The SAML keys can be created by using the following command:
```
  $ openssl req -new -x509 -days 3650 -nodes -sha256 -out saml.crt -keyout saml.pem
```

Copy the contents of `saml.crt` to `ssp_idp_multi_saml_cert`, and `saml.pem` to `ssp_idp_multi_saml_key`.

### Adding Google Authentication
Register application with Google here: https://console.developers.google.com/?pli=1

Create a new project.
Credentials > Create credentials > OAuth client ID
Select Web application
Name the client something memorable
Authorized redirect URIs: https://hub.callysto.ca/simplesaml/module.php/authoauth2/linkback.php
Note the client ID and client secret as they will be added to:
```
ssp_idp_multi_sources:
  ...
  - type: google
    display_name: Google
    client_id: <Google client ID>
    client_secret: <Google client secret>
```
More documentation here: https://developers.google.com/identity/protocols/OAuth2

### Adding Microsoft Authentication
You will need to register the application here: http://go.microsoft.com/fwlink/?LinkID=144070

Under the Platforms > Web section in the Microsoft registration page,
use the following for the Redirect URL: https://hub.callysto.ca/simplesaml/module.php/authoauth2/linkback.php
Make sure the `User.Read` permission is set.

Create an application secret. This will be stored under `client_secret` in local_vars.yml:
```
ssp_idp_multi_sources:
  ...
  - type: microsoft
    display_name: Microsoft
    client_id: <Microsoft Application Id>
    client_secret: <Application Secret>
```

More documentation here: https://msdn.microsoft.com/en-us/library/bb676626.aspx

### Adding a SAML Identity Provider:
Add an entry for the Identity Provider under `local_vars.yml`:
```
ssp_idp_multi_sources:
  ...
  - type: saml
    display_name: Example School
    metadata_url: https://school.example.com/authentication/idp/metadata
```

You will need to provide the following metadata URL to the Identity Provider:
https://hub.callysto.ca/simplesaml/module.php/saml/sp/metadata.php/default-sp

Currently only SAML Identity Providers that publish their metadata is supported. If values
are hardcoded, support for this will need to be added to the ssp-idp-multi role.
It's trivial to add, but likely won't be needed.

### Adding a Generic OIDC Provider
There is currently no way to configure generic OIDC connections. Google and Microsoft both use
OAuth2/OIDC connections, which means SimpleSAMLphp has support, but it will just need to be added
to the Ansible role.
