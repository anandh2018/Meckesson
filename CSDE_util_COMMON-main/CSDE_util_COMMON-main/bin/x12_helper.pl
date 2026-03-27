#!/usr/bin/perl

use X12::Parser;
use strict;

our $X12_HELPER_RE = qr/[~]ST[*](\d\d\d)[*].*[~]REF[*]87[*]([A-Za-z0-9]{10})/o;

sub x12_type ($) {

  my $config_file;
  my $fname = shift;

	if (! open(FH, "read_file $fname 2> /dev/null |")) {
		print STDERR "x12_type(): Could not open file $fname : $!\n";
		return undef;
	}

  my $head;
	read(FH, $head, 1000);
	close(FH);

  my ($type, $version);

	if ($head =~ $X12_HELPER_RE ) {
		($type, $version) = ($1, $2);
	}

	if ($type =~ /^\s*$/) {
		return undef;
	} else {
		return $type;
	}
}

sub x12_extended_type($) {
  my $fname = shift;
  my $config_file = x12_parserconfig($fname);
  my $config_file_basename = $config_file;

	$config_file_basename =~ s/.*\///g;

	if ($config_file =~ /^\s*$/) {
		return undef;
	}

  my $ref_file = "/staging/Q3/bluelite/perl/lib/X12/Parser/cf/reference.txt";

	if (! open(FH, $ref_file)) {
		print STDERR "error: could not open the file $ref_file: $!\n";
		return undef;
	}

  my ($extended_type, $config_base);

	while (<FH>) {
		chomp;

		($extended_type, $config_base) = split(',', $_);

		if ($config_base eq $config_file_basename) {
			return $extended_type;
		}
	}
}


sub x12_version ($) {

  my $config_file;
  my $fname = shift;

	if (! open(FH, "read_file $fname 2> /dev/null |")) {
		print STDERR "x12_version(): Could not open file $fname : $!\n";
		return undef;
	}

  my $head;
	read(FH, $head, 1000);
	close(FH);

  my ($type, $version);

	if ($head =~ $X12_HELPER_RE) {
		($type, $version) = ($1, $2);
	}

	if ($version =~ /^\s*$/) {
		return undef;
	} else {
		return $version;
	}
}

sub x12_parserconfig ($) {

  my $fname = shift;

	if (! defined($fname)) {
		return undef;
	}

  my $type = x12_type($fname);

	if (! defined($type)) {
		return undef;
	}

  my $version = x12_version($fname);

	if (! defined($version)) {
		return undef;
	}

  my	$config_file = "/ds/development/X12/Parser_v0.5/Spec/cf/${type}_${version}.cf";

	if (! -f $config_file) {
		print STDERR "x12_parserconfig: Expected config file of '$config_file' does not exist. x12 type = '$type', version = '$version'\n";
		return undef;
	}

	return $config_file;
}

return 1;
