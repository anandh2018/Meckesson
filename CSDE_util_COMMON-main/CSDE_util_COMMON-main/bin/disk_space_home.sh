#!/bin/sh
# disk_space_home.sh
# Will check if /home directory is over 90% on prod servers outside of dsgrid02a
# B.Oliver 7-22-22

df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $6 }' | while read output;
do
  echo $output
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 90 ] && [  $partition == "/home" ]; then
    echo "Running out of space \"$partition ($usep%)\" on $(hostname) as on $(date)" |
     mail -s "Alert: Almost out of disk space $usep%" DataServicesNotification@McKesson.com
  fi
done

