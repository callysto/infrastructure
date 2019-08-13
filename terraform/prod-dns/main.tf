// This is set by the Makefile.
variable "PROD_CALLYSTO_ZONE_ID" {}

resource "openstack_dns_recordset_v2" "callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "callysto.ca."
  type    = "A"

  records = [
    "178.128.229.90",
  ]
}

resource "openstack_dns_recordset_v2" "callysto_ca_mx" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "callysto.ca."
  type    = "MX"

  records = [
    "5 alt1.aspmx.l.google.com.",
    "10 aspmx2.googlemail.com.",
    "5 alt2.aspmx.l.google.com.",
    "10 aspmx3.googlemail.com.",
    "1 aspmx.l.google.com.",
  ]
}

resource "openstack_dns_recordset_v2" "callysto_ca_txt" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "callysto.ca."
  type    = "TXT"

  records = [
    "google-site-verification=EgQjUTwphS2LJKfwAg9Tzu_cgicMAMrxp2QRH2HyOMY",
  ]
}

resource "openstack_dns_recordset_v2" "courses_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "courses.callysto.ca."
  type    = "A"

  records = [
    "162.246.156.224",
  ]
}

resource "openstack_dns_recordset_v2" "hub_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "hub.callysto.ca."
  type    = "A"

  records = [
    "162.246.156.219",
  ]
}

resource "openstack_dns_recordset_v2" "hub_dev_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "hub-dev.callysto.ca."
  type    = "A"

  records = [
    "162.246.156.224",
  ]
}

resource "openstack_dns_recordset_v2" "studio_courses_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "studio-courses.callysto.ca."
  type    = "A"

  records = [
    "162.246.156.224",
  ]
}

resource "openstack_dns_recordset_v2" "star_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "*.callysto.ca."
  type    = "CNAME"

  records = [
    "callysto.ca.",
  ]
}

resource "openstack_dns_recordset_v2" "training_callysto_ca" {
  zone_id = "${var.PROD_CALLYSTO_ZONE_ID}"
  name    = "training.callysto.ca."
  type    = "CNAME"

  records = [
    "hosting.gitbook.com.",
  ]
}
