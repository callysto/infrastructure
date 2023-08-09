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

  # Sharder Settings
  sharder_name = "hub.${var.PROD_CALLYSTO_DOMAINNAME}"

  # Sharder floating IP settings.
  sharder_create_floating_ip   = "false"
  sharder_existing_floating_ip = "162.246.156.36"

  # SSP Settings
  ssp_name                 = "ssp.${var.PROD_CALLYSTO_DOMAINNAME}"
  ssp_create_floating_ip   = "false"
  ssp_existing_floating_ip = "162.246.156.247"

  # Hub 01 Settings
  hub01_name                 = "hub-01.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub01_create_floating_ip   = "false"
  hub01_existing_floating_ip = "162.246.156.219"

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  hub01_existing_volumes = [
    "ad112939-111b-4929-8bd4-b9e5662d0945",
    "b92bdad9-d9ea-4921-9a5f-2d556400a179",
  ]

  # Hub 02 Settings
  hub02_name                 = "hub-02.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub02_create_floating_ip   = "false"
  hub02_existing_floating_ip = "162.246.156.212"

  hub02_existing_volumes = [
    "9e3efaa9-6b21-4899-bb94-1389db64669e",
    "97720a93-6353-4dd6-b031-f306e196e2fa",
  ]

  # Hub 03 Settings
  hub03_name                 = "hub-03.${var.PROD_CALLYSTO_DOMAINNAME}"
  hub03_create_floating_ip   = "false"
  hub03_existing_floating_ip = "162.246.156.237"

  hub03_existing_volumes = [
    "04e5d637-d56e-4cad-b845-8358d5e436a0",
    "6c4fc956-0886-4821-95e1-ac25828c2565",
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

module "hub03" {
  source               = "../modules/hub"
  name                 = "${local.hub03_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.hub_flavor_name}"
  key_name             = "${local.key_name}"
  network_name         = "${local.network_name}"
  vol_zfs_size         = "${module.settings.hub_vol_zfs_size}"
  existing_volumes     = "${local.hub03_existing_volumes}"
  create_floating_ip   = "${local.hub03_create_floating_ip}"
  existing_floating_ip = "${local.hub03_existing_floating_ip}"
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

resource "ansible_host" "hub03" {
  inventory_hostname = "${local.hub03_name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.shibboleth_hosts.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub03.ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub03.vol_id_1}"
    zfs_disk_2              = "${module.hub03.vol_id_2}"
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

output "hub03_ip" {
  value = "${module.hub03.ip}"
}

output "hub03_dns_name" {
  value = "${module.hub03.dns_name}"
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
