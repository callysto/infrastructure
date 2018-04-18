resource "openstack_blockstorage_volume_v2" "zfsvol1" {
  name = "docker"
  size = 50
}

resource "openstack_blockstorage_volume_v2" "zfsvol2" {
  name = "docker"
  size = 50
}

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
  user_data       = "${var.cloudconfig_default_user}"
  network {
    name = "default"
  }
}

resource "openstack_compute_volume_attach_v2" "zfsvol1" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol1.id}"
}
resource "openstack_compute_volume_attach_v2" "zfsvol2" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol2.id}"
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip_1.address}"
}


# Security Group

resource "openstack_networking_secgroup_v2" "callysto" {
    name = "Callysto"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "::/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "http_world_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "https_world_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "http_world_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "::/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "https_world_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "::/0"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}


resource "openstack_networking_secgroup_rule_v2" "icmp_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "icmp"
  security_group_id = "${openstack_networking_secgroup_v2.callysto.id}"
}

