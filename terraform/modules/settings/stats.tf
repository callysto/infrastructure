variable "stats_flavor_name" {
  type = "map"

  default = {
    prod = "m1.large"
    dev  = "m1.medium"
  }
}

variable "stats_vol_zfs_size" {
  type = "map"

  default = {
    prod = "50"
    dev  = "25"
  }
}

output "stats_flavor_name" {
  value = "${var.stats_flavor_name[var.environment]}"
}

output "stats_vol_zfs_size" {
  value = "${var.stats_vol_zfs_size[var.environment]}"
}
