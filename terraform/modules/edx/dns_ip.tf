resource "openstack_dns_recordset_v2" "name_ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.instance.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_dns_recordset_v2" "cms_ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.cms_name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.instance.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_dns_recordset_v2" "lms_ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.lms_name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.instance.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_dns_recordset_v2" "preview_ipv6" {
  zone_id = "${var.zone_id}"
  name    = "${var.preview_name}."
  ttl     = 60
  type    = "AAAA"

  records = [
    "${replace(openstack_compute_instance_v2.instance.access_ip_v6, "/[][]/", "")}",
  ]
}

resource "openstack_networking_floatingip_v2" "new_fip" {
  count = "${var.create_floating_ip == "true" ? 1 : 0}"
  pool  = "public"
}

resource "openstack_compute_floatingip_associate_v2" "new_fip" {
  count       = "${var.create_floating_ip == "true" ? 1 : 0}"
  instance_id = "${openstack_compute_instance_v2.instance.id}"
  floating_ip = "${openstack_networking_floatingip_v2.new_fip.address}"
}

resource "openstack_dns_recordset_v2" "new_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.new_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "new_cms_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.cms_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.new_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "new_lms_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.lms_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.new_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "new_preview_fip" {
  count   = "${var.create_floating_ip == "true" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.preview_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.new_fip.floating_ip}"]
}

resource "openstack_compute_floatingip_associate_v2" "existing_fip" {
  count       = "${var.existing_floating_ip != "" ? 1 : 0}"
  instance_id = "${openstack_compute_instance_v2.instance.id}"
  floating_ip = "${var.existing_floating_ip}"
}

resource "openstack_dns_recordset_v2" "existing_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.existing_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "existing_cms_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.cms_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.existing_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "existing_lms_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.lms_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.existing_fip.floating_ip}"]
}

resource "openstack_dns_recordset_v2" "existing_preview_fip" {
  count   = "${var.existing_floating_ip != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "${var.preview_name}."
  ttl     = 60
  type    = "A"

  records = ["${openstack_compute_floatingip_associate_v2.existing_fip.floating_ip}"]
}

locals {
  ip = "${
    coalesce(
      element(concat(openstack_compute_floatingip_associate_v2.new_fip.*.floating_ip, list("")), 0),
      element(concat(openstack_compute_floatingip_associate_v2.existing_fip.*.floating_ip, list("")), 0),
      openstack_dns_recordset_v2.name_ipv6.records[0]
    )
  }"
}

output "ip" {
  value = "${local.ip}"
}

output "dns_name" {
  value = "${var.name}"
}
