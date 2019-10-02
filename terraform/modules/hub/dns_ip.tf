resource "openstack_dns_recordset_v2" "hub_ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.hub.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_networking_floatingip_v2" "hub" {
  count = "${var.create_floating_ip == "true" ? 1 : 0}"
  pool  = "public"
}

resource "openstack_compute_floatingip_associate_v2" "hub_new_fip" {
  count       = "${var.create_floating_ip == "true" ? 1 : 0}"
  instance_id = "${openstack_compute_instance_v2.hub.id}"
  floating_ip = "${openstack_networking_floatingip_v2.hub.address}"
}

resource "openstack_dns_recordset_v2" "hub_new_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.hub_new_fip.floating_ip}"]
}

resource "openstack_compute_floatingip_associate_v2" "hub_existing_fip" {
  count       = "${var.existing_floating_ip != "" ? 1 : 0}"
  instance_id = "${openstack_compute_instance_v2.hub.id}"
  floating_ip = "${var.existing_floating_ip}"
}

resource "openstack_dns_recordset_v2" "hub_existing_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.hub_existing_fip.floating_ip}"]
}

locals {
  hub_ip = "${
    coalesce(
      element(concat(openstack_compute_floatingip_associate_v2.hub_new_fip.*.floating_ip, list("")), 0),
      element(concat(openstack_compute_floatingip_associate_v2.hub_existing_fip.*.floating_ip, list("")), 0),
      openstack_dns_recordset_v2.hub_ipv6.records[0]
    )
  }"
}

output "hub_ip" {
  value = "${local.hub_ip}"
}

output "dns_name" {
  value = "${var.name}"
}
