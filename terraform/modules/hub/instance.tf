resource "openstack_networking_floatingip_v2" "fip" {
  pool = "${var.floating_ip_pool}"
}

resource "openstack_compute_instance_v2" "callysto" {
  name = "${local.name}"

  image_id        = "${var.image_id}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${var.key_name}"
  security_groups = ["${openstack_networking_secgroup_v2.callysto.name}"]
  user_data       = "${local.cloudconfig}"

  network {
    name = "${var.network_name}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  floating_ip = "${openstack_networking_floatingip_v2.fip.address}"
  instance_id = "${openstack_compute_instance_v2.callysto.id}"
}

output "name" {
  value = "${local.name}"
}

output "floating_ip" {
  value = "${openstack_networking_floatingip_v2.fip.address}"
}

output "access_ip_v6" {
  value = "${openstack_compute_instance_v2.callysto.access_ip_v6}"
}
