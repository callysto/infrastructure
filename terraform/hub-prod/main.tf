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
  hub_existing_volumes = ["992a01ff-8d31-4a16-ada4-2a278b8847fb", "5ea86a3d-a26e-4aca-b7e3-0f2a424aaea1"]
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

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "ssp" {
  inventory_group_name = "ssp"
}

resource "ansible_group" "environment" {
  inventory_group_name = "prod"
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

output "hub_ip" {
  value = "${module.hub.ip}"
}

output "hub_dns_name" {
  value = "${module.hub.dns_name}"
}
