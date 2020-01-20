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
* [DNS Management](#dns-management)
* [Replacing a ZFS Pool](#replacing-a-zfs-pool)

> User Management

* [Creating an Announcement or Alert](#creating-an-announcement-or-alert)
* [Setting a Getting Started Notebook](#setting-a-getting-started-notebook)
* [Modifying a Notebook Template](#modifying-a-notebook-template)
* [Determining a User's Hash](#determining-a-users-hash)
* [Managing Admin Users](#managing-admin-users)
* [Quota Management](#quota-management)
* [Logout Redirect](#logout-redirect)

> edX Management

* [Installing Tutor](#installing-tutor)
* [Creating a new Tutor environment](#creating-a-new-tutor-environoment)
* [Building a Custom edX Image](#building-a-custom-edx-image)
* [Upgrading Tutor](#upgrading-tutor)
* [Updating the Callysto edX Theme](#updating-the-callysto-edx-theme)
* [Deploying an edX Environment](#deploying-an-edx-environment)
* [Updating edX After Deployment](#updating-edx-after-deployment)
* [Tutor Plugins](#tutor-plugins)
* [Deleting a Course](#deleting-a-course)
* [Creating edX Users](#creating-edx-users)
* [Changing a User's Password](#changing-a-users-password)
* [Accessing a Django Shell](#accessing-a-django-shell)

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
$ make packer/build/centos
```

You only need to repeat this process when there are significant OS upgrades
or a new ZFS kernel module.

By default, Terraform is configured to automatically search for the generated
"callysto-centos" image and use this image to build the hub (see below).

## Callysto Environments

When the Callysto project started, it consisted of a single type of
environment: a single JupyterHub virtual machine.

Since the project has progressed, new components have been added to the
infrastructure in order to add different features. It's possible to deploy
Callysto using one of several different combinations of components. We call
a combination an "environment".

To see the different types of environments available, run the following:

```
make terraform/list-environments
```

To see the corresponding Ansible playbook, run the following:

```
make ansible/list-environments
```

For example, the Terraform environment `dev-hub-aio` will have an Ansible
playbook called `hub-aio`.

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
$ make terraform/new TYPE=hub-prod-aio ENV=hub-prod
```

Next, edit `terraform/hub-prod/main.tf` and modify as needed. Notably:

1. Add the 2 volume UUIDs to `existing_volumes`.
2. Add the floating IP to `existing_floating_ip`.

Finally, deploy the hub:

```
$ make terraform/apply ENV=hub-prod
```

## Deploying a Development Environment

To deploy a development environment, first create the new environment from the
development template:
```
$ make terraform/new TYPE=dev-hub-aio NAME=hub-dev
```

Next, edit `terraform/hub-dev/main.tf` and modify as needed. Finally, deploy
the environment
```
$ make terraform/apply ENV=hub-dev
$ make ansible/playbook PLAYBOOK=hub-aio ENV=hub-dev GROUP=hub
```

## Deploying a Custom Environment

To deploy a custom environment, run the following:

```
$ make terraform/new TYPE=<type> ENV=<name>
```

This will do the following:

1. Create a `terraform/hub-<name>` directory with customized `main.tf` file.
2. Create a `ansible/group_vars/hub-<name>` directory with a copy of `local_vars.yml`.

## Building Docker Images

Docker images are used for the individual Notebooks run from the hub. To build
and manage these images, do the following on Clavius:

First, clone the `docker-stacks` repo:

```
$ cd ~/work
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

Once that has finished, you can update the Docker image on your deployed hubs.
To do this, log into a hub via SSH and then run:

```
docker image pull callysto/pims-r
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

## DNS Management

Callysto leverages Designate, the OpenStack DNS project, for API-based DNS
management. Ideally, you will want to register two domain names: one for
production and one for development.

Once they have been registered with a registrar (for example, Namecheap),
add them to OpenStack by using either the `openstack` command, `designate`
command, or the OpenStack web dashboard. For example:

```
openstack zone create --email <contact email> --description Production --ttl 60 mydomain.com
```

Once both zones have been registered, make note of their UUIDs and add them
to the `Makefile` under the following areas:

```
export DEV_CALLYSTO_DOMAINNAME := <dev domain>
export DEV_CALLYSTO_ZONE_ID := <zone uuid>

export PROD_CALLYSTO_DOMAINNAME := <dev domain>
export PROD_CALLYSTO_ZONE_ID := <zone uuid>
```

Once these are in place, DNS records will automatically be managed for
development environments.

For production environments, you will need to manage the records separately
from the actual resources. This is to help protect the records from
accidentally being deleted.

Modify the `terraform/prod-dns/main.tf` file with any changes you need to make
and then run:

```
make terraform/apply ENV=prod-dns
```

## Replacing a ZFS Pool

All user data on the hub is stored on a mirrored ZFS Pool within the hub.
There might come a time when either the pool runs out of space or
becomes corrupt and needs to be replaced.

First, use Terraform directly to create two new OpenStack volumes:

```
cd ~/work/callysto
source ../rc/openrc
openstack volume create --type encrypted --size 300 hub.callysto.ca-new-home-1
openstack volume create --type encrypted --size 300 hub.callysto.ca-new-home-2
```

`hub.callysto.ca-new-home-1` is a suggested name. It should be unique and
describe its purpose well.

Next, attach _one_ of the volumes to the hub:

```
openstack server add volume hub.callysto.ca <volume id>
```

Once the volume is attached, create a new pool on the hub itself. Run
the following after connecting to the hub via SSH:

```
zpool create -f tank2 /dev/disk/by-id/<scsi-id>
```

Where `scsi-id` is the following:

```
scsi-0QEMU_QEMU_HARDDISK_<first 20 characters of volume id>
```

For example:

```
scsi-0QEMU_QEMU_HARDDISK_992a01ff-8d31-4a16-a
```

After this command is run, a new pool called `tank2` will exist.

Next, create a snapshot on the old pool:

```
zfs snapshot -r tank@migrate
```

> NOTE: if the pool is out of space, you will need to delete some files in
> order to make the snapshot.

One the snapshot is created, you can copy the data from the old pool to
the new pool:

```
zfs send -R tank@migrate | zfs receive -F tank2
```

This process will take roughly 2-3 hours.

Once it has completed, stop the JupyterHub service and export the old pool:

```
service jupyterhub stop
zpool export tank
```

Then detach the volumes from the instance by running the following commands
on Clavius:

```
openstack server remove volume hub.callysto.ca <volume id>
```

Then back on the hub, export the new pool and re-import it with
the name `tank` and start JupyterHub:

```
zpool export tank2
zpool import tank2 tank
service jupyterhub start
```

Once you've verified the hub is working, you may delete the original volumes:


```
openstack volume delete <old-vol-1>
openstack volume delete <old-vol-2>
```

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

# edX Management

Management of edX is handled by [Tutor](https://docs.tutor.overhang.io).

There are two main concepts to understand when it comes to managing edX:

1. Building a custom edX image.
2. Deploying an edX environment.

Tutor generates files for both of these actions under the same directory, so
some files will be used on Clavius and others will be used on the deployed
server.

## Installing Tutor

To install Tutor and the Callysto Tutor plugin, run:

```
make tutor/install
```

## Creating a New Tutor Environment

Creating a Tutor environment is required if you want to build a custom
Tutor image. This is almost always required since our production edX
environment uses extra plugins and a customized theme.

Unlike creating a new Terraform environment, there isn't a `make`
command that creates a tutor environment. Instead, you clone it
from Cybera's internal Git service.

For example, to create an environment called `edx-prod`,  run
the following:

```
cd ~/work/callysto-infra/tutor
git clone https://git.cybera.ca/Callysto/edx-tutor-image edx-prod
cd edx-prod
```

> `edx-prod` should already exist on Clavius.

To create another environment, perhaps to test changes, you can do
something like the following:

```
cd ~/work/callysto-infra/tutor
git clone https://git.cybera.ca/Callysto/edx-tutor-image edx-NAME
cd edx-NAME
```

where `NAME` is a name of your choice (`dev`, `jttest`, etc).

The cloned repository contains a large number of files and directories
and most of these actually go unused. We're really only concerned with
the following:

* `config.yml`
* `env/build/openedx/Dockerfile`
* `env/build/openedx/requirements/`
* `env/build/openedx/themes`

## Building the Production edX Image

After you have an edx environment cloned on Clavius, you can being making
any changes you need to customize the Open edX Docker image. Details about
how to do this can be found at:

* https://docs.tutor.overhang.io/local.html
* https://docs.tutor.overhang.io/dev.html

> NOTE: If `tutor config save` is run, it might overwrite some of the
> customizations done to the build files. Make sure to run `git status`
> and verify if any changes need reverted.

You can also look at the git repository history to see the previous changes
that have been made:

```
git log
```

Once your modifications are made, you can build an image.

It's generally best to rebuild an image from scratch rather than have the
build use existing cached layers from previous Docker builds. To do this,
run the following:

```
docker image ls callysto/openedx -q | xargs docker image rm -f
```

Once the cached image layers are removed, run:

```
cd ~/work/callysto-infra
make tutor/image/build ENV=edx-prod
```

The resulting image will then be available on Docker Hub at:

```
callysto/openedx:edx-prod
```

The above examples used `edx-prod` as the environment, but remember that you
can create your own edx environments in Clavius and name them whatever you
would like. See the section on "Creating a New Tutor Environment" for more
information.

## Updating the Callysto edX Theme

The Callysto edX Theme is based on Tutor's
[Indigo theme](https://github.com/overhangio/indigo). The build files for
this theme should be located at:

```
~/work/tutor-indogo
```

If that directory doesn't exist, run the following:

```
cd ~/work
git clone https://github.com/callysto/tutor-indigo
cd tutor-indigo
git checkout -b callysto
```

Inside this directory is a `config.yml` file. You can edit this file to
apply some customizations to the theme.

You can also edit some of the other files if you need to make additional
changes to the theme. For example, replace
`./theme/lms/static/images/logo.png` with a custom logo.

Once you've made your changes, first make sure to commit them to git:

```
git add .
git commit -m "Summary of changes"
git push -u origin callysto
```

Then "render" the theme:

```
cd ~/work/callysto-infra
make tutor/theme/render ENV=hub-prod
```

Once the theme is rendered, you will need to rebuild the Tutor Open edX
Docker image. See the section titled "Building the Production edX Image"
for more information.

## Upgrading Tutor

New versions of Tutor contain bug fixes and updates for all aspects of the
edX environment. In order to take advantage of all of these updates, each
Tutor environment we've created needs to be refreshed.

### On Clavius

Tutor environments are stored in `~/work/callysto-infra/tutor`. To refresh
a Tutor environment, do the following:

1. Upgrade Tutor itself

This command will upgrade the Python Tutor package:

```
cd ~/work/callysto-infra
make tutor/upgrade
```

2. Upgrade the environment:

This command will create a new Tutor environment and move all local
changes to the new environment.

```
make tutor/upgrade/environment ENV=edx-prod
```

3. Build the new image:

See the "Building the Production edX Image" section for how to do this.

4. Modify the `config.yml` file for Ansible:

Do this by reviewing `~/.local/lib/python3.6/site-packages/tutor/templates`
and `~/work/callysto-infra/anisble/roles/internal/callysto-edx/templates/tutor_config.yml.j2`
and modifying the Ansible template accordingly.

Doing a `diff` on both files will result in a lot of changes reported, but
most values won't need to be changed. Look for hard-coded version strings
that have been updated as well as any new settings that should be added.

## Deploying an edX Environment

First, build the infrastructure using Terraform:

```
cd ~/work/callysto-infra
make terraform/new TYPE=dev-edx-aio ENV=<env>
```

Where `env` is a name of your choice. `dev`, `test`, `your-name` are all good
choices.

Next, modify any settings in
`~/work/callysto-infra/ansible/group_vars/<env>/local_vars.yml`. The edX
settings are all prefixed with `edx_`.

Next, deploy the infrastructure:

```
make terraform/apply ENV=<env>
```

After that, run the edX Ansible playbook:

```
make ansible/playbook ENV=<env> PLAYBOOK=edx-aio
```

At this point, the virtual machine will be running, have Tutor installed,
and have a customized Tutor `config.yml` file located at
`/tank/tutor/config.yml`. This config file will have the hostname of the
virtual machine set as well as any configuration items you had in the
`local_vars.yml` file.

You can now SSH to the host and begin using Tutor to launch edX.

If this is the first time you're starting the environment, you
will need to log into the virtual machine via SSH and then run:

```
tutor config save
tutor local start --detach
tutor local init
tutor local https create
tutor local start --detach
```

If this is a dev environment, you can now access edX by replacing the word
"edx" of the dev domain name with "courses" and "studio". For example, if your
dev domain name was "edx.engaged-peacock.callysto.farm", you can visit:

* https://courses.engaged-peacock.callysto.farm
* https://studio.engaged-peacock.callysto.farm

## Updating edX After Deployment

If you have made changes to the edX image and need to update it in an existing
environment, then do the following:

First, create the new image following the process defined above.

Next, stop and start edX with Tutor:

```
tutor local pullimages
tutor local stop
tutor local start --detach
```

If Tutor gives an error about not finding a container, then you can stop it
using Docker directly:

```
docker ps -a -q | xargs docker stop
docker ps -a -q | xargs docker rm
tutor local start --detach
```

## Tutor Plugins

In order to modify how Tutor behaves, we need to interact with it through a
plugin. There is a Callysto plugin availble at
https://github.com/callysto/tutor-callysto which is downloaded and installed
upon running `make tutor/install`.

See the Tutor documentation (and example plugins) about how to use the Tutor
plugin API:

* https://docs.tutor.overhang.io/plugins.html

When you've made changes to the `tutor-callysto` plugin, run:

```
cd ~/work/
pip3.6 --user --upgrade ./
```

## Deleting a Course

If you need to delete a course, run the following on the edX server:

```
tutor local run cms -- ./manage.py cms delete_course <course-id>
```

Where `course-id` is something like `course-v1:Cybera+CYB101+2019`.

## Creating edX users

To create users, do:

```
tutor local createuser --staff --superuser yourusername user@email.com
```

## Changing a User's Password

If you need to change a user's password through Django, run:

```
tutor local run lms ./manage.py lms shell

>>> from django.contrib.auth.models import User
>>> u = User.objects.get(username='sysadmin')
>>> u.set_password('new-password')
>>> u.save()
```

## Accessing a Django Shell

To get access to a Django shell for any kind of Django-based management, run:

```
tutor local run lms ./manage.py lms shell
```


