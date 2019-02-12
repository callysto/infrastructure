variable "DEV_CALLYSTO_DOMAINNAME" {}

variable "DEV_CALLYSTO_ZONE_ID" {}

locals {
  name = "clavius.${var.DEV_CALLYSTO_DOMAINNAME}"

  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d" # CentOS 7
  flavor_name     = "m1.small"
  network_name    = "default"
  public_key      = "${file("../../keys/id_rsa.pub")}"
  floatingip_pool = "public"
  zone_id         = "${var.DEV_CALLYSTO_ZONE_ID}"
}

module "clavius" "clavius" {
  source       = "../modules/clavius"
  name         = "${local.name}"
  image_id     = "${local.image_id}"
  flavor_name  = "${local.flavor_name}"
  key_name     = "${openstack_compute_keypair_v2.clavius.name}"
  network_name = "${local.network_name}"
}

resource "openstack_compute_keypair_v2" "clavius" {
  name       = "clavius"
  public_key = "${local.public_key}"
}

resource "openstack_networking_floatingip_v2" "clavius" {
  pool = "${local.floatingip_pool}"
}

resource "openstack_compute_floatingip_associate_v2" "clavius" {
  instance_id = "${module.clavius.instance_uuid}"
  floating_ip = "${openstack_networking_floatingip_v2.clavius.address}"
}

resource "openstack_dns_recordset_v2" "clavius_v4" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "A"

  records = [
    "${openstack_networking_floatingip_v2.clavius.address}",
  ]
}

resource "openstack_dns_recordset_v2" "clavius_v6" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(module.clavius.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "ansible_group" "infra" {
  inventory_group_name = "infra"
}

resource "ansible_host" "clavius" {
  inventory_hostname = "clavius"
  groups             = ["${ansible_group.infra.inventory_group_name}"]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${openstack_dns_recordset_v2.clavius_v4.records[0]}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    docker_storage          = "${module.clavius.docker_storage}"
  }
}
