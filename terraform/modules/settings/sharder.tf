variable "sharder_flavor_name" {
  type = map

  default = {
    prod = "m1.small"
    dev  = "m1.small"
  }
}

variable "sharder_vol_zfs_size" {
  type = map

  default = {
    prod = "10"
    dev  = "5"
  }
}

output "sharder_flavor_name" {
  value = "${var.sharder_flavor_name[var.environment]}"
}

output "sharder_vol_zfs_size" {
  value = "${var.sharder_vol_zfs_size[var.environment]}"
}
