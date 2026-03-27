
if [ "$*" = '' ]
  then
	echo "Usage: $0 dir1 [dir2] ..."
	exit 1
fi

for f in `find $* -type f | grep -v '/data_sources/' |
#	grep -v /production/ |
	grep -v /lost+found/ |
	fsize |
	grep / |
	sort -nr |
	head -1000 |
	sed 's/  */,/g' |
	cut -d, -f3`
do
	ls -lh $f
done

