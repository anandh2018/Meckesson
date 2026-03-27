
status=0

for f in $*
  do
	case $f in
	*.zip)	cmd=unzip
		;;
	*.gz)	cmd=gunzip
		;;
	*)	echo "cannot determine file type"
		exit 1
		;;
	esac

	$cmd -t $f > /dev/null 2>&1
	if [ "$?" -ne 0 ]
	  then
		echo "$f:ERROR"
		status=1
	  else
		echo "$f:OK"
	fi
  done

exit $status

