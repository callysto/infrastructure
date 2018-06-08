# Callysto Ops Processes

The following sections describe various operational processes for managing
the Callysto environment.

* [Starting from Scratch](#starting-from-scratch)
* [Building the Hub Image](#building-the-hub-image)
* [Deploying the Development Environment](#deploying-the-development-environment)
* [Deploying a CI Environment](#deploying-a-ci-environment)
* [Building Docker Images](#building-docker-images)
* [Installing hubtraf](#installing-hubtraf)

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

Make note of the Zone ID and set it in `terraform/modules/dns/main.tf`.

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

## Deploying the Development Environment

To deploy a development environment, run the following:

```
$ pushd terraform
$ make env=hub-dev apply
$ pushd ../ansible
$ make env=hub-dev hub/init/apply
$ make env=hub-dev hub/apply
$ popd
$ popd
```

There can only be one development environment running at a time. If you want to
run a second development environment, you have two options:

1. Copy `terraform/hub-dev` as `terraform/hub-mydev` and replace all occurrences
of `hub-dev` with `hub-mydev` within the `main.tf` file.

2. Use the `terraform/hub-ci` environment or copy `terraform/hub-ci` to
`terraform/hub-mydev`. There is no need to edit `main.tf` as the `hub-ci`
environment will generate an environment with a random name. If you don't want
a random name, go with Option 1 above.

## Deploying a CI Environment

The CI environment is meant to be a disposable development environment for use
with automated acceptance testing. You normally won't launch a CI environment
yourself, but a CI tool, such as Jenkins or Travis, will create (and destroy)
it.

To deploy a ci environment, have a CI system run the following:

```
$ cd terraform
$ make env=hub-dev apply
$ cd ../ansible
$ make env=hub-dev hub/init/apply
$ make env=hub-dev hub/apply
```

## Building Docker Images

Docker images are used for the individual Notebooks run from the hub. To build
and manage these images, do the following on Clavius:

> Alternatively, you can forgo building images and just make changes to the
> `Dockerfile` files where appropriate. Pushing the changes to the Github repo
> will trigger Travis to build the images. Upon merging changes to the `ianabc`
> branch, the images will be pushed to DockerHub.

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
