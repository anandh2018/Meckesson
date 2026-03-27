#!/usr/bin/perl

$fname = $ARGV[0];
$sleep_time = $ARGV[1];

sub usage() {

	print STDERR "usage: $0 file_name [sample_interval_seconds]\n";

}

if (! -f $fname) {
	&usage;
	exit(1);
}

if (! ($sleep_time > 0)) {
	$sleep_time = 5;
}

my $orig_size;
$start_time = time;
$prev_time = $start_time;

while (1 == 1) {
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fname);

	if (! defined($orig_size)) {
		$orig_size = $size;
	}

	if (($prev_size > 0) and ($prev_size <= $size)) {


		$curr_time = time;
		$rate = ($size - $prev_size) / ($curr_time - $prev_time) / (1024 * 1024);
		$prev_time = $curr_time;
		$elapsed_time = time - $start_time;

		$avg_rate = ($size - $orig_size) / ($curr_time - $start_time) / (1024 * 1024);

		print "size = $size, elapsed time = $elapsed_time, rate = " . sprintf('%.1f', $rate) . " MB/sec, avg rate = " . sprintf('%.1f', $avg_rate) . " MB/sec\n";
	}
		
	$prev_size = $size;
	sleep($sleep_time);
}
