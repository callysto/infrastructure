resource "random_id" "name" {
  prefix      = "ci-"
  byte_length = 4
}

locals {
  name = "hub-${random_id.name.hex}.callysto.farm"

  image_id         = "10076751-ace0-49b2-ba10-cfa22a98567d" # CentOS 7
  flavor_name      = "m1.large"
  network_name     = "default"
  public_key       = "${file("../../keys/id_rsa.pub")}"
  zone_id          = "fb1e23f2-5eb9-43e9-aa37-60a5bd7c2595" # callysto.farm
  vol_homedir_size = 10
  vol_docker_size  = 20
}

resource "openstack_compute_keypair_v2" "hub-ci" {
  name       = "hub-${random_id.name.hex}"
  public_key = "${local.public_key}"
}

module "hub-ci" {
  source           = "../modules/hub"
  name             = "${local.name}"
  image_id         = "${local.image_id}"
  flavor_name      = "${local.flavor_name}"
  key_name         = "${openstack_compute_keypair_v2.hub-ci.name}"
  network_name     = "${local.network_name}"
  vol_homedir_size = "${local.vol_homedir_size}"
  vol_docker_size  = "${local.vol_docker_size}"
}

resource "openstack_dns_recordset_v2" "hub-ci" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(module.hub-ci.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "hub-dev" {
  inventory_group_name = "hub-dev"
}

resource "ansible_group" "jupyter" {
  inventory_group_name = "jupyter"
  children             = ["hub", "hub-dev"]
}

resource "ansible_host" "hub-ci" {
  inventory_hostname = "${local.name}"
  groups             = ["hub", "hub-dev"]

  vars {
    ansible_user = "ptty2u"

    ansible_host            = "${openstack_dns_recordset_v2.hub-ci.records[0]}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
  }
}
