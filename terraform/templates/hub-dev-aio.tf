### All in One Development Jupyter Hub

# These are set in env or .envrc file
variable "DEV_CALLYSTO_DOMAINNAME" {}

variable "DEV_CALLYSTO_ZONE_ID" {}

resource "random_pet" "key_name" {
  prefix = "key"
  length = 2
}

resource "random_pet" "hub_name" {
  prefix = "hub"
  length = 2
}

# These represent settings to tune the hub you're creating
locals {
  # Global Settings
  image_name   = "callysto-centos"
  network_name = "default"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  zone_id      = "${var.DEV_CALLYSTO_ZONE_ID}"

  # Hub Settings
  hub_name = "${random_pet.hub_name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"

  # Create a new floating IP or use an existing one.
  # If set to false and "", then IPv6 will be used.
  hub_create_floating_ip = "false"

  hub_existing_floating_ip = ""

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  hub_existing_volumes = []
}

data "openstack_images_image_v2" "callysto" {
  name        = "${local.image_name}"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "callysto" {
  name       = "${random_pet.key_name.id}"
  public_key = "${local.public_key}"
}

module "settings" {
  source      = "../modules/settings"
  environment = "dev"
}

module "hub" {
  source               = "../modules/hub"
  name                 = "${local.hub_name}"
  zone_id              = "${local.zone_id}"
  image_id             = "${data.openstack_images_image_v2.callysto.id}"
  flavor_name          = "${module.settings.hub_flavor_name}"
  key_name             = "${openstack_compute_keypair_v2.callysto.name}"
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
  inventory_group_name = "dev"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "ENV"
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
    ansible_host            = "${module.hub.hub_ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub.vol_id_1}"
    zfs_disk_2              = "${module.hub.vol_id_2}"
    zfs_pool_name           = "tank"
    docker_storage          = ""
  }
}

output "hub_ip" {
  value = "${module.hub.hub_ip}"
}

output "hub_dns_name" {
  value = "${module.hub.dns_name}"
}
