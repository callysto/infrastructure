resource "openstack_networking_secgroup_v2" "clavius" {
  name = "${var.name}"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.clavius.id}"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "::/0"
  security_group_id = "${openstack_networking_secgroup_v2.clavius.id}"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_v4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  security_group_id = "${openstack_networking_secgroup_v2.clavius.id}"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "icmp"
  security_group_id = "${openstack_networking_secgroup_v2.clavius.id}"
}
