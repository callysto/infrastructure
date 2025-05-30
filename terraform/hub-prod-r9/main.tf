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
variable "PROD_CALLYSTO_DOMAINNAME" {}

variable "PROD_CALLYSTO_ZONE_ID" {}

# These represent settings to tune the hub you're creating
locals {
  # Global Settings
  image_name   = "Alma Linux 9"
  network_name = "default"
  network_id   = "b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  key_name     = "clavius-r9"
  zone_id      = "${var.PROD_CALLYSTO_ZONE_ID}"

  # Sharder Settings
  sharder_name = "hub.${var.PROD_CALLYSTO_DOMAINNAME}"

  # Sharder floating IP settings
  sharder_create_floating_ip   = "false"
  sharder_existing_floating_ip = "162.246.156.97"

  # SSP Settings
  ssp_name               = "ssp.${var.PROD_CALLYSTO_DOMAINNAME}"
  ssp_create_floating_ip = "true"

  #ssp_existing_floating_ip = "162.246.156.143"
  ssp_existing_floating_ip = ""

  # Hub 01 Settings
  hub01_name                 = "hub-01.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub01_create_floating_ip   = "false"
  hub01_existing_floating_ip = "162.246.156.72"
  hub01_existing_volumes     = ["ff4f2adc-4487-4515-93e1-4785f74b841a", "b5cf8c8e-152a-43e0-b703-7eeaab40cccc"]

  # Hub 02 Settings
  hub02_name                 = "hub-02.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub02_create_floating_ip   = "false"
  hub02_existing_floating_ip = "162.246.156.170"
  hub02_existing_volumes     = ["236fd61d-66a0-4511-b132-7b66f34b8f0e", "35bb32da-5c51-4f7d-bafe-3cfbee28a38f"]

  # Hub 03 Settings
  hub03_name                 = "hub-03.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub03_create_floating_ip   = "false"
  hub03_existing_floating_ip = "162.246.156.214"
  hub03_existing_volumes     = ["7c76cb02-ba93-41e3-a0d3-6bdc46295136"]

  # Stats Settings
  stats_name                 = "stats.${var.PROD_CALLYSTO_DOMAINNAME}"
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
  environment = "prod"
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
  source       = "../modules/hub"
  name         = "${local.hub01_name}"
  zone_id      = "${local.zone_id}"
  image_id     = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name  = "${module.settings.hub_flavor_name}"
  key_name     = "${local.key_name}"
  network_name = "${local.network_name}"
  network_id   = "${local.network_id}"

  #vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  vol_zfs_size         = 15
  existing_volumes     = "${local.hub01_existing_volumes}"
  create_floating_ip   = "${local.hub01_create_floating_ip}"
  existing_floating_ip = "${local.hub01_existing_floating_ip}"
}

module "hub02" {
  source       = "../modules/hub"
  name         = "${local.hub02_name}"
  zone_id      = "${local.zone_id}"
  image_id     = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name  = "${module.settings.hub_flavor_name}"
  key_name     = "${local.key_name}"
  network_name = "${local.network_name}"
  network_id   = "${local.network_id}"

  #vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  vol_zfs_size         = 15
  existing_volumes     = "${local.hub02_existing_volumes}"
  create_floating_ip   = "${local.hub02_create_floating_ip}"
  existing_floating_ip = "${local.hub02_existing_floating_ip}"
}

module "hub03" {
  source       = "../modules/hub"
  name         = "${local.hub03_name}"
  zone_id      = "${local.zone_id}"
  image_id     = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name  = "${module.settings.hub_flavor_name}"
  key_name     = "${local.key_name}"
  network_name = "${local.network_name}"
  network_id   = "${local.network_id}"

  #vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  vol_zfs_size         = 15
  existing_volumes     = "${local.hub03_existing_volumes}"
  create_floating_ip   = "${local.hub03_create_floating_ip}"
  existing_floating_ip = "${local.hub03_existing_floating_ip}"
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
  inventory_group_name = "prod"
}

resource "ansible_group" "shibboleth_hosts" {
  inventory_group_name = "shibboleth_hosts"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "hub-prod"
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

  vars = {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub01.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub01.vol_id_1}"
    zfs_disk_2              = "${module.hub01.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

resource "ansible_host" "hub02" {
  inventory_hostname = "${local.hub02_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars = {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub02.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub02.vol_id_1}"
    zfs_disk_2              = "${module.hub02.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

resource "ansible_host" "hub03" {
  inventory_hostname = "${local.hub03_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars = {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub03.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub03.vol_id_1}"
    zfs_disk_2              = "${module.hub03.vol_id_2}"
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

  vars = {
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

  vars = {
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

output "hub02_ip" {
  value = "${module.hub02.ip}"
}

output "hub02_dns_name" {
  value = "${module.hub02.dns_name}"
}

output "hub03_ip" {
  value = "${module.hub03.ip}"
}

output "hub03_dns_name" {
  value = "${module.hub03.dns_name}"
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
