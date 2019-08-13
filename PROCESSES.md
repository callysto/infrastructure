# Callysto Ops Processes

The following sections describe various operational processes for managing
the Callysto environment.

# Table of Contents

> Infrastructure Management

* [Starting from Scratch](#starting-from-scratch)
* [Backing up Important Files](#backing-up-important-files)
* [Generating Let's Encrypt Certificates](#generating-lets-encrypt-certificates)
* [Deploying Certificates](#deploying-certificates)
* [Building the Hub Image](#building-the-hub-image)
* [Deploying the Production Environment](#deploying-the-production-environment)
* [Deploying the Development Environment](#deploying-the-development-environment)
* [Deploying a CI Environment](#deploying-a-ci-environment)
* [Deploying a Custom Environment](#deploying-a-custom-environment)
* [Deploying Metrics Server](#deploying-metrics-server)
* [Building Docker Images](#building-docker-images)
* [Installing hubtraf](#installing-hubtraf)
* [Adding a Base System Package](#adding-a-base-system-package)
* [Managing SSH Keys](#managing-ssh-keys)
* [Modifying the JupyterHub Error Page](#modifying-the-jupyterhub-error-page)
* [SimpleSAMLphp Theme](#simplesamlphp-theme)

> User Management

* [Creating an Announcement or Alert](#creating-an-announcement-or-alert)
* [Setting a Getting Started Notebook](#setting-a-getting-started-notebook)
* [Modifying a Notebook Template](#modifying-a-notebook-template)
* [Determining a User's Hash](#determining-a-users-hash)
* [Managing Admin Users](#managing-admin-users)
* [Quota Management](#quota-management)
* [Logout Redirect](#logout-redirect)

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

Review and modify the `Makefile` to suit your environment.

Next, create an ssh keypair:

```
$ ssh-keygen -t rsa -f ./keys/id_rsa
```

> Do not store keys in this repository!

Next, set up Terraform:

```
$ make terraform/setup
```

> Read the `terraform/setup` task in the `Makefile` to understand all steps being performed.

Next, set up Ansible

```
$ make ansible/setup
```

> Read the `ansible/setup` task in the `Makefile` to understand all steps being performed.

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
$ make terraform/apply ENV=clavius
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
$ make ansible/playbook PLAYBOOK=init ENV=clavius GROUP=clavius
$ make ansible/playbook PLAYBOOK=clavius ENV=clavius GROUP=clavius
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
$ make anisble/setup
```

> Notice how you've just repeated the steps from the beginning of this section.
> This is intentional as there's an element of bootstrapping to get started.
>
> Additionally, you should also copy the `terraform/clavius/terraform.tfstate`
> file from the workstation which deployed clavius to the new location, too.

## Backing Up Important Files

If you review the `.gitignore` file for this repository, you'll see that it's
ignoring a good amount of files. Some of these files are being ignored because
of their sensitive nature. If we didn't ignore these files, we could not make this
a public repository.

However, these sensitive files are still critical to operations and need to be
backed up.

To configure backups, look at the bottom of the `local_vars.yml.example` file for
the `Infrastructure / Clavius backup` section. Copy these settings to the
`group_vars/all/local_vars.yml` file. Change the settings appropriately for your
environment.

Next, run the following:

```shell
$ make backup
```

The backup destination directory (by default, `~/work/backup`) should now be populated
with some files. We recommend running this `Make` task regularly copying these files
off-site.

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
make letsencrypt/generate ENV=dev
```

Finally, set the `callysto_ssl_cert_dir` variable in your `local_vars.yml` file.
The value should be the _local_ path to where the certificates are located. For
example: `~/work/callysto-infra/letsencrypt/dev/certs/star_callysto_farm`.

`callysto_ssl_cert_dir` is used by the `callysto-html` ansible role to copy the
certificates found in this directory to `/etc/pki/tls/` on the remote servers.

## Deploying Certificates

After the Let's Encrypt-based certificates have been generated, you can deploy them
one of two ways:

1. Run the full `hub.yml` playbook.
2. Deploy only the certificates by doing:

```
make ansible/playbook ENV=hub-prod GROUP=hub PLAYBOOK=deploy-certs
```

The above is useful for production environments where you _only_ want to deploy
the certificates.

Note that Apache will not be automatically restarted. You must do this manually.
This is to provide the ability to wait until a window to restart Apache.

## Building the Hub Image

To help reduce the amount of time it takes to deploy a hub, you can create an
image with the essential components pre-installed. This is done using Packer.

As a pre-requisite, you will need to ensure an OpenStack security group exists
for Packer:

```
$ make terraform/apply ENV=packer
```

Next, build the image:

```
$ make packer/build/hub
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
$ make terraform/hub/new/prod  ENV=hub-prod
```

Next, edit `terraform/hub-prod/main.tf` and modify as needed. Notably:

1. Add the 2 volume UUIDs to `existing_volumes`.
2. Add the floating IP to `existing_floating_ip`.

Finally, deploy the hub:

```
$ make terraform/apply ENV=hub-prod
```

## Deploying the Development Environment

To deploy a development environment, first create the new environment from the
development template:
```
$ make terraform/hub/new/dev ENV=hub-dev
```

Next, edit `terraform/hub-dev/main.tf` and modify as needed. Finally, deploy
the environment
```
$ make terraform/apply ENV=hub-dev
$ make ansible/playbook PLAYBOOK=hub ENV=hub-dev GROUP=hub
```

## Deploying a Custom Environment

To deploy a custom environment, run the following:

```
$ make terraform/hub/new/dev ENV=<name>
```

This will do the following:

1. Create a `terraform/hub-<name>` directory with customized `main.tf` file.
2. Create a `ansible/group_vars/hub-<name>` directory with a copy of `local_vars.yml`.

## Deploying Metrics Server

To deploy metrics/stats server, make sure the ENVIRONMENT variable is set to *DEV* or *PROD* in the local_vars.yml and TF/stats/main.tf
Additionally, to enable zfs storage for stats set zfs_containers and zfs_pool_name in local_vars.yml

Then run the following:
```
$ make terraform/apply ENV=stats
$ make ansible/playbook PLAYBOOK=stats ENV=stats GROUP=stats
```

To access metrics please go to https://stats.<domain_name>/grafana/ in a browser and log in with default Grafana password to set a new one. Please store the password in password manager like 1password.

## Building Docker Images

Docker images are used for the individual Notebooks run from the hub. To build
and manage these images, do the following on Clavius:

First, clone the `docker-stacks` repo:

```
$ pushd ~/work
$ git clone https://github.com/callysto/docker-stacks
$ cd docker-stacks
$ git checkout ianabc
```

> Make sure you are on the `ianabc` branch.

Next, build the images in succession:

```
$ make build/base-notebook
$ make build/minimal-notebook DARGS="--build-arg BASE_CONTAINER=callysto/base-notebook"
$ make build/scipy-notebook DARGS="--build-arg BASE_CONTAINER=callysto/minimal-notebook"
$ make build/pims-minimal DARGS="--build-arg BASE_CONTAINER=callysto/scipy-notebook"
$ make build/pims-r DARGS="--build-arg BASE_CONTAINER=callysto/pims-minimal"
```

If Swift is being used for file storage, build the Swift image:

```
$ make build/callysto-swift DARGS="--build-arg BASE_CONTAINER=callysto/pims-r"
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

## Modifying the JupyterHub Error Page

To modify the JupyterHub Error page, edit the template located at
`ansible/roles/internal/jupyterhub/templates/hub-error.html.j2`.

Since both Ansible and JupyterHub use Jinja, this is a double-nested Jinja
file which can make alterations difficult. Make sure you wrap the
JupyterHub-specific Jinja logic in `{% raw -%}` tags.

You can change the value of the displayed email address by setting the
`support_email` variable in the `local_vars.yml` file.

## SimpleSAMLphp Theme

SimpleSAMLphp handles the authentication when the `shib` authenticator
is used.

You can apply a custom SimpleSAMLphp theme to customize the look of the
login and logout pages.

See https://github.com/callysto/callysto-ssp-theme as an example of
how to build a theme.

To set a custom theme, modify the following settings in `local_vars.yml`:

* `ssp_theme_name`
* `ssp_theme_repo`
* `ssp_theme_version`
* `ssp_theme_dir`

# User Management

## Creating an Announcement or Alert

1. Set the `jupyterhub_announcement` or `jupyterhub_alert` variable in the `local_vars.yml` file.
2. Run:

```
$ make ansible/playbook ENV=<env> GROUP=hub PLAYBOOK=hub
```

This will set an announcement or alert in the following locations:

* JupyterHub control panel
* Jupyter Notebook file index / tree page
* Jupyter Notebook notebook page

## Setting a Getting Started Notebook

When a user logs in for the first time, it's sometimes helpful to have an
initial notebook available to them. This is known as a Getting Started notebook.

To enable this, set the `jupyterhub_getting_started_url` variable in the
`local_vars.yml` file. This should be a direct link to an `.ipynb` file. For
example: `https://raw.githubusercontent.com/callysto/getting-started/master/getting-started.ipynb`

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

## Determining a User's Hash

When a user logs in for the first time, SimpleSAMLphp will generate a unique
hash of that user's username. This provides two benefits:

1. It allows a user to log in with the same username from different sources
(ex: Google and a Federation) and not have the accounts collide.
2. It prevents any type of identifiable information of that user being stored
within the hub.

The user's home directory will then be `/tank/home/<hash>` instead of
`/tank/home/<readable username>`.

However, this makes managing users more difficult because we have no way of
easily determining a user's home directory. For example, if user
john.doe@example.com reports a problem, there's no immediate way of determining
if `/tank/home/3a33be55004107d5202a4fcf32a0a2d804a9e137` is their home
directory or if `/tank/home/6fc583e6ba82d7c7f1e6fd7908afe48906e1093f` is.

We have created a script located at `/usr/local/bin/findhash.php` to help
assist with this problem.

You can run this script directly on the hub by doing:

```
$ /usr/local/bin/findhash.php john.doe@example.com
```

Or by running the following task on Clavius:

```
make user/findhash USER=john.doe@example.com ENV=hub-prod
```

## Managing Admin Users

To grant admin privileges to certain users, first find their hash. Next,
edit the `local_vars.yml` file and add them to the `jupyterhub_admin_users`
variable.

## Quota Management

The `Makefile` contains a handful of tasks to manage a user's quota:

> Note: <user>` will be the _hash_ of the user and not the readable username.

```
$ make quota/get ENV=<env>
$ make quota/get ENV=<env> USER=<user>
$ make quota/set ENV=<env> USER=<user> REFQUOTA=<10G>
```

## Logout Redirect

When a user logs out, they will be redirected to `/simplesaml/logout.php`. To
set this to a custom URL, set the `jupyterhub_shib_return_url` setting in
`local_vars.yml`.
