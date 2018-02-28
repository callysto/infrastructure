# Build a Hub for Callysto

## Terraform
The resources are controlled by terraform so we can destroy and recreate
everything quickly.
 
 * deb21990-9256-4ac3-ac7c-b7cb5275d619: m1.8c32g
 * deb21990-9256-4ac3-ac7c-b7cb5275d619: CentOS 7
 * 2 * 50G volumes for user homedir backing

### Setup
You will need to make some environment variables available for terraform to talk
to openstack. As an example, we need the variable `${var.os_cybera_password}`
inside terraform, we can do this by defining TF_VAR_os_cybera_password before
running terraform. There's an `init.sh` script in the terraform directory which
should be able to handle most of this
```
  $ cd terraform
  $ . init.sh
  $ echo $TF_VAR_os_project_name
```


### First Time
You will need the openstack plugin and some other bits and pieces so run
`terraform init` in the terraform directory
```
  $ cd terraform
  $ terraform init
```

### Terraform apply
`terraform apply` will create the resources for you
