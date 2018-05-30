# Callysto Ops Processes

The following sections describe various operational processes for managing
the Callysto environment.

* [Starting from Scratch](#starting-from-scratch)
* [Deploying the Development Environment](#deploying-the-development-environment)
* [Deploying a CI Environment](#deploying-a-ci-environment)

## Starting from Scratch

If all of the existing Callysto infrastructure was lost or if you are creating
your own clone of Callysto, start here.

### OpenStack Access

The Callysto infrastructure runs exclusively on OpenStack. In order to exactly
reproduce everything here, you will need access to an OpenStack cloud with the
following services:

* Nova
* Cinder
* Neutron
* Designate

Download or generate a standard `openrc` file. All commands below assume you
have sourced this file into your shell environment.

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

Next, install the required external roles:

```
$ pushd ansible/scripts
$ ./role_update.sh
$ popd
```

Finally, set up the Ansible inventory script:

```
$ pushd ansible
$ make setup
$ popd
```

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

Next, add the public keys of all users to
`ansible/group_vars/all/local_vars.yml`. For example:

```
ssh_public_keys:
  - name: Andrew
    user: ptty2u
    state: present
    public_key: '...'
```

```
$ pushd ansible
$ make env=clavius clavius/init/apply
$ make env=clavius clavius/apply
$ popd
```

Once this is complete, log in to `clavius.callysto.farm` (or whatever the name
you chose is) to finish the process.

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
$ pushd scripts
$ ./role_update.sh
$ popd
$ popd
```

> Notice how you've just repeated the steps from the beginning of this section.
> This is intentional as there's an element of bootstrapping to get started.
>
> Additionally, you should also copy the `terraform/clavius/terraform.tfstate`
> file to the new location, too.

## Deploying the Development Environment

To deploy a development environment, run the following:

```
$ cd terraform
$ make env=hub-dev apply
$ cd ../ansible
$ make env=hub-dev hub/init/apply
$ make env=hub-dev hub/apply
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
