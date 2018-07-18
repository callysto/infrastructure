resource "random_pet" "name" {
  length = 2
}

locals {
  name = "${random_pet.name.id}.callysto.farm"

  image_name   = "callysto-hub"
  flavor_name  = "m1.large"
  network_name = "default"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  vol_zfs_size = 50
  zone_id      = "fb1e23f2-5eb9-43e9-aa37-60a5bd7c2595"
}

data "openstack_images_image_v2" "hub" {
  name        = "${local.image_name}"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "hub" {
  name       = "${random_pet.name.id}"
  public_key = "${local.public_key}"
}

module "hub" {
  source       = "../modules/hub"
  name         = "${local.name}"
  image_id     = "${data.openstack_images_image_v2.hub.id}"
  flavor_name  = "${local.flavor_name}"
  key_name     = "${openstack_compute_keypair_v2.hub.name}"
  network_name = "${local.network_name}"
  vol_zfs_size = "${local.vol_zfs_size}"
}

resource "openstack_dns_recordset_v2" "hub" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(module.hub.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "environment" {
  inventory_group_name = "dev"
}

resource "ansible_group" "local_vars" {
  inventory_group_name = "hub-ENV"
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
    ansible_user = "ptty2u"

    ansible_host            = "${openstack_dns_recordset_v2.hub.records[0]}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
  }
}