# Callysto Ops Processes

The following sections describe various operational processes for managing
the Callysto environment.

# Table of Contents

> Infrastructure Management

* [Starting from Scratch](#starting-from-scratch)
* [Generating Let's Encrypt Certificates](#generating-lets-encrypt-certificates)
* [Building the Hub Image](#building-the-hub-image)
* [Deploying the Production Environment](#deploying-the-production-environment)
* [Deploying the Development Environment](#deploying-the-development-environment)
* [Deploying a CI Environment](#deploying-a-ci-environment)
* [Deploying a Custom Environment](#deploying-a-custom-environment)
* [Building Docker Images](#building-docker-images)
* [Installing hubtraf](#installing-hubtraf)
* [Adding a Base System Package](#adding-a-base-system-package)
* [Managing SSH Keys](#managing-ssh-keys)

> User Management

* [Creating an Announcement](#creating-an-announcement)
* [Modifying a Notebook Template](#modifying-a-notebook-template)
* [Quota Management](#quota-management)

# Infrastructure Management

## Starting from Scratch

If all of the existing Callysto infrastructure was lost or if you are creating
your own clone of Callysto, start here.

### OpenStack

As mentioned in the [README](README.md), Callysto is configured specifically to
run in an OpenStack cloud.

Make sure your OpenStack account has a sufficient quota to run all required
resources. (TODO: document the exact quota requirements)

Download or generate a standard `openrc` file. All commands below assume you
have sourced this file into your shell environment.

> Do not store credentials in this repository!

### Clone this Repository

Clone this repository to your local workstation:

```
$ git clone https://github.com/callysto/infrastructure callysto-infra
$ cd callysto-infra
```

> All future commands will assume you are in the `callysto-infra` directory
> unless otherwise noted.

Next, create an ssh keypair:

```
$ ssh-keygen -t rsa -f ./keys/id_rsa
```

> Do not store keys in this repository!

Next, set up Terraform:

```
$ pushd terraform
$ make setup
$ popd
```

> Read the `setup` task in the `Makefile` to understand all steps being performed.

Next, set up Ansible

```
$ pushd ansible
$ make setup
$ popd
```

> Read the `setup` task in the `Makefile` to understand all steps being performed.

### Domain Names

The Callysto infrastructure relies on two domain names: one for production
and one for development.

The production domain name can be managed outside of this repository.

The development domain name must be added to OpenStack Designate. Currently
this is done manually since it is a one-time step. Use the `designate` command
or the Horizon web interface to add the domain/zone.

Make note of the Zone ID and set it as the `zone_id` in a `hub-*/main.tf` file.

### Bootstrapping

Create a central workstation which can be used by all members of the Callysto
team. This workstation will be called "clavius", in reference to the
[moon base](https://en.wikipedia.org/wiki/Clavius_Base).

First, use Terraform to build the clavius infrastructure. Review the
`terraform/modules/clavius/*.tf` and `terraform/clavius/main.tf` files for
details. Make any changes as appropriate.

Once reviewed, run:

```
$ pushd terraform
$ make env=clavius apply
$ popd
```

Once Terraform has finished, use Ansible to provision it. Review the
`ansible/plays/init.yml` and `ansible/plays/clavius.yml` files to understand
the steps that will be applied.

Next, add the public keys of all team members to
`ansible/group_vars/all/local_vars.yml`. For example:

```
ssh_public_keys:
  - name: Andrew
    user: ptty2u
    state: present
    public_key: '...'
```

Finally, run Ansible:

```
$ pushd ansible
$ make env=clavius clavius/init/apply
$ make env=clavius clavius/apply
$ popd
```

Once this is complete, log in to `clavius.callysto.farm` (or whatever the name
you chose is) via ssh to finish the process:

```
$ ssh ptty2u@clavius.callysto.farm
```

First, configure a LUKS-based encrypted volume:

```
$ sudo cryptsetup -y -v luksFormat /dev/sdb # password is in 1pw
$ sudo cryptsetup open /dev/sdb work
$ sudo mkfs.ext4 /dev/mapper/work
$ mkdir /home/ptty2u/work
$ sudo mount /dev/mapper/work /home/ptty2u/work
$ sudo chown -R ptty2u:ptty2u /home/ptty2u/work
```

Next, re-clone the infrastructure repository and repeat the initial setup:

```
$ git clone https://github.com/callysto/infrastructure callysto-infra
$ cd callysto-infra
$ ssh-keygen -t rsa -f ./keys/id_rsa
$ pushd ansible
$ make setup
$ popd
```

> Notice how you've just repeated the steps from the beginning of this section.
> This is intentional as there's an element of bootstrapping to get started.
>
> Additionally, you should also copy the `terraform/clavius/terraform.tfstate`
> file from the workstation which deployed clavius to the new location, too.

## Generating Let's Encrypt Certificates

Let's Encrypt is used for SSL certificates. We leverage wildcard certificates
to reduce the amount of certificates we need to obtain from Let's Encrypt.

The wildcard certificate is generated locally on Clavius and then pushed to
the Callysto infrastructure.

To generate the wildcard certificates, first review the following files:

* `letsencrypt/<env>/config`
* `letsencrypt/<env>/hook.sh`
* `letsencrypt/<env>/domains.txt`

Once the files are configured correctly, run:

```
pushd letsencrypt
make generate env=dev
popd
```

Finally, set the `callysto_ssl_cert_dir` variable in your `local_vars.yml` file.
The value should be the _local_ path to where the certificates are located. For
example: `~/work/callysto-infra/letsencrypt/dev/certs/star_callysto_farm`.

`callysto_ssl_cert_dir` is used by the `callysto-html` ansible role to copy the
certificates found in this directory to `/etc/pki/tls/` on the remote servers.

## Building the Hub Image

To help reduce the amount of time it takes to deploy a hub, you can create an
image with the essential components pre-installed. This is done using Packer.

As a pre-requisite, you will need to ensure an OpenStack security group exists
for Packer:

```
$ pushd terraform
$ make env=packer apply
$ popd
```

Next, build the image:

```
$ pushd packer
$ make build/hub
$ popd
```

You only need to repeat this process when there are significant OS upgrades
or a new ZFS kernel module.

By default, Terraform is configured to automatically search for the generated
"callysto-hub" image and use this image to build the hub (see below).

## Deploying the Production Environment

Deploying the production environment is different than deploying a development
environment (described below).

While Terraform does a great job at handling the full lifecycle of compute
resources, we want to take certain measures to ensure data doesn't get
accidentally deleted.

First, create two 250gb volumes:

```
$ openstack volume create --size 250 hub.callysto.ca-home-1
$ openstack volume create --size 250 hub.callysto.ca-home-2
```

Next, allocate a Floating IP:

```
$ openstack floating ip create public
```

Next, create a new Terraform environment:

```
$ pushd terraform
$ make new-hub/prod env=prod
```

Next, edit `hub-prod/main.tf` and modify as needed. Notably:

1. Add the 2 volume UUIDs to `existing_volumes`.
2. Add the floating IP to `existing_floating_ip`.

Finally, deploy the hub:

```
$ make apply env=hub-prod
$ popd
```

## Deploying the Development Environment

To deploy a development environment, run the following:

```
$ pushd terraform
$ make env=hub-dev apply
$ pushd ../ansible
$ make env=hub-dev hub/apply
$ popd
$ popd
```

## Deploying a Custom Environment

To deploy a custom environment, run the following:

```
$ pushd terraform
$ make new-hub/dev env=<name>
```

This will do the following:

1. Create a `terraform/hub-<name>` directory with customized `main.tf` file.
2. Create a `ansible/group_vars/hub-<name>` directory with a copy of `local_vars.yml`.

## Building Docker Images

Docker images are used for the individual Notebooks run from the hub. To build
and manage these images, do the following on Clavius:

First, clone the `docker-stacks` repo:

```
$ pushd ~/work
$ git clone https://github.com/callysto/docker-stacks
$ git checkout ianabc
```

> Make sure you are on the `ianabc` branch.

Next, build the images in succession:

```
$ make build/base-notebook
$ make build/minimal-notebook
$ make build/scipy-notebook
$ make build/pims-minimal
$ make build/pims-r
```

If Swift is being used for file storage, build the Swift image:

```
$ make build/callysto-swift
```

Alternatively, build and test the entire stack all at once:

```
$ make build-test-all
```

Once the images have been built, you can push them to DockerHub by doing:

```
$ source ~/work/rc/dockerhub
$ make callysto/push
```

## Installing hubtraf

`hubtraf` is a utility which can simulate traffic to a JupyterHub environment.
This is useful to check if the Hub is working as well as to do benchmarking.

To install `hubtraf`, do the following on Clavius:

```
$ pushd ~/work
$ git clone https://github.com/yuvipanda/hubtraf
$ cd hubtraf
$ pip3.6 install -e .
$ popd
```

### Using hubtraf

Run the following:

```
$ hubtraf --json --user-session-min-runtime 10 --user-session-max-runtime 30 --user-session-max-start-delay 5 https://hub-dev.callysto.farm 1
```

Tweak the parameters as required.

> Note: jupyterhub _must_ be configured with the "dummy" authenticator for `hubtraf` to work.

## Installing a Base System Package

A Base Package is something you want to see on _all_ servers: `vi`, `tmux`, etc.
These should be generic packages that are applicable to a wide range of processes.

To add a base package, edit the `ansible/roles/internal/base-packages/vars/RedHat.yml`
file.

## Managing SSH Keys

You can define SSH keys in the `local_vars.yml` file under the `ssh_public_keys`
variable. If you want to define keys which should be deployed to _everything_,
define them in the `group_vars/all/local_vars.yml` file.

For per-environment keys, define them in `group_vars/<group name>/local_vars.yml`.

The format of the `ssh_public_keys` dict is:

```
ssh_public_keys:
  username:
    user: <local user>
    state: present/absent
    public_key: 'ssh-rsa ...'
```

Ansible will merge all `ssh_public_key` definitions across all variable files.

# User Management

## Creating an Announcement

1. Set the `jupyterhub_announcement` variable in the `local_vars.yml` file.
2. Run:

```
$ pushd ansible
$ make env=<env> hub/apply
$ popd
```

This will set the announcement in the following locations:

* JupyterHub control panel
* Jupyter Notebook file index / tree page
* Jupyter Notebook notebook page

## Modifying a Notebook Template

If you need to alter the actual Jupyter Notebook itself, choose the appropriate
page to update from here: https://github.com/jupyter/notebook/tree/master/notebook/templates.

Next, copy the page to `ansible/roles/internal/jupyterhub/templates/notebooks`
(if it doesn't already exist) and alter it accordingly.

Finally, add the file to Ansible by editing `ansible/roles/internal/jupyterhub/tasks/main.yml`.

Because Jupyter Notebook _also_ uses Jinja templating, it will interfere with
Ansible's template processing. Therefore, you must wrap most template tags
with:

```
{% raw -%}
{% endraw -%}
```

See the `ansible/roles/internal/jupyterhub/templates/notebooks/notebook.html.j2`
file as an example.

## Quota Management

The `ansible/Makefile` contains a handful of tasks to manage a user's quota:

```
$ pushd ansible
$ make quota/get env=<env>
$ make quota/get env=<env> user=<user>
$ make quota/set env=<env> user=<user> refquota=<10G>
$ popd
```
