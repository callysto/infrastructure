# These represent settings to tune the hub you're creating
locals {
  name = "hub.callysto.ca"

  image_name   = "callysto-hub"
  network_name = "default"
  public_key   = "${file("../../keys/id_rsa.pub")}"

  existing_floating_ip = "162.246.156.219"

  existing_volumes = [
    "f537d65c-4a22-4cec-ad3f-4a8875fc8b7b",
    "85aed780-0dd2-47a9-919e-a7b19fb24ec9",
  ]
}

data "openstack_images_image_v2" "hub" {
  name        = "${local.image_name}"
  most_recent = true
}

module "settings" {
  source      = "../modules/settings"
  environment = "prod"
}

module "hub" {
  source           = "../modules/hub"
  name             = "${local.name}"
  image_id         = "${data.openstack_images_image_v2.hub.id}"
  flavor_name      = "${module.settings.hub_flavor_name}"
  key_name         = "clavius"
  network_name     = "${local.network_name}"
  existing_volumes = "${local.existing_volumes}"
}

resource "openstack_compute_floatingip_associate_v2" "hub_existing_fip" {
  count       = "${local.existing_floating_ip != "" ? 1 : 0}"
  instance_id = "${module.hub.instance_uuid}"
  floating_ip = "${local.existing_floating_ip}"
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "environment" {
  inventory_group_name = "prod"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "hub-prod"
}

resource "ansible_host" "hub" {
  inventory_hostname = "${local.name}"

  groups = [
    "all",
    "${ansible_group.hub.inventory_group_name}",
    "${ansible_group.environment.inventory_group_name}",
    "${ansible_group.local_vars.inventory_group_name}",
  ]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${local.existing_floating_ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub.vol_id_1}"
    zfs_disk_2              = "${module.hub.vol_id_2}"
  }
}
