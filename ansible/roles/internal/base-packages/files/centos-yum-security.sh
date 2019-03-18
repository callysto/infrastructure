#!/bin/bash

PATH="/usr/bin:/bin"
export PATH

DATE="$(date '+%Y/%m/%d %H:%M:%S (%Z)')"
HOSTNAME="$(hostname)"

subject="${HOSTNAME} centos-yum-security"
body=""

UPDATES_AVAILABLE=$(centos-yum-security -d)
if [ "$?" -eq 100 ] ; then
    printf -v msg '\n%s\n' "${UPDATES_AVAILABLE}"
    body+="${msg}"
else
    exit
fi


APPLY_UPDATES=$(centos-yum-security -y)
printf -v msg '\n%s\n' "${APPLY_UPDATES}"
body+="${msg}"

if [ -n "${body}" ] ; then
printf -v body 'This is the "centos-yum-security" script on %s run at %s.\n%s.' "${HOSTNAME}" "${DATE}" "${body}"
cat <<EOF | mailx -s "${subject}" root
${body}
EOF
fi
