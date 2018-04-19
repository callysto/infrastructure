resource "openstack_networking_floatingip_v2" "fip_1" {
  pool         = "public"
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
}

resource "openstack_compute_keypair_v2" "callysto" {
  name = "callysto"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "openstack_compute_instance_v2" "callysto-dev" {
  name            = "callysto-dev"
#  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d"
  image_name       = "CentOS 7"
  flavor_name       = "m1.large"
  key_pair        = "${openstack_compute_keypair_v2.callysto.name}"
  security_groups = ["${openstack_networking_secgroup_v2.callysto.name}"]
  user_data       = "${var.cloudconfig}"
  network {
    name = "default"
  }
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip_1.address}"
}
