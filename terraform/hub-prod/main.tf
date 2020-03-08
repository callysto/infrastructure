## Production All in One Development Jupyter Hub

# These are set in env or .envrc file
variable "PROD_CALLYSTO_DOMAINNAME" {}

variable "PROD_CALLYSTO_ZONE_ID" {}

# These represent settings to tune the hub you're creating
locals {
  # Global Settings
  image_name   = "callysto-centos"
  network_name = "default"
  key_name     = "clavius"
  zone_id      = "${var.PROD_CALLYSTO_ZONE_ID}"

  # Hub Settings
  hub_name = "hub.${var.PROD_CALLYSTO_DOMAINNAME}"

  # Create a new floating IP or use an existing one.
  # If set to false and "", then IPv6 will be used.
  hub_create_floating_ip = "false"

  hub_existing_floating_ip = "162.246.156.219"

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  hub_existing_volumes = [
    "ad112939-111b-4929-8bd4-b9e5662d0945",
    "b92bdad9-d9ea-4921-9a5f-2d556400a179",
  ]

  # Stats Settings
  stats_name                 = "stats.${var.PROD_CALLYSTO_DOMAINNAME}"
  stats_create_floating_ip   = "false"
  stats_existing_floating_ip = "199.116.235.41"

  stats_existing_volumes = [
    "21833a44-bc33-4489-b7f6-f7d2573c9fab",
    "0f208656-892d-4651-9304-2dc9e528ea21",
  ]

  # edX Settings
  edx_name                 = "edx.${var.PROD_CALLYSTO_DOMAINNAME}"
  cms_name                 = "studio.${var.PROD_CALLYSTO_DOMAINNAME}"
  lms_name                 = "courses.${var.PROD_CALLYSTO_DOMAINNAME}"
  edx_create_floating_ip   = "false"
  edx_existing_floating_ip = "199.116.235.105"

  edx_existing_volumes = [
    "2f73e302-da47-4097-b4ed-4bfe9e1ff928",
    "1590e460-bd65-4584-a25b-ac2efeb330f4",
  ]
}

data "openstack_images_image_v2" "callysto" {
  name        = "${local.image_name}"
  most_recent = true
}

module "settings" {
  source      = "../modules/settings"
  environment = "prod"
}

module "hub" {
  source               = "../modules/hub"
  name                 = "${local.hub_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.hub_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  existing_volumes     = "${local.hub_existing_volumes}"
  create_floating_ip   = "${local.hub_create_floating_ip}"
  existing_floating_ip = "${local.hub_existing_floating_ip}"
}

module "stats" {
  source               = "../modules/stats"
  name                 = "${local.stats_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.stats_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  vol_zfs_size         = "${module.settings.stats_vol_zfs_size}"
  existing_volumes     = "${local.stats_existing_volumes}"
  create_floating_ip   = "${local.stats_create_floating_ip}"
  existing_floating_ip = "${local.stats_existing_floating_ip}"
}

module "edx" {
  source               = "../modules/edx"
  name                 = "${local.edx_name}"
  cms_name             = "${local.cms_name}"
  lms_name             = "${local.lms_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.edx_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  vol_zfs_size         = "${module.settings.edx_vol_zfs_size}"
  existing_volumes     = "${local.edx_existing_volumes}"
  create_floating_ip   = "${local.edx_create_floating_ip}"
  existing_floating_ip = "${local.edx_existing_floating_ip}"
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "ssp" {
  inventory_group_name = "ssp"
}

resource "ansible_group" "stats" {
  inventory_group_name = "stats"
}

resource "ansible_group" "edx" {
  inventory_group_name = "edx"
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

resource "ansible_host" "hub" {
  inventory_hostname = "${local.hub_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.ssp.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub.vol_id_1}"
    zfs_disk_2              = "${module.hub.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

resource "ansible_host" "stats" {
  inventory_hostname = "${local.stats_name}"

  groups = [
    "all",
    "${ansible_group.stats.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.stats.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.stats.vol_id_1}"
    zfs_disk_2              = "${module.stats.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

resource "ansible_host" "edx" {
  inventory_hostname = "${local.edx_name}"

  groups = [
    "all",
    "${ansible_group.edx.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.edx.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.edx.vol_id_1}"
    zfs_disk_2              = "${module.edx.vol_id_2}"
    edx_name                = "${module.edx.dns_name}"
    cms_name                = "${local.cms_name}"
    lms_name                = "${local.lms_name}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

output "hub_ip" {
  value = "${module.hub.ip}"
}

output "hub_dns_name" {
  value = "${module.hub.dns_name}"
}

output "stats_ip" {
  value = "${module.stats.ip}"
}

output "stats_dns_name" {
  value = "${module.stats.dns_name}"
}

output "edx_ip" {
  value = "${module.edx.ip}"
}

output "edx_dns_name" {
  value = "${module.edx.dns_name}"
}
