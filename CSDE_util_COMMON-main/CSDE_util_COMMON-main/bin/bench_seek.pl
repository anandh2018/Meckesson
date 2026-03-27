#!/usr/bin/perl -w

use Data::Dumper;
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use strict;
use Time::HiRes qw(time);

#if (scalar(@ARGV) != 2) {
#	die "Usage: raw_fname #_iterations\n";
#}

my ($iterations) = shift(@ARGV);


my ($bytes, $raw_bytes_read, $sl_bytes_read, $sl_buffer, $raw_buffer, $position);
my $matches = 0;
my $mismatches = 0;
my ($raw_seek_ret, $sl_seek_ret);
my $seek_type;
my ($whence, $whence_text);

$bytes = 12000;
my $total_bytes = 0;


my $alt_dir = '/scsi15k_1';
my $fname;
my $alt_fname;
my $fsize;
my (@seeks, $i, $start_time, $end_time, $elapsed, @info, $improvement_pct, $improvement_pct_txt, $num_tests, $total_improvement);

while (<>) {
	chomp;

	$fname = $_;
	$alt_fname = $fname;
	$alt_fname =~ s/^\/[^\/]+\///;
	$alt_fname = "$alt_dir/$alt_fname";

	$fsize = -s $fname;

	@seeks = ();

	for($i = 0; $i < $iterations; $i++) {

		$seek_type = int(rand(3));

		if ($seek_type == 0) {
			$whence = SEEK_SET;
			$whence_text = 'SEEK_SET';
			$position = int(rand($fsize) - 0.25 * $fsize);
		} elsif ($seek_type == 1) {
			$whence = SEEK_CUR;
			$whence_text = 'SEEK_CUR';
			$position = $bytes * 5;
		} elsif ($seek_type == 2) {
			$whence = SEEK_END;
			$whence_text = 'SEEK_END';
			$position = -1 * int(rand($fsize) - 0.25 * $fsize);
		} else {
			die "unknown seek_type of $seek_type\n";
		}

		push(@seeks, $position, $whence);
	}

	@info = ();

	foreach $fname ($fname, $alt_fname) {

		$start_time = time;

		open(RAW, $fname) || die "Cannot open $fname: $!";

		$total_bytes = 0;

		for($i = 0; $i <= $#seeks; $i += 2) {
			($position, $whence) = ($seeks[$i], $seeks[$i + 1]);

			$raw_seek_ret = seek(RAW, $position, $whence);

			$raw_bytes_read = read(RAW, $raw_buffer, $bytes);

			$total_bytes += $raw_bytes_read;
		}

		close(RAW);

		$end_time = time;
		$elapsed = $end_time - $start_time;

		push(@info, { fname => $fname, elapsed => $elapsed, fsize => $fsize, reads => $iterations });

		print "$fname : $total_bytes bytes read out of $fsize  = " . sprintf('%.0f', $total_bytes * 100 / $fsize) . "% . Elapsed = $elapsed\n";

	}

	$improvement_pct = ($info[0]->{elapsed} / $info[1]->{elapsed} - 1) * 100;
	$improvement_pct_txt = sprintf('%.1f', $improvement_pct);

	$num_tests++;
	$total_improvement += $improvement_pct;

	print "$fname : " . "elapsed1 = $info[0]->{elapsed}, elapsed2 = $info[1]->{elapsed}, imp% = $improvement_pct_txt\n";
	#print Dumper \@info;
	#print "improvement = $improvement_pct %\n\n";

}

print "num tests = $num_tests\n";

my $speed_improvement_pct = $total_improvement / $num_tests;
print "avg speed improvement = " . sprintf('%.0f', $speed_improvement_pct) . " %\n";

my $new_elapsed_pct = sprintf('%.0f', 100 / ($speed_improvement_pct / 100 + 1));
print "new elapsed = $new_elapsed_pct % of old elapsed\n";
