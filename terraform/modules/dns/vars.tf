variable "zone_id" {
  default = "fb1e23f2-5eb9-43e9-aa37-60a5bd7c2595"
}

variable "domain_name" {
  default = "callysto.farm"
}

output "zone_id" {
  value = "${var.zone_id}"
}

output "domain_name" {
  value = "${var.domain_name}"
}
