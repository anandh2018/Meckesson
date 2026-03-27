#!/usr/bin/perl

$delim = ',';

if ($#ARGV >= 0) {
	$delim = $ARGV[0];
}

$line = <STDIN>;
chop($line);

@data = split("[${delim}]", $line);

$last_element = $#data;

$last_key_element = $last_element - 1;

$key = join(${delim}, @data[0 .. $last_key_element]);
$hash{$key} += $data[$last_element];

while ($line = <STDIN>) {
	$rec_num++;
	chop($line);
	@data = split("[${delim}]", $line);

#	if ($#data != $last_element) {
#		die "ERROR: Record $rec_num has " . ($#data + 1) . " fields, but record 1 has " . ($last_element + 1) . " fields. Record contains:
#$line\n";
#	}

	$key = join($delim, @data[0 .. $last_key_element]);
	$hash{$key} += $data[$last_element];

}

foreach $key (keys %hash) {
	print "${key}${delim}$hash{$key}\n" || die "ERROR: Unable to write record to standard output : $!\n";
}

