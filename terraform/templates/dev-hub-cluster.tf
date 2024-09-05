## Development JupyterHub Cluster Environment
## Development JupyterHub Cluster Environment
terraform {
  required_providers {
    ansible = {
      source  = "nbering/ansible"
      version = "~>1.0"
    }

    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

# These are set by the Makefile
variable "DEV_CALLYSTO_DOMAINNAME" {}

variable "DEV_CALLYSTO_ZONE_ID" {}

resource "random_pet" "name" {
  length = 2
}

# These represent settings to tune the hub you're creating
locals {
  # Global Settings
  image_name   = "Alma Linux 9"
  network_name = "default"
  network_id   = "b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  key_name     = "key-${random_pet.name.id}"
  zone_id      = "${var.DEV_CALLYSTO_ZONE_ID}"

  # Sharder Settings
  sharder_name = "hub-${random_pet.name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"

  # Sharder floating IP settings
  sharder_create_floating_ip   = "false"
  sharder_existing_floating_ip = ""

  # SSP Settings
  ssp_name                 = "ssp-${random_pet.name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"
  ssp_create_floating_ip   = "false"
  ssp_existing_floating_ip = ""

  # Hub 01 Settings
  hub01_name                 = "hub-01-${random_pet.name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"
  hub01_create_floating_ip   = "false"
  hub01_existing_floating_ip = ""

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  hub01_existing_volumes = []

  # Stats Settings
  stats_name                 = "stats-${random_pet.name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"
  stats_create_floating_ip   = "false"
  stats_existing_floating_ip = ""
  stats_existing_volumes     = []
}

data "openstack_images_image_v2" "callysto" {
  name        = "${local.image_name}"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "callysto" {
  name       = "${local.key_name}"
  public_key = "${local.public_key}"
}

module "settings" {
  source      = "../modules/settings"
  environment = "dev"
}

module "sharder" {
  source               = "../modules/sharder"
  name                 = "${local.sharder_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.sharder_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  network_id           = "${local.network_id}"
  create_floating_ip   = "${local.sharder_create_floating_ip}"
  existing_floating_ip = "${local.sharder_existing_floating_ip}"
}

module "ssp" {
  source               = "../modules/ssp"
  name                 = "${local.ssp_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.ssp_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  network_id           = "${local.network_id}"
  create_floating_ip   = "${local.ssp_create_floating_ip}"
  existing_floating_ip = "${local.ssp_existing_floating_ip}"
}

module "hub01" {
  source               = "../modules/hub"
  name                 = "${local.hub01_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.hub_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  network_id           = "${local.network_id}"
  vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  existing_volumes     = "${local.hub01_existing_volumes}"
  create_floating_ip   = "${local.hub01_create_floating_ip}"
  existing_floating_ip = "${local.hub01_existing_floating_ip}"
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "ssp" {
  inventory_group_name = "ssp"
}

resource "ansible_group" "sharder" {
  inventory_group_name = "sharder"
}

resource "ansible_group" "environment" {
  inventory_group_name = "dev"
}

resource "ansible_group" "shibboleth_hosts" {
  inventory_group_name = "shibboleth_hosts"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "ENV"
}

resource "ansible_host" "hub01" {
  inventory_hostname = "${local.hub01_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub01.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub01.vol_id_1}"
    zfs_disk_2              = "${module.hub01.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

resource "ansible_host" "ssp" {
  inventory_hostname = "${local.ssp_name}"

  groups = [
    "all",
    "${ansible_group.ssp.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.ssp.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
  }
}

resource "ansible_host" "sharder" {
  inventory_hostname = "${local.sharder_name}"

  groups = [
    "all",
    "${ansible_group.sharder.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.sharder.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

output "hub01_ip" {
  value = "${module.hub01.ip}"
}

output "hub01_dns_name" {
  value = "${module.hub01.dns_name}"
}

output "ssp_ip" {
  value = "${module.ssp.ip}"
}

output "ssp_dns_name" {
  value = "${module.ssp.dns_name}"
}

output "sharder_ip" {
  value = "${module.sharder.ip}"
}

output "sharder_dns_name" {
  value = "${module.sharder.dns_name}"
}
