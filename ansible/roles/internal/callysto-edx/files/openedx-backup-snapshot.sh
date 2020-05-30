#!/bin/bash
# script to backup openedx tutor to swift

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
export PATH

# source openstack cred
source /root/openrc

declare -i RETENTION
declare -i SNAPCOUNT
declare -i EXCEEDCOUNT
declare -i SNAPCTR
declare -i SWIFTCOUNT
declare -i SWIFTEXCEEDCOUNT
declare -i SWIFTCTR

CURRENTDATE=$(date +"%Y%m%d-%H%M%S")
ZFS_FS="tank/tutor"
ZFS_POOL="tank"
SNAPCOUNT=$(zfs list -t snapshot -o name 2> /dev/null | grep ^$ZFS_FS | wc -l)
# set backup retention (no. of snapshots/backups to keep)
RETENTION="30"
HOSTNAME=$(hostname)
SWIFTCONTAINER="${HOSTNAME}_backups"
SWIFTCOUNT=$(swift list ${SWIFTCONTAINER} -p zfs-snap 2> /dev/null | wc -l)

# check if pool exist
if ! zfs list -o name ${ZFS_FS} &> /dev/null; then
  echo "Cannot open '${ZFS_FS}': dataset does not exist. Exiting.."
  exit 2
fi

# enable listsnapshots if it is disabled
if [[ "$(zpool get listsnapshots ${ZFS_POOL} -o value | tail -n1)" != "on" ]]; then
  echo "Zpool property: listsnapshots is disabled for zfs pool: ${ZFS_POOL}. Enabling.."
  zpool set listsnapshots=on ${ZFS_POOL}
fi

#echo "Current zfs snapshot count: ${SNAPCOUNT}"

# check if no. of snapshots exceed retention
if [[ $SNAPCOUNT -gt $RETENTION ]]; then
  #echo "Current zfs snapshot(${SNAPCOUNT}) is greater than retention(${RETENTION})."
  EXCEEDCOUNT=$(expr $SNAPCOUNT - $RETENTION)
  while [[ $EXCEEDCOUNT -ne 0 ]]; do
    SNAPCTR=$(zfs list -t snapshot -o name | grep ^$ZFS_FS | wc -l)
    OLDEST_BACKUP=$(zfs list -t snapshot -o name -S creation | grep $ZFS_FS | tail -n1 | cut -d @ -f 2)
    EXCEEDCOUNT=$(expr $SNAPCTR - $RETENTION)
    #echo "Oldest zfs snapshot: ${OLDEST_BACKUP}"
    if [[ $EXCEEDCOUNT -ne 0 ]]; then
      zfs destroy -rv ${ZFS_FS}@${OLDEST_BACKUP}
    fi
    sleep 3
  done
fi

# create swift container if it does not exist
if ! swift stat ${SWIFTCONTAINER} &> /dev/null; then
  echo "Container '${SWIFTCONTAINER}' not found. Creating container.."
  swift post ${SWIFTCONTAINER}
fi

#echo ""
#echo "Current zfs snapshot backup count stored in swift: ${SWIFTCOUNT}"

# check if no. of swift backups exceed retention
if [[ $SWIFTCOUNT -gt $RETENTION ]]; then
  #echo "Current zfs snapshot backup(${SWIFTCOUNT}) stored in swift is  greater than retention(${RETENTION})."
  SWIFTEXCEEDCOUNT=$(expr $SWIFTCOUNT - $RETENTION)
  while [[ $SWIFTEXCEEDCOUNT -ne 0 ]]; do
    SWIFTCTR=$(swift list ${SWIFTCONTAINER} -p zfs-snap | wc -l)
    SWIFT_OLDEST_BACKUP=$(swift list ${SWIFTCONTAINER} -lp zfs-snap | sort -k2 -r | tail -n2 | head -n1 | awk '{print $5}')
    SWIFTEXCEEDCOUNT=$(expr $SWIFTCTR - $RETENTION)
    #echo "Oldest zfs snapshot backup in swift: ${SWIFT_OLDEST_BACKUP}"
    if [[ $SWIFTEXCEEDCOUNT -ne 0 ]]; then
      swift delete $SWIFTCONTAINER $SWIFT_OLDEST_BACKUP
    fi
    sleep 3
  done
fi

# create snapshot
echo "creating snapshot"
zfs snapshot -r ${ZFS_FS}@${CURRENTDATE}
sleep 3

# send snapshot to swift
echo "uploading snapshot to swift"
zfs send -R ${ZFS_FS}@${CURRENTDATE} | gzip | swift upload ${SWIFTCONTAINER} --object-name zfs-snap-${CURRENTDATE}.gz -
