resource "null_resource" "create_swarm_cluster" {
  provisioner "local-exec" {
    command = <<-EOF
      /usr/bin/openstack coe cluster show ${var.cluster_name}
      if [[ $? == 1 ]]; then
        /usr/bin/openstack coe cluster create ${var.cluster_name} --cluster-template ${var.magnum_flavor_name} --master-count 1 --node-count ${var.node_count} --docker-volume-size ${var.volume_size} --keypair ${var.key_name}
        while true ; do
          status=$(/usr/bin/openstack coe cluster show ${var.cluster_name} -c status -f value)
          if [[ "$status" == "CREATE_COMPLETE" ]]; then
            break
          fi

          if [[ "$status" =~ *ERROR* ]]; then
            exit 1
          fi

          if [[ "$status" =~ *FAILED* ]]; then
            exit 1
          fi

          /usr/bin/sleep 30
        done
      fi

      /usr/bin/rm -rf ${path.root}/certs || /usr/bin/true
      /usr/bin/mkdir ${path.root}/certs || /usr/bin/true
      /usr/bin/openstack coe cluster config ${var.cluster_name} --dir ${path.root}/certs
    EOF
  }
}

data "external" "swarm_cluster_ips" {
  depends_on = ["null_resource.create_swarm_cluster"]
  program    = ["${path.root}/../bin/get-cluster-master-ips.sh", "${var.cluster_name}"]
}

resource "null_resource" "delete_swarm_cluster" {
  provisioner "local-exec" {
    command = <<-EOF
      /usr/bin/openstack coe cluster delete ${var.cluster_name}

      while true ; do
        status=$(/usr/bin/openstack coe cluster show ${var.cluster_name} -c status -f value)
        if [[ $? == 1 ]]; then
          break
        fi

        /usr/bin/sleep 30
      done

      /usr/bin/rm -rf ${path.root}/certs
    EOF

    when = "destroy"
  }
}

output "ipv4" {
  value = "${data.external.swarm_cluster_ips.result["ipv4"]}"
}

output "ipv6" {
  value = "${data.external.swarm_cluster_ips.result["ipv6"]}"
}
