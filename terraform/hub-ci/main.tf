resource "random_id" "name" {
  prefix      = "-ci-"
  byte_length = 4
}

locals {
  name_suffix = "${random_id.name.hex}"
  public_key  = "${file("../../keys/id_rsa.pub")}"
}

resource "openstack_compute_keypair_v2" "hub-ci" {
  name       = "hub${local.name_suffix}"
  public_key = "${local.public_key}"
}

module "hub-ci" {
  source           = "../modules/hub"
  name_suffix      = "${local.name_suffix}"
  image_id         = "10076751-ace0-49b2-ba10-cfa22a98567d"
  flavor_name      = "m1.large"
  key_name         = "${openstack_compute_keypair_v2.hub-ci.name}"
  network_name     = "default"
  floating_ip_pool = "public"
}

resource "ansible_group" "hub" {
  inventory_group_name = "hub"
}

resource "ansible_group" "jupyter" {
  inventory_group_name = "jupyter"
  children             = ["hub"]
}

resource "ansible_host" "hub-ci" {
  inventory_hostname = "${module.hub-ci.name}"
  groups             = ["hub"]

  vars {
    ansible_user            = "ptty2u"
    ansible_host            = "${module.hub-ci.floating_ip}"
    ansible_ssh_common_args = "-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
  }
}
