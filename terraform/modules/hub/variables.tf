variable "floating_ip_pool" {}

variable "image_id" {}

variable "flavor_name" {}

variable "key_name" {}

variable "network_name" {}

variable "name_suffix" {
  default = ""
}

variable "domain" {
  default = "callysto.ca"
}

locals {
  name = "${format("callysto%s.%s", var.name_suffix, var.domain)}"

  cloudconfig = <<EOF
    #cloud-config
    preserve_hostname: true
    runcmd:
      - sed -i '/\/dev\/sdb/d' /etc/fstab
      - swaplabel -L swap0 /dev/sdb
      - echo "LABEL=swap0 none  swap  defaults  0  0" >> /etc/fstab
    system_info:
      default_user:
        name: ptty2u
  EOF
}
