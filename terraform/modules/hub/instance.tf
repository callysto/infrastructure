resource "openstack_networking_floatingip_v2" "fip" {
  pool = "${var.floating_ip_pool}"
}

resource "openstack_compute_keypair_v2" "callysto" {
  name       = "${format("callysto%s", var.name_suffix)}"
  public_key = "${var.public_key}"
}

resource "openstack_compute_instance_v2" "callysto" {
  name = "${format("callysto%s", var.name_suffix)}"

  image_id        = "${var.image_id}"
  flavor_name     = "${var.flavor_name}"
  key_pair        = "${openstack_compute_keypair_v2.callysto.name}"
  security_groups = ["${openstack_networking_secgroup_v2.callysto.name}"]
  user_data       = "${var.cloudconfig}"

  network {
    name = "${var.network_name}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "fip" {
  floating_ip = "${openstack_networking_floatingip_v2.fip.address}"
  instance_id = "${openstack_compute_instance_v2.callysto.id}"
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip.address}"
}
