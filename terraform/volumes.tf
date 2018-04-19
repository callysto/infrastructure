resource "openstack_blockstorage_volume_v2" "zfsvol1" {
  name = "zfsvol1"
  size = 50
}

resource "openstack_blockstorage_volume_v2" "zfsvol2" {
  name = "zfsvol2"
  size = 50
}

resource "openstack_blockstorage_volume_v2" "var_docker" {
  name = "var_docker"
  size = 100
}

resource "openstack_compute_volume_attach_v2" "zfsvol1" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol1.id}"
}
resource "openstack_compute_volume_attach_v2" "zfsvol2" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol2.id}"
}

resource "openstack_compute_volume_attach_v2" "var_docker" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.var_docker.id}"
}

