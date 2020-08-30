## Production JupyterHub Cluster Environment

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

  # Sharder Settings
  sharder_name = "hub.${var.PROD_CALLYSTO_DOMAINNAME}"

  # Sharder floating IP settings.
  sharder_create_floating_ip   = "false"
  sharder_existing_floating_ip = "<IP>"

  # SSP Settings
  ssp_name                 = "ssp.${var.PROD_CALLYSTO_DOMAINNAME}"
  ssp_create_floating_ip   = "false"
  ssp_existing_floating_ip = "<IP>"

  # Hub 01 Settings
  hub01_name                 = "hub-01.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub01_create_floating_ip   = "false"
  hub01_existing_floating_ip = "<IP>"

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  hub01_existing_volumes = [
    "<vol1>",
    "<vol2>",
  ]

  # Hub 02 Settings
  hub02_name                 = "hub-02.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub02_create_floating_ip   = "false"
  hub02_existing_floating_ip = "<IP>"

  hub02_existing_volumes = [
    "<vol1>",
    "<vol2>",
  ]

  # Stats Settings
  stats_name                 = "stats.${var.PROD_CALLYSTO_DOMAINNAME}"
  stats_create_floating_ip   = "false"
  stats_existing_floating_ip = "<IP>"

  stats_existing_volumes = [
    "<vol1>",
    "<vol2>",
  ]

  # edX Settings
  edx_name                 = "edx.${var.PROD_CALLYSTO_DOMAINNAME}"
  cms_name                 = "studio.${var.PROD_CALLYSTO_DOMAINNAME}"
  lms_name                 = "courses.${var.PROD_CALLYSTO_DOMAINNAME}"
  edx_create_floating_ip   = "false"
  edx_existing_floating_ip = "<IP>"

  edx_existing_volumes = [
    "<vol1>",
    "<vol2>",
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

module "sharder" {
  source               = "../modules/sharder"
  name                 = "${local.sharder_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.sharder_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
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
  vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  existing_volumes     = "${local.hub01_existing_volumes}"
  create_floating_ip   = "${local.hub01_create_floating_ip}"
  existing_floating_ip = "${local.hub01_existing_floating_ip}"
}

module "hub02" {
  source               = "../modules/hub"
  name                 = "${local.hub02_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.hub_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  existing_volumes     = "${local.hub02_existing_volumes}"
  create_floating_ip   = "${local.hub02_create_floating_ip}"
  existing_floating_ip = "${local.hub02_existing_floating_ip}"
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

resource "ansible_group" "sharder" {
  inventory_group_name = "sharder"
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

resource "ansible_host" "hub02" {
  inventory_hostname = "${local.hub02_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub02.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub02.vol_id_1}"
    zfs_disk_2              = "${module.hub02.vol_id_2}"
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

output "sharder_ip" {
  value = "${module.sharder.ip}"
}

output "sharder_dns_name" {
  value = "${module.sharder.dns_name}"
}

output "ssp_ip" {
  value = "${module.ssp.ip}"
}

output "ssp_dns_name" {
  value = "${module.ssp.dns_name}"
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
