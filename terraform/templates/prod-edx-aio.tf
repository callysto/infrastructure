## Production All in One edX Environment

# These are set by the Makefile
variable "PROD_CALLYSTO_DOMAINNAME" {}

variable "PROD_CALLYSTO_ZONE_ID" {}

# These represent settings to tune the edx you're creating
locals {
  # Global Settings
  image_name   = "callysto-centos"
  network_name = "default"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  key_name     = "clavius"
  zone_id      = "${var.PROD_CALLYSTO_ZONE_ID}"

  # edX Settings
  edx_name = "edx.${var.PROD_CALLYSTO_DOMAINNAME}"
  cms_name = "studio.${var.PROD_CALLYSTO_DOMAINNAME}"
  lms_name = "courses.${var.PROD_CALLYSTO_DOMAINNAME}"

  # Create a new floating IP or use an existing one.
  # If set to false and "", then IPv6 will be used.
  edx_create_floating_ip = "false"

  edx_existing_floating_ip = ""

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  edx_existing_volumes = []
}

data "openstack_images_image_v2" "callysto" {
  name        = "${local.image_name}"
  most_recent = true
}

module "settings" {
  source      = "../modules/settings"
  environment = "prod"
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

resource "ansible_group" "edx" {
  inventory_group_name = "edx"
}

resource "ansible_group" "environment" {
  inventory_group_name = "prod"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "ENV"
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

output "edx_ip" {
  value = "${module.edx.ip}"
}

output "edx_dns_name" {
  value = "${module.edx.dns_name}"
}
