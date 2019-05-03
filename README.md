# Callysto Infrastructure

This repository contains code for managing infrastructure within the Callysto
project.

## OpenStack

The Callysto infrastructure runs exclusively on OpenStack. In order to exactly
reproduce everything here, you will need access to an OpenStack cloud with the
following services:

* Nova
* Cinder
* Neutron
* Designate

## Master Makefile

There is a master `Makefile` located in the root directory. This `Makefile`
is used to more easily interact with the below services.

To see all tasks that the `Makefile` supports, run:

```
  $ make help
```

## Packer

Packer is used to create OpenStack images with pre-installed packages and
settings. This is to help reduce the amount of time it takes to build dev
and CI environments.

### Binaries

The `./bin` directory contains the binaries required to run Packer.
These binaries are bundled in this repository to ensure all project members are
using the same version.

### Makefile

The master `Makefile` provides an easy way to interact with Packer to create
images.

For example, to create the base hub image:

```
  $ make packer/build/hub
```

> Note: review the `Makefile` and Packer build files to ensure their settings
> are appropriate for your environment.

## Terraform

The resources are controlled by terraform so we can destroy and recreate
everything quickly.

All Terraform-related files are stored in the `./terraform` directory.

### Binaries

The main `./bin` directory contains the binaries required to run Terraform.
These binaries are bundled in this repository to ensure all project members are
using the same version.

### Modules

Terraform modules are stored in `./terraform/modules`. The following modules
are defined:

  * `settings`: Returns settings based on a development or production environment.
  * `clavius`: deploys a centralized team workstation to manage Callysto.
  * `hub`: deploys a standard Callysto JupyterHub environment.

### Makefile

The master `Makefile` provides an easy way to interact with Terraform to
deploy and manage infrastructure.

For example, to redeploy the `hub-dev` environment, do

```
  $ make terraform/destroy ENV=hub-dev
  $ make terraform/apply ENV=hub-dev
```

This will use the Terraform binary in `./bin` to apply the Terraform configuration
defined in `./terraform/hub-dev`.

The `Makefile` arguments correspond to the common Terraform commands: `plan`, `apply`,
`destroy`, etc.

The `Makefile` is only a convenience and it is not required. If you want to use Terraform
directly, simply do:

```
$ cd terraform/hub-dev
$ ../../bin/<arch>/terraform <action>
```

### Deploying an Environment

An "environment" is defined as any collection of related infrastructure.
Environments are grouped in directories under the `terraform` directory.

Use the `Makefile` to deploy an environment:

```
$ make terraform/plan ENV=hub-dev
$ make terraform/apply ENV=hub-dev
```

## Ansible

Resources are _provisioned_ with Ansible. Contrast this with Terraform
which _deploys_ resources.

### Makefile

The master `Makefile` can assist with running various Ansible commands.
Using the `Makefile` makes it easy to ensure the command has all required
information.

If you prefer to not use the `Makefile`, check the contents of the `Makefile`
for all required Ansible arguments and then just run `ansible` or
`ansible-playbook` manually.

## Ansible Inventory

Inventory is handled through the
[ansible-terraform-inventory](https://github.com/jtopjian/ansible-terraform-inventory)
plugin. This plugin reads in the Terraform State of a deployed enviornment and
creates an appropriate Ansible Inventory result.

## Running Ansible

To deploy a hub, run:

```
  $ make ansible/playbook/check PLAYBOOK=hub ENV=hub-dev
  $ make ansible/playbook PLAYBOOK=hub ENV=hub-dev
```

> Note: `check` might fail because Ansible's inability to accurately do noop.

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
  $ openssl req -new -x509 -days 3650 -nodes -sha256 -out saml.crt -keyout saml.pem -subj "/C=CA/ST=Alberta/L=Calgary/O=Callysto Dev/OU=Infra/CN=hub-dev.callysto.farm"
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

## Let's Encrypt Integration

Let's Encrypt is used for all SSL certificates. We use
[dehydrated](https://github.com/lukas2511/dehydrated) combined with OpenStack
Designate to generate wildcard certificates. The certificates are stored on the
Clavius server and then pushed to the various Callysto servers.

Dehydrated is stored in the `vendor` directory.

The configuration is stored in `letsencrypt`.

## Direnv Integration for Dev Environment

The direnv is storing set of variables required by Terraform, Ansible and Letsencrypt
in one .envrc file to speed up deployment (only dev environment at the moment).

A binary for both Linux and Darwin (Mac) have been bundled in the `/bin` directory.

## Metrics and OS Statistics

The system of gathering statistics from the Callysto environment has been introduced (thanks to Ian Allison's initial work)
- [Grafana](https://grafana.com/) provides graphs for default stats
- [Prometheus](https://prometheus.io) is used to gather and store all information
- [Prometheus Exporter](https://github.com/UnderGreen/ansible-prometheus-node-exporter.git) and [cAdvisor](https://github.com/google/cadvisor) are being installed on monitored nodes
All above systems are behind Nginx and/or Apache2 as proxy for SSL/TLS communication

To view default graphs please follow to dashboards at *https://stats.<domain_name>*/grafana/
