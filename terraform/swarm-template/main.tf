resource "random_pet" "name" {
  length = 2
}

locals {
  name               = "${random_pet.name.id}.callysto.farm"
  public_key         = "${file("../../keys/id_rsa.pub")}"
  zone_id            = "fb1e23f2-5eb9-43e9-aa37-60a5bd7c2595"
  magnum_flavor_name = "swarm-ipv6-large"
  swarm_node_count   = 1
  docker_volume_size = 25
}

resource "openstack_compute_keypair_v2" "swarm_cluster" {
  name       = "${random_pet.name.id}"
  public_key = "${local.public_key}"
}

module "swarm_cluster" {
  source             = "../modules/swarm-cluster"
  cluster_name       = "${local.name}"
  key_name           = "${openstack_compute_keypair_v2.swarm_cluster.name}"
  magnum_flavor_name = "${local.magnum_flavor_name}"
  node_count         = "${local.swarm_node_count}"
  volume_size        = "${local.docker_volume_size}"
}

resource "openstack_dns_recordset_v2" "swarm_cluster" {
  zone_id = "${local.zone_id}"
  name    = "${local.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(module.swarm_cluster.ipv6, "/[][]/", "")}",
  ]
}
