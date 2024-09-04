resource "openstack_blockstorage_volume_v2" "zfs" {
  count = "${length(var.existing_volumes) == 0 ? 2 : 0}"

  name = "${format("%s-zfs-%02d", var.name, count.index+1)}"
  size = "${var.vol_zfs_size}"

  volume_type = "ssd"
}

# Determine the volume UUIDs, whether if existing ones were supplied
# or if new ones were created.
locals {
  vol_id_1 = "${length(var.existing_volumes) == 0 ?
    element(concat(openstack_blockstorage_volume_v2.zfs.*.id, list("")), 0) :
    element(concat(var.existing_volumes, list("")), 0)
  }"

  vol_id_2 = "${length(var.existing_volumes) == 0 ?
    element(concat(openstack_blockstorage_volume_v2.zfs.*.id, list("")), 1) :
    element(concat(var.existing_volumes, list("")), 1)
  }"
}

# Manually specify each attachment in a serial order.
# This prevents the possibility of volumes attaching out of order.
resource "openstack_compute_volume_attach_v2" "zfs_1" {
  instance_id = "${openstack_compute_instance_v2.instance.id}"
  volume_id   = "${local.vol_id_1}"
}

resource "openstack_compute_volume_attach_v2" "zfs_2" {
  depends_on = ["openstack_compute_volume_attach_v2.zfs_1"]

  instance_id = "${openstack_compute_instance_v2.instance.id}"
  volume_id   = "${local.vol_id_2}"
}

output "vol_id_1" {
  value = "${local.vol_id_1}"
}

output "vol_id_2" {
  value = "${local.vol_id_2}"
}
