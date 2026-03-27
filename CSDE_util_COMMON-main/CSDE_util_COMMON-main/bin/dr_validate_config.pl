#!/usr/bin/perl

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#	read in DataRights configuration file, test validity against *.xsd
#
#	dr_validate_config.pl --help
#
#	Oct 29, 2013 Michael Carey
#		BEGIN
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

use strict;
use warnings;
use XML::LibXML;
use File::Spec;
use Getopt::Long;

my $xml_file = '';
my $xsd_file = '';
my $help     = '';
my $result = GetOptions(
						 "xml_file=s" => \$xml_file,
						 "xsd_file=s" => \$xsd_file,
						 "help"       => \$help,
						 );

if ($help) {
	show_help();
	exit(0);
}

# for xml config file, if file is not specified on the command line,
# use the path/name stored in PDC_CONFIG_INFO environment variable
my $xml = '';
if ($xml_file) {

	# we will use file from the command line
	print("using $xml_file for test\n");
	$xml = $xml_file;
	
} else {

	print("xml file not specified on command line\n");

	if ( exists $ENV{PDC_CONFIG_INFO} ) {

		$xml = $ENV{PDC_CONFIG_INFO};
		print("using $ENV{PDC_CONFIG_INFO} from environment variable\n");

	} else {

		show_help();
		print("no xml file to validate\n");
		die("PDC_CONFIG_INFO environment variable not defined\n");

	}

} ## end else [ if ($xml_file) ]

# test file for existence and readability, die if bad
test_file($xml);

# if *.xsd file is specified on command line, use that, else
# use environment variable to construct *.xsd
my $xsd = '';
if ($xsd_file) {

	# we will use xsd file from the command line
	print("using $xsd_file for test\n");
	$xsd = $xsd_file;
	
} else {

	print("xsd file not specified on command line\n");

	if ( exists $ENV{PDC_CONFIG_INFO} ) {

		$xsd = $ENV{PDC_CONFIG_INFO};
		print("constructing xsd path/filename from environment variable\n");

	} else {

		show_help();
		print("cannot construct xsd filename, specify one on the cmd line\n");
		die("PDC_CONFIG_INFO environment variable not defined\n");

	}

	# construct *.xsd path/filename
	my $volume;
	my $dirs;
	( $volume, $dirs, $xsd ) = File::Spec->splitpath($xsd);

	# make sure the config file has an xml extension
	if ( $xsd =~ m/.xml$/ ) {

		# good, the config file has an xml extension
	} else {

		print("$xsd does not appear to have an xml extension\n");
		die("cannot construct *.xsd file, provide one on the command line");

	}

	$xsd =~ tr/.xml$/.xsd/;

	$xsd = File::Spec->catpath( $volume, $dirs, $xsd );
	print("using $xsd as template\n");

} ## end else [ if ($xsd_file) ]

# test file for existence and readability, die if bad
test_file($xsd);

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# open file read in xml config perform some validation
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $xml_parser;
my $xml_doc;
my $xmlref;
my $xml_schema;
my $xml_vstat = 1;    # ->validate either returns 0 or dies
eval {
	# validating with XML::LibXML
	$xml_parser = XML::LibXML->new();
	$xml_doc    = $xml_parser->parse_file($xml);
	$xml_schema = XML::LibXML::Schema->new( location => $xsd );
	$xml_vstat  = $xml_schema->validate($xml_doc);

};
if ( ( $xml_vstat != 0 ) || $@ ) {
	die("$xml NOT VALID, $@\n");
}

if ( $xml_vstat == 0 ) {
	print("$xml PASSED VALIDATION!\n");
}

exit(0);

sub show_help {
	print <<EOT;

Validate a DataRights configuration XML file agianst an XSD.  This is a command
line utility for BLUELITE::DataRights.

Usage:

  dr_validate_config.pl --xml_file=FILE [--xsd_file=FILE] [--help]

Options:

  --xml_file=FILE  DataRights xml config file to test for validity
  
  --xsd_file=FILE  Xsd template to use for validating.  If xsd is not specified
                   here, the file defined by environment variable
                   PDC_CONFIG_INFO will be used.  It's xml exension will be
                   converted to xsd.

  --help           Show this help

EOT

	return (1);
} ## end sub show_help

sub test_file {
	my $tst_file = shift() || '';

	# test file for existence and readability
	# make sure the file exists
	if ( -e $tst_file ) {

		# GOOD, file exists
	} else {

		die("file doesn't exist: $tst_file");

	}

	# make sure the config file is readable
	if ( -r $tst_file ) {

		# GOOD, file is readable
	} else {

		die("file not readable: $tst_file");

	}

	return(1);
} ## end sub test_file

=head1 dr_validate_config.pl

Validate a DataRights configuration XML file agianst an XSD.  This is a command
line utility for BLUELITE::DataRights.

=head1 SYNOPSIS

 dr_validate_config.pl  (test config file specified in env var PDC_CONFIG_INFO)
 
 dr_validate_config.pl --xml_file=test_config.xml   (test specified XML file 
                                                     using production XSD.)

 dr_validate_config.pl --xsd_file=test_xsd.xsd  (test production XML file using
                                                 specified XSD)

 dr_validate_config.pl --xml_file=test_config.xml --xsd_file=test_xsd.xsd
                       (test specified XML file using specified XSD file)

 dr_validate_config.pl --help (show help)

 
=head1 DESCRIPTION

This command line utility uses XML::LibXML to test an XML file against an XSD.
If file path/names are not specified on the command line, the environment
variable PDC_CONFIG_INFO is used.

=head2 Options

=over 4

=item --xml_file=FILE

Specify the XML file to test.  If omitted, the environment variable
 PDC_CONFIG_INFO will be used.
 
=item --xsd_file=FILE

Specify the XSD file to use for validation.  If one is not specified, the
environment variable PDC_CONFIG_INFO is used.  The 'xml' extension is replaced
with 'xsd'.

=item --help

Show help text

=back

=head1 AUTHOR

=over 4

=item Michael Carey <michael.carey@mckesson.com>

=back

=head1 COPYRIGHT

 Copyright 2013 RelayHealth/McKesson.  All rights reserved.

=cut

__END__
