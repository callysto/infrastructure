resource "openstack_networking_secgroup_v2" "packer" {
  name = "packer"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_1" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_2" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "::/0"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_3" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_4" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "::/0"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_5" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "packer_rule_6" {
  security_group_id = "${openstack_networking_secgroup_v2.packer.id}"
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "icmp"
  remote_ip_prefix  = "::/0"
}
