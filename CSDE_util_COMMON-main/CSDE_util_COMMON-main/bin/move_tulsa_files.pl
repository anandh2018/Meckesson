#!/usr/bin/perl
use File::Copy;
use strict;

#Make sure DS_BASE_DIR is set
our $DS_BASE_DIR = $ENV{DS_BASE_DIR};
die "ERROR: DS_BASE_DIR environment variable is '$DS_BASE_DIR', which is not an existing directory\n" if (! ((defined($DS_BASE_DIR)) && (-d $DS_BASE_DIR)));

#source directory
my $tulsa_root_directory = $DS_BASE_DIR . "/data_sources/incoming/tulsa";
#target directory
my $data_source_root_directory = $DS_BASE_DIR . "/data_sources/pclaims/T";
#input file
my $full_source_filename = shift @ARGV;

if ($full_source_filename =~ m/tulsa/) {

	if ( $full_source_filename =~ m/(CMST)_(\d{4})(\d{2})(\d{2}).dat.gz/ 
		|| $full_source_filename =~ m/(NSFe)_(\d{4})(\d{2})(\d{2})t.dat.gz/) {
		my $file_type = $1;
    my $year      = $2;
    my $month     = $3;
    my $day       = $4;

    #Check the file integrity
    my $gunzip_code = system("gunzip -t $full_source_filename");
    print "Checking file integrity...";
		$gunzip_code = $gunzip_code >> 8;
    if (0 != $gunzip_code) {
      print "File failed integrity check!: $full_source_filename returned code $gunzip_code\n";
      exit(100);
    }
    print "OK\n";

		my $abbr_name;
		my $subdir;

		if ( $file_type =~ 'CMST') {

			$abbr_name = 'NSFc_T';
			$subdir    = 'NSF_clean';

		} elsif ( $file_type =~ 'NSFe' ) {

			$abbr_name = 'NSFe_T';
			$subdir    = 'NSF_c1';

		#This should *NEVER* occur
		} else {

			print "Unknown file type: $file_type\n";
			exit(110);

		}

    #Create file name
		my $filename = $abbr_name . "_" . $year . $month . $day . ".dat.gz";
   	my $full_data_source_filename = $data_source_root_directory . "/" . $subdir . "/" . $year. $month . "/" . $filename;
  
    #Move file to destination
    print "Moving $full_source_filename to $full_data_source_filename...";
    if (! move($full_source_filename, $full_data_source_filename) ) {
      print "Error moving $full_source_filename to $full_data_source_filename: $!\n";
      exit(120);
    }
    print "OK\n";

  }
  else {
    print "File did not match expected naming convention (CMST)_(\d{4})(\d{2})(\d{2}).dat.gz or (NSFe)_(\d{4})(\d{2})(\d{2})t.dat.gz: $full_source_filename\n";
    exit(140);
  }
} else {
  print "Do not understand file source: $full_source_filename\n";
  exit(150);
}
