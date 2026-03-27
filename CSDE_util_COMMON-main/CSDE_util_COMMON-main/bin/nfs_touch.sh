for i in `cat /etc/mtab | grep nfs | awk {'print $2'} | grep -v lib`
  do
		stat $i > /dev/null && [ -t 0 ] && echo $i
  done
