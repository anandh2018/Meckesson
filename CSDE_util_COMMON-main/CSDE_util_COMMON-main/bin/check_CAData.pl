#!/usr/bin/perl

# ===============================================================
#  _____  ___   ______      _                 _                               
# /  __ \/ _ \  |  _  \    | |               | |                              
# | /  \/ /_\ \ | | | |__ _| |_ __ _ ___  ___| |_                             
# | |   |  _  | | | | / _` | __/ _` / __|/ _ \ __|                            
# | \__/\ | | | | |/ / (_| | || (_| \__ \  __/ |_                             
#  \____|_| |_/ |___/ \__,_|\__\__,_|___/\___|\__|
#
#  _____           _            _____ _               _    
# |  ___|         (_)          /  __ \ |             | |   
# | |____  ___ __  _ _ __ ___  | /  \/ |__   ___  ___| | __
# |  __\ \/ / '_ \| | '__/ _ \ | |   | '_ \ / _ \/ __| |/ /
# | |___>  <| |_) | | | |  __/ | \__/\ | | |  __/ (__|   < 
# \____/_/\_\ .__/|_|_|  \___|  \____/_| |_|\___|\___|_|\_\
#           |_|                                            
#                                                                    
# check_CAData.pl
# ===============================================================
# Author : Isaac Lim (eg8gpb7)
# VerDate: v1.0 / 28SEP2015
# CorrectAddress Dataset Expiration Check
# ===============================================================


# for dev use only
#use lib ('/ds/development/QASL3/dev/common/lib');

use DateTime;
use Date::Calc qw/Delta_Days/;
use Data::Dumper;
use DS::QASL;
use Getopt::Long;
use BLUELITE::Common qw(email);
use DS::DSLOG;

our $PGM = $0;
$PGM =~ s/.*\///g;


sub Usage() {
  print "\n---------------------------------------\n";
  print "CorrectAddress Dataset Expiration Check :: $PGM\n";
  print "---------------------------------------\n";
  print "Usage 1: $PGM -env <dev|qaqc|prod>\n\n";
  print "Option:\n";
  print "  -email <email_list>\n\n";
  print "note: email list option is comma separated and is required in order to send emails\n";
}

my ($email_list,$env);

if (! @ARGV) {
  Usage;
  exit(1);
}

my $ret = GetOptions(
  'email=s' => \$email_list,
  'env=s' => \$env,
);

if (! $ret) {
  print "\n";
  Usage;
  exit(1);
}

if (! $env) {
  die "Environment type (dev/qaqc/prod) required. please provide -env option.\n";
} elsif (lc $env =~ /^(dev|qaqc|prod)$/) {
  $ENV{LOG_ENV_NAME} = $ENV{ENV_NAME} = $env;
} else {
  die "Could not recognize -env option \"$env\". Use dev/qaqc/prod...\n";
}

#if (! $email_list) {
#  die "Unable to retrieve email list. Not emailing out!";
#}

my $DSLOG = DS::DSLOG->new(
  APP_ID => 'DSMONITOR',
  PROCESS => 'CA_DATA_CHECK',
  LOG_LEVEL => 'INFO',
  MESSAGE => 'Starting Check'
);


my $build_dt;
my ($year, $month, $day);

my $qas_object = DS::QASL->new();
my $build_date = $qas_object->get_build_date()->{BuildDate};

if ($build_date =~ /^\s*(\d{4})(\d{2})(\d{2})\s*$/) {
  ($year, $month, $day) = ($1, $2, $3);
  $build_dt = DateTime->new(year => $year, month => $month, day => $day);
} else {
  die "Build date not in YYYYMMDD format\n";
}

my $today = DateTime->today();
my $expire_dt = $build_dt->clone->add(days => 105);
my $ninety_day_check_dt = $build_dt->clone->add(days => 90);

my @today_arr = ($today->year, $today->month, $today->day);
my @expire_date_arr = ($expire_dt->year, $expire_dt->month, $expire_dt->day);
my $dd = Delta_Days(@today_arr, @expire_date_arr);

my $cmp = DateTime->compare($today, $ninety_day_check_dt);

my $msg;
if ($cmp >= 0) {
  if ( $dd < 0 ) {
    # RED -- EXPIRED!
    $msg = "CA Data is expired! Address validation will not work.";
    $DSLOG->log(EVENT_CODE => 'ERROR', LOG_LEVEL => 'FATAL', MESSAGE => $msg);
  } elsif ( $dd <= 10 ) {
    # RED
    $msg = "CA Data will expire on $expire_date_arr[0]$expire_date_arr[1]$expire_date_arr[2]!";
    $DSLOG->log(EVENT_CODE => 'ERROR', LOG_LEVEL => 'FATAL', MESSAGE => $msg);
  } else {
    # YELLOW
    $msg = "90 days has passed and new CA Data has not been loaded yet. Please check for new dataset...";
    $DSLOG->log(EVENT_CODE => 'WARN', LOG_LEVEL => 'WARN', MESSAGE => $msg);
  }
  if ($email_list && $msg) {
    BLUELITE::Common::email(
    to => $email_list,
    subject => "CorrectAddress Data Expiration (generated from $env)",
    message => $msg,
    );
  }
} else {
  $DSLOG->log(EVENT_CODE => 'OK', LOG_LEVEL => 'INFO', MESSAGE => 'CorrectAddress Data is OK');
}

