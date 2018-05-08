resource "openstack_blockstorage_volume_v2" "homedir" {
  count = 2
  name  = "${format("callysto-homedir-%02d%s", count.index+1, var.name_suffix)}"
  size  = 50
}

resource "openstack_blockstorage_volume_v2" "docker" {
  name = "${format("callysto-docker%s", var.name_suffix)}"
  size = 100
}

# Manually specify each attachment in a serial order.
# This prevents the possibility of volumes attaching out of order.
resource "openstack_compute_volume_attach_v2" "homedir_1" {
  instance_id = "${openstack_compute_instance_v2.callysto.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.homedir.0.id}"
}

resource "openstack_compute_volume_attach_v2" "homedir_2" {
  depends_on = ["openstack_compute_volume_attach_v2.homedir_1"]

  instance_id = "${openstack_compute_instance_v2.callysto.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.homedir.1.id}"
}

resource "openstack_compute_volume_attach_v2" "docker" {
  depends_on = ["openstack_compute_volume_attach_v2.homedir_2"]

  instance_id = "${openstack_compute_instance_v2.callysto.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.docker.id}"
}
