variable "ssp_flavor_name" {
  type = "map"

  default = {
    prod = "m1.small"
    dev  = "m1.small"
  }
}

output "ssp_flavor_name" {
  value = "${var.ssp_flavor_name[var.environment]}"
}
