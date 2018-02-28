variable "os_password" {}

# TF_VAR_os_username
variable "os_username" {
  default = "ifallison@gmail.com"
}

# TF_VAR_os_tenant_name {
variable "os_tenant_name" {
  default = "jupyter-dev"
}

# TF_VAR_os_tenant_id {
variable "os_tenant_id" {
  default = "d22d1e3f28be45209ba8f660295c84cf"
}

# TF_VAR_os_auth_url 
variable "os_auth_url" {
  default = "https://keystone-yyc.cloud.cybera.ca:5000/v2.0"
}

# TF_VAR_os_region_name
variable "os_region_name" {
  default = "Calgary"
}

variable "cloudconfig_default_user" {
  type = "string"
  default = <<EOF
#cloud-config
system_info:
  default_user:
    name: ptty2u
EOF
}

