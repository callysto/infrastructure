provider "openstack" {
  user_name    = "${var.os_username}"
  password     = "${var.os_password}"
  auth_url     = "${var.os_auth_url}"
  tenant_name  = "${var.os_tenant_name}"
  tenant_id    = "${var.os_tenant_id}"
  region       = "${var.os_region_name}"
}

resource "openstack_blockstorage_volume_v2" "zfsvol1" {
  name = "docker"
  size = 50
}

resource "openstack_blockstorage_volume_v2" "zfsvol2" {
  name = "docker"
  size = 50
}

resource "openstack_networking_floatingip_v2" "fip_1" {
  pool         = "public"
}

resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
}

resource "openstack_compute_instance_v2" "callysto-dev" {
  name            = "callysto-dev"
  image_id        = "10076751-ace0-49b2-ba10-cfa22a98567d"
  flavor_id       = "1a9598b6-1cf9-452a-b7fd-64844382a709"
  key_pair        = "id_cybera_openstack"
  security_groups = ["default","ssh","ping"]
  user_data       = "${var.cloudconfig_default_user}"
  network {
    name = "default"
  }
}

resource "openstack_compute_volume_attach_v2" "zfsvol1" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol1.id}"
}
resource "openstack_compute_volume_attach_v2" "zfsvol2" {
  instance_id = "${openstack_compute_instance_v2.callysto-dev.id}"
  volume_id = "${openstack_blockstorage_volume_v2.zfsvol2.id}"
}

output "ip" {
  value = "${openstack_networking_floatingip_v2.fip_1.address}"
}
