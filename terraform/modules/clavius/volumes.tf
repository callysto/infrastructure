resource "openstack_blockstorage_volume_v2" "homedir" {
  name = "${format("%s-homedir", var.name)}"
  size = 20
}

resource "openstack_compute_volume_attach_v2" "homedir" {
  instance_id = "${openstack_compute_instance_v2.clavius.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.homedir.id}"
}
