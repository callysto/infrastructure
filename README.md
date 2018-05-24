# Callysto Infrastructure

This repository contains code for managing infrastructure within the Callysto
project.

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.

All Terraform-related files are stored in the `./terraform` directory.

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

The `Makefile` arguments correspond to the common Terraform commands: `plan`, `apply`,
`destroy`, etc.

The `Makefile` is only a convenience and it is not required. If you want to use Terraform
directly, simply do:

```
$ cd hub-dev
$ ../bin/<arch>/terraform <action>
```

### Terraform Prep
First, run the following to ensure your environment has all prerequisites:

```
  $ make setup
```

You will need to ensure your OpenStack `openrc.sh` file is sourced before running
terraform.

```
  $ source openrc.sh
```

> Do not store credentials in this repository!

The SSH key from the top-level `./keys` directory will be attached to the
instance. Ensure that you have created a key under the `keys` directory:

```
  $ cd keys
  $ ssh-keygen -t rsa -f ./id_rsa
```

> Do not store keys in this repository!

### Deploying an Environment
An "environment" is defined as any collection of related infrastructure.
Environments are grouped in directories under the `terraform` directory.

Use the `Makefile` to deploy an environment:

```
$ make plan env=hub-dev
$ make apply env=hub-dev
```

## Ansible
Resources are _provisioned_ with Ansible. Contrast this with Terraform
which _deploys_ resources.

### Makefile
There's an `ansible/Makefile` which can assist with running various Ansible
commands. Using the `Makefile` makes it easy to ensure the command has all
required information.

If you prefer to not use the `Makefile`, check the contents of the `Makefile`
for all required Ansible arguments and then just run `ansible` or
`ansible-playbook` manually.

## Ansible Inventory
Inventory is handled through the
[ansible-terraform-inventory](https://github.com/jtopjian/ansible-terraform-inventory)
plugin. This plugin reads in the Terraform State of a deployed enviornment and
creates an appropriate Ansible Inventory result.

### Ansible Prep
Run the setup command to prepare the environment:

```
  $ cd ansible
  $ make setup
```

(TODO: this should install Ansible if it's not installed)

Create local_vars.yml file and fill in needed values:

```
  $ cd ansible
  $ cp local_vars.yml.example group_vars/hub/local_vars.yml
  $ vi group_vars/hub/local_vars.yml
```

> Make sure to set `jupyterhub_authenticator` and `jupyterhub_spawner` appropriately.

Create deploy keys. Each of these must be registered on Github by their respected projects.

```
  $ mkdir -p .hostfiles/secret/deploy_keys
  $ ssh-keygen -t rsa -f .hostfiles/secret/deploy_keys/id_callysto_html_deploy
  $ ssh-keygen -t rsa -f .hostfiles/secret/deploy_keys/id_syzygyauthenticator_callysto_deploy
```

Download needed external Ansible roles
Where possible we want to use roles from [ansible
galaxy](https://galaxy.ansible.com). New roles from galaxy can be added to
`ansible/roles/roles_requirements.yml` and a setup script at
`ansible/scripts/role_update.sh` will download them.

```
  $ ./ansible/scripts/role_update.sh
```

## Running Ansible

The instance must be initialized the first time. This will update all packages,
and use a suitable kernel to run zfs with. The instance will reboot once during
the process to use a new kernel version.

```
  $ cd ansible
  $ make env=hub-dev hub/init/check
  $ make env=hub-dev hub/init/apply
```

> Note: `init/check` might fail due to Ansible unable to accurately predict the
> commands it will run.

After a successful initialization, you can continue provisioning the hub with:

```
  $ make env=hub-dev hub/check
  $ make env=hub-dev hub/apply
```

> Note: again, `hub/check` might fail because Ansible.

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
use the following for the Redirect URL: https://hub.callysto.ca/simplesaml/module.php/authwindowslive/linkback.php
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

This SAML Identity Provider must release an eduPersonPrincipalName (urn:oid:1.3.6.1.4.1.5923.1.1.1.6) attribute.
Once provided, it is converted at the Identity Proxy level into a Targeted ID (urn:oid:1.3.6.1.4.1.5923.1.1.1.10)
such as `20fa03478ece18d03c7cd5b39aa2224e45f0cee8`.

### Adding a Generic OIDC Provider
There is currently no way to configure generic OIDC connections. Google and Microsoft both use
OAuth2/OIDC connections, which means SimpleSAMLphp has support, but it will just need to be added
to the Ansible role.

### Identity Proxy Mock (Development) Accounts
In the local_vars.yml file, enable the `develop` variable:
```
...
ssp_develop: True
...
```

Run a deployment

#### Test Accounts
There are 2 test accounts that come enabled with the mock Identity Proxy. They can be used by clicking `Login with mock account` at the Callysto login screen:
```
username: user1
password: password

username: user2
password: password
```

user1 will release an eduPersonTargetedID attribute with the value `lw90qgjwcywcdg0dh3xpykvn0a2wctetlhp5eznmu`
user2 will release an eduPersonPrincipalName attribute with the value `user2@example.ca`
