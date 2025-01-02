resource "openstack_dns_recordset_v2" "ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.instance.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_networking_port_v2" "port_1" {
  network_id = "${var.network_id}"
  #network_id = openstack_compute_instance_v2.instance.network.0.uuid
  device_id = openstack_compute_instance_v2.instance.id
}

resource "openstack_networking_floatingip_v2" "new_fip" {
  count = "${var.create_floating_ip == "true" ? 1 : 0}"
  pool  = "public"
}

resource "openstack_networking_floatingip_associate_v2" "new_fip" {
  count       = "${var.create_floating_ip == "true" ? 1 : 0}"
  floating_ip = "${openstack_networking_floatingip_v2.new_fip[0].address}"
  port_id     = openstack_networking_port_v2.port_1.id
}

resource "openstack_dns_recordset_v2" "new_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_networking_floatingip_associate_v2.new_fip[0].floating_ip}"]
}

resource "openstack_networking_floatingip_associate_v2" "existing_fip" {
  count       = "${var.existing_floating_ip != "" ? 1 : 0}"
  floating_ip = "${var.existing_floating_ip}"
  port_id     = openstack_networking_port_v2.port_1.id
}

resource "openstack_dns_recordset_v2" "existing_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_networking_floatingip_associate_v2.existing_fip[0].floating_ip}"]
}

locals {
  ip = "${
    coalesce(
      element(concat(openstack_networking_floatingip_associate_v2.new_fip.*.floating_ip, tolist([""])), 0),
      element(concat(openstack_networking_floatingip_associate_v2.existing_fip.*.floating_ip, tolist([""])), 0),
      sort(openstack_dns_recordset_v2.ipv6.records)[0]
    )
  }"
}

output "ip" {
  value = "${local.ip}"
}

output "dns_name" {
  value = "${var.name}"
}
