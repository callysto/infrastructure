variable "cloudconfig" {
  type = "string"
  default = <<EOF
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

