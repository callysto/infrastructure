resource "openstack_compute_instance_v2" "hub" {
  name = "${var.name}"

  image_id        = "${var.image_id}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${var.key_name}"
  security_groups = ["${openstack_networking_secgroup_v2.hub.name}"]
  user_data       = "${local.cloudconfig}"

  network {
    name = "${var.network_name}"
  }

  lifecycle {
    ignore_changes = ["image_id"]
  }
}

output "instance_uuid" {
  value = "${openstack_compute_instance_v2.hub.id}"
}

output "access_ip_v6" {
  value = "${openstack_compute_instance_v2.hub.access_ip_v6}"
}
