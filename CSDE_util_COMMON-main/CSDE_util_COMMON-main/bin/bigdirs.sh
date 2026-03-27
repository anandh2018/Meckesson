
if [ "$*" = '' ]
  then
        echo "Usage: $0 dir1 [dir2] ..."
        exit 1
fi

du -m --exclude=data_sources --exclude=production $* |
sort -nr
