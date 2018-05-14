# Callysto Infrastructure

This repository contains code for managing infrastructure within the Callysto
project.

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.

All Terraform-related files are stored in the `./terraform` directory.

### Terraform Prep
You will need to ensure your OpenStack `openrc.sh` file is sourced before running
terraform.
```
  $ source openrc.sh
```

The SSH key from the top-level `./keys` directory will be attached to the
instance. Ensure that you have created a key under the `keys` directory:

```
  $ cd keys
  $ ssh-keygen -t rsa -f ~/.ssh/id_rsa
```

### Binaries
The `./terraform/bin` directory contains the binaries required to run Terraform.
These binaries are bundled in this repository to ensure all project members are
using the same version.

### Modules
Terraform modules are stored in `./terraform/modules`. The following modules
are defined:

  * `hub`: deploys a standard Callysto JupyterHub environment.

### Makefile
The `./terraform/Makefile` provides an easy way to interact with Terraform to
deploy and manage infrastructure.

For example, to redeploy the `hub-dev` environment, do

```
  $ make destroy env=hub-dev
  $ make apply env=hub-dev
```

This will use the Terraform binary in `./bin` to apply the Terraform configuration
defined in `./terraform/hub-dev`.

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
