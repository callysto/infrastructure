# These are set in env or .envrc file
variable "DEV_CALLYSTO_DOMAINNAME" {}
variable "DEV_CALLYSTO_ZONE_ID" {}

resource "random_pet" "name" {
  length = 2
}

# These represent settings to tune the hub you're creating
locals {
  name = "${random_pet.name.id}.${var.DEV_CALLYSTO_DOMAINNAME}"

  image_name   = "callysto-hub"
  network_name = "default"
  public_key   = "${file("../../keys/id_rsa.pub")}"
  zone_id      = "${var.DEV_CALLYSTO_ZONE_ID}"

  # Create a new floating IP or use an existing one.
  # If set to false and "", then IPv6 will be used.
  create_floating_ip = false

  existing_floating_ip = ""

  # Set this to use existing volumes. Make sure to only specify 2.
  #existing_volumes = ["uuid1", "uuid2"]
  existing_volumes = []
}

data "openstack_images_image_v2" "hub" {
  name        = "${local.image_name}"
  most_recent = true
}

resource "openstack_compute_keypair_v2" "hub" {
  name       = "${random_pet.name.id}"
  public_key = "${local.public_key}"
}

module "settings" {
  source      = "../modules/settings"
  environment = "dev"
}

module "hub" {
  source           = "../modules/hub"
  name             = "${local.name}"
  image_id         = "${data.openstack_images_image_v2.hub.id}"
  flavor_name      = "${module.settings.hub_flavor_name}"
  key_name         = "${openstack_compute_keypair_v2.hub.name}"
  network_name     = "${local.network_name}"
  vol_zfs_size     = "${module.settings.hub_vol_zfs_size}"
  existing_volumes = "${local.existing_volumes}"
}

resource "openstack_dns_recordset_v2" "hub_ipv6" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(module.hub.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_networking_floatingip_v2" "hub" {
  count = "${local.create_floating_ip ? 1 : 0}"
  pool  = "public"
}

resource "openstack_compute_floatingip_associate_v2" "hub_new_fip" {
  count       = "${local.create_floating_ip ? 1 : 0}"
  instance_id = "${module.hub.instance_uuid}"
  floating_ip = "${openstack_networking_floatingip_v2.hub.address}"
}

resource "openstack_dns_recordset_v2" "hub_new_fip" {
  count   = "${local.create_floating_ip ? 1 : 0}"
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.hub_new_fip.floating_ip}"]
}

resource "openstack_compute_floatingip_associate_v2" "hub_existing_fip" {
  count       = "${local.existing_floating_ip != "" ? 1 : 0}"
  instance_id = "${module.hub.instance_uuid}"
  floating_ip = "${local.existing_floating_ip}"
}

resource "openstack_dns_recordset_v2" "hub_existing_fip" {
  count   = "${local.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.hub_existing_fip.floating_ip}"]
}

locals {
  hub_ip = "${
    coalesce(
      element(concat(openstack_compute_floatingip_associate_v2.hub_new_fip.*.floating_ip, list("")), 0),
      element(concat(openstack_compute_floatingip_associate_v2.hub_existing_fip.*.floating_ip, list("")), 0),
      openstack_dns_recordset_v2.hub_ipv6.records[0]
    )
  }"
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
    ansible_user            = "ptty2u"
    ansible_host            = "${local.hub_ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    zfs_disk_1              = "${module.hub.vol_id_1}"
    zfs_disk_2              = "${module.hub.vol_id_2}"
    docker_storage          = "${module.hub.docker_storage}"
  }
}
