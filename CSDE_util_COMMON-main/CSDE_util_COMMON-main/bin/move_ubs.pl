#!/usr/bin/perl

use File::Copy;
use strict;

my $verispan_root_directory = "/ds/production/verispan/incoming";
my $data_source_root_directory = "/ds/data_sources/hospital_claims";
my $full_source_filename = shift @ARGV;

if ($full_source_filename =~ m/tulsa/) {
  my $file_source  = "tulsa";
  my $short_source = "T";
  if ($full_source_filename =~ m/ub_(raw|phi)_(\d{4})(\d{2})(\d{2}).dat.gz/) {
    my $file_type = $1;
    my $year      = $2;
    my $month     = $3;
    my $day       = $4;
    
    #Test file
    my $gunzip_code = system("gunzip -t $full_source_filename");
    print "Checking file integrity...";
    if (0 != $gunzip_code) {
      print "File failed integrity check!: $full_source_filename returned code $gunzip_code\n";
      exit(100);
    }
    print "OK\n";
    
    #Set up file naming conventions
    my $short_type = undef;
    if ($file_type eq "raw") {
      $file_type  = "raw";
      $short_type = "r";
    }
    elsif ($file_type eq "phi") {
      $file_type  = "c1";
      $short_type = "e";
    }
    else {
      print "Error - Do not understand file type: $full_source_filename has type $file_type\n";
      exit(110);
    }
    
    #Create file name
    my $filename = "UB" . $short_type . "_" . $short_source . "_" . $year . $month . $day . ".dat.gz";
    my $full_data_source_filename = $data_source_root_directory . "/" . $file_source . "/UB_" .$file_type . "/" . $year . $month . "/" . $filename;

    #Move file to destination
    print "Moving $full_source_filename to $full_data_source_filename...";
    if (! move($full_source_filename, $full_data_source_filename) ) {
      print "Error moving $full_source_filename to $full_data_source_filename: $!\n";
      exit(120);
    }
    print "OK\n";
    
		# COMMENTED OUT (dliu) on 3/29/2010. Verispan has been disabled.

    #Copy raw files to verispan incoming directory
    #if ($file_type eq "raw") {
      #Create verspan file name
    #  my $full_verispan_filename = $verispan_root_directory . "/" . $filename;
    #  print "Copying $full_data_source_filename to $full_verispan_filename...";
    #  if (! copy($full_data_source_filename, $full_verispan_filename) ) {
    #    print "Error moving $full_data_source_filename to $full_verispan_filename: $!\n";
    #    exit(130);
    #  }
    #  print "OK\n";
    #}
  }
  else {
    print "File did not match expected naming convention ub_(raw|phi)_YYYYMMDD.dat.gz: $full_source_filename\n";
    exit(140);
  }
} else {
  print "Do not understand file source: $full_source_filename\n";
  exit(150);
}
