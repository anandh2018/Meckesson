#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Data::Dumper;
use DS::Dimension::Functional::EMI::PatientSearch;
use Getopt::Long;

my $orig_file = select STDERR;

#declare options for use below
my $first_name;
my $last_name;
my $gender;
my $dob;
my $zip;
my $member_id;
my $allow_test_cases;
my $db_user;
my $threshhold;

#valid options
GetOptions( "first_name|f:s"        => \$first_name,
            "last_name|l:s"         => \$last_name,
            "gender|g:s"            => \$gender,
            "dob|d:s"               => \$dob,
            "zip|z:s"               => \$zip,
            "member_id|m:s"         => \$member_id,
            "allow_test_cases|a:s"  => \$allow_test_cases,
            "db_user|u:s"           => \$db_user,
            "threshhold|t:s"         => \$threshhold
          );



#------------------------------------------------------------------------------#
# set default threshhold if it wasnt specified                                 #
#------------------------------------------------------------------------------#
if ( ! defined $threshhold ) {
  $threshhold = 34;
}

#------------------------------------------------------------------------------#
# set default db_user if it wasnt specified                                    #
#------------------------------------------------------------------------------#
if ( ! defined $db_user ) {
  $db_user = "emi_patient_prod";
}

#Create patient object
my $patient_obj = DS::Dimension::Functional::EMI::Patient->new(db_user => $db_user, schema => $db_user);

#------------------------------------------------------------------------------#
# load search criteria                                                         # 
#------------------------------------------------------------------------------#
my $criteria = {};

if ( defined $first_name
  && 0 < length($first_name) ) {
    $criteria->{first_name} = $first_name;
}
if ( defined $last_name 
  && 0 < length($last_name) ) {
    $criteria->{last_name} = $last_name;
}
if ( defined $gender 
  && 0 < length($gender) ) {
    $criteria->{gender} = $gender;
}
if ( defined $dob 
  && 0 < length($dob) ) {
    $criteria->{dob} = $dob;
}
if ( defined $zip 
  && 0 < length($zip) ) {
  $criteria->{zip} = $zip;
}

#------------------------------------------------------------------------------#
# cardholder logic                                                             #  
#------------------------------------------------------------------------------#
if ( defined $member_id 
  && 0 < length($member_id ) ) {
    if ( ( ! defined $allow_test_cases )
      || ( $allow_test_cases == 0 )
      || ( $allow_test_cases == 1 && $member_id !~ m/^TEST_CASE_/ ) )  {
        $criteria->{cardholder_id} = $member_id; 
  }
}

#------------------------------------------------------------------------------#
# perform the search                                                           #
#------------------------------------------------------------------------------#
my $pt_search;

eval {
  $pt_search = $patient_obj->executeSearch($criteria, $threshhold);
};

#------------------------------------------------------------------------------#
# if there's an error write to STDERR - otherwise print result to STDOUT       #
#------------------------------------------------------------------------------#

select $orig_file;

if ($@) {
  print STDERR $@;
}

else {
  foreach my $result ( @{$pt_search} ) {
    print $result . "\n";
  };
}

$patient_obj->DESTROY();
