#!/bin/bash

PATH=$PATH:/bin:/usr/bin

if [[ -z $1 ]]; then
  exit 1
fi

master_ip=$(openstack coe cluster show $1 -c api_address -f value | cut -d: -f2 | tr -d /)
master_uuid=$(openstack server list --ip $master_ip -c ID -f value)
all_ips=($(openstack server show $master_uuid -c addresses -f value | cut -d= -f2 | tr -d ,))

ipv6="${all_ips[0]}"

if [[ "${#all_ips[@]}" == "3" ]]; then
  ipv4="${all_ips[2]}"
else
  ipv4="${all_ips[1]}"
fi

cat <<EOF
{
  "name": "$1",
  "ipv6": "${ipv6}",
  "ipv4": "${ipv4}"
}
EOF
