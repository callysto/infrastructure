variable "image_id" {}

variable "flavor_name" {}

variable "key_name" {}

variable "network_name" {}

variable "zone_id" {}

variable "name" {
  default = ""
}

variable "create_floating_ip" {
  default = "false"
}

variable "existing_floating_ip" {
  default = ""
}

locals {
  cloudconfig = <<EOF
    #cloud-config
    preserve_hostname: true
    runcmd:
      - sed -i '/\/dev\/sdb/d' /etc/fstab
      - sed -i '/\/dev\/sdc/d' /etc/fstab
      - swaplabel -L swap0 /dev/sdb
      - echo "LABEL=swap0 none  swap  defaults  0  0" >> /etc/fstab
    system_info:
      default_user:
        name: ptty2u
  EOF
}
