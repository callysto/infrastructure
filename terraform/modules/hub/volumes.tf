resource "openstack_blockstorage_volume_v2" "zfs" {
  count = 2
  name  = "${format("%s-zfs-%02d", var.name, count.index+1)}"
  size  = "${var.vol_zfs_size}"
}

# Manually specify each attachment in a serial order.
# This prevents the possibility of volumes attaching out of order.
resource "openstack_compute_volume_attach_v2" "zfs_1" {
  instance_id = "${openstack_compute_instance_v2.hub.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.zfs.0.id}"
}

resource "openstack_compute_volume_attach_v2" "zfs_2" {
  depends_on = ["openstack_compute_volume_attach_v2.zfs_1"]

  instance_id = "${openstack_compute_instance_v2.hub.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.zfs.1.id}"
}
