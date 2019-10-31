variable "edx_flavor_name" {
  type = "map"

  default = {
    prod = "m1.40g100g8c32g"
    dev  = "m1.40g100g4c8g"
  }
}

variable "edx_vol_zfs_size" {
  type = "map"

  default = {
    prod = "100"
    dev  = "25"
  }
}

output "edx_flavor_name" {
  value = "${var.edx_flavor_name[var.environment]}"
}

output "edx_vol_zfs_size" {
  value = "${var.edx_vol_zfs_size[var.environment]}"
}
