#!/bin/bash

# Set the path
PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
export PATH

# source openstack cred
source /root/openrc

declare -i dir_size=0
declare -i dir_size_total=0
declare -i zfs_used_space=0
declare -i total_zfs_used_space
declare -i zfs_free_space
declare -i zfs_free_space_after_cleanup
declare -i gib=1073741824
declare -i mib=1048576
declare -i kib=1024
declare -i daycount
daycount=365
old_users=$(sqlite3 /srv/jupyterhub/jupyterhub.sqlite "select name from users where last_activity < date('now', '-${daycount} days')")

zpool_size=$(zpool list -Ho size tank)
zfs_free_space=$(zfs get -Hp avail -o value tank/home)
old_users_count=$(sqlite3 /srv/jupyterhub/jupyterhub.sqlite "select count(name) from users where last_activity < datetime('now', '-${daycount} days')")
total_user_count=$(sqlite3 /srv/jupyterhub/jupyterhub.sqlite "select count(name) from users")

# Function to check for user last activity older than the day count set.
check_inactive_users() {

# Exit if there is no inactive user found.
if [[ -z ${old_users} ]]; then
echo "No inactive users found. Exiting."
exit
fi

# Loop through inactive users and print some info.
for i in $old_users; do
last_activity=$(sqlite3 /srv/jupyterhub/jupyterhub.sqlite "select strftime('%Y-%m-%d %H:%M:%S', last_activity) from users where name = '${i}'")
zfs_used_space_conv=$(zfs get -H used -o value tank/home/${i} 2> /dev/null)
zfs_used_space=$(zfs get -Hp used -o value tank/home/${i} 2> /dev/null)
total_zfs_used_space=$((${total_zfs_used_space} + ${zfs_used_space}))
#echo "Found inactive user: $i"
#echo "Date of last activity: ${last_activity}"
#echo "Zfs storage space used: ${zfs_used_space_conv}"
#echo ""
done

zfs_free_space_after_cleanup=$((${zfs_free_space} + ${total_zfs_used_space}))
echo "Current total zfs free space: $(zfs get -H avail -o value /tank/home)"
}

# Function to convert bits to Gib/Mib/Kib
convert_bits() {

if [[ $1 -ge ${gib} ]]; then
result=$(echo "print(f'{$1/${gib}:.02f}G')" | python3)

elif [[ $1 -ge ${mib} ]]; then
result=$(echo "print(f'{$1/${mib}:.02f}M')" | python3)

else
result=$(echo "print(f'{$1/${kib}:.02f}K')" | python3)
fi
}

# Check if inactive users data have been archived.
archive_inactive_users() {

# Exit if there is no inactive user found.
if [[ -z ${old_users} ]]; then
echo "No inactive users found. Exiting."
exit
fi

cd /tank
echo "Checking if their account has already been archived."
for i in $old_users; do
# Swift check to see if their account has already been archived
swift stat archived_users ${i}.tar.gz &> /dev/null

# If the return code is 0, then the user has already been archived.
# For now, we'll skip re-archiving their account.
if [[ $? == 0 ]]; then
  echo "User $i has already been archived. Skipping.."
  continue
else
  echo "User $i has not been archived."
fi

# Tar their home directory and upload it to swift
echo "Archiving ${i} home directory."
tar czf ${i}.tar.gz /tank/home/${i} &> /dev/null
swift upload archived_users ${i}.tar.gz

# If there was an error, report it and move on
# using != 0 to capture other error code
if [[ $? != 0 ]]; then
  echo "Error uploading ${i}.tar.gz to swift"
  continue

fi

# Check if a cleanup notice exist. If it doesn't exist,
# delete the contents of user's home directory and
# generate the cleanup notice.

cleanup_notice="/tank/home/${i}/Inactive-Account-Notice.txt"
if [[ ! -f $cleanup_notice ]]; then
# Delete contents of home directory using rm instead of destroying zfs dataset.
echo "Removing home directory contents."
rm -rf /tank/home/${i}/*
# Delete created tar in tank directory
echo "Removing created tar."
rm -rf /tank/${i}.tar.gz

echo "Putting inactive notice in home directory."
cat > /tank/home/${i}/Inactive-Account-Notice.txt <<EOF
Hi,

We noticed that you have been inactive for a while.
Because of this inactivity, we archived the contents of your jupyterhub.
If you need your old contents restored, feel free to contact sysadmin@callysto.ca and we can take a look at restoring it.
Please note that restoring your old contents is not guaranteed.

Thank you.
EOF

else
  echo "Cleanup notice exist."
fi
done
}

while :
do
echo -e "Please choose an option: [1/2/3]"
echo -e "1. Check inactive users. This will output general details like zfs storage space and total inactive users."
echo -e "2. Archive inactive users. This will archive the home directory of inactive users, upload them to swift, remove home directory contents, and create a notice."
echo -e "3. Exit."

read -sn 1 RES
if [[ $RES == '1' ]]; then
echo "Zpool size: ${zpool_size}"
check_inactive_users
# Outputs the converted ${total_zfs_used_space}
convert_bits ${total_zfs_used_space}
echo "Total zfs storage space used by inactive users: ${result}"
# Outputs the converted ${zfs_free_space_after_cleanup}
convert_bits ${zfs_free_space_after_cleanup}
echo "New zfs free space after cleanup: ${result}"
echo "Total user count: ${total_user_count}"
echo "Total inactive users that haven't signed in for the last ${daycount} days: ${old_users_count}"
exit

elif [[ $RES == '2' ]]; then
archive_inactive_users
exit

elif [[ $RES == '3' ]]; then
exit

else
  clear
  echo -e "Please enter a valid response or ctrl-c to exit. \n"
fi
done
