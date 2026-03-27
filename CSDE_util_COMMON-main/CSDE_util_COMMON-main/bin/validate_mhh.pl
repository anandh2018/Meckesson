#!/usr/bin/perl

use strict;
use Socket;
use IO::Socket;
use IO::Select;
use DateTime;

my @servernames = (q{ds16.ndchealth.com:8080},
                   q{ds17.ndchealth.com:8080},
                   q{ds18.ndchealth.com:8080},
                    );

my $script     = q{/ds/common/bin/medrecon};
my $last_name  = q{OTC};
my $first_name = q{SALES};
my $dob        = q{19800212};
my $gender     = q{F};
my $zip_code   = q{28752};

my $today      = DateTime->today();
my $end_date   = $today->ymd(q{});

my $last_month = $today->subtract(days => 30);
my $start_date = $last_month->ymd(q{}); 

#Hard code dates if needed
#$end_date = q{20100524};
#$start_date = q{20100526};

my $servers;
foreach my $servername (@servernames) {
  $servers->{$servername} = undef();

  my $parentfh = undef();
  my $childfh  = undef();

  socketpair ($childfh, $parentfh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "Socketpair creation failed: $!";
  
  $parentfh->autoflush(1);
  $childfh->autoflush(1);

  my $sock = IO::Select->new();
  $sock->add($childfh);
  
  my $pid;
  if ($pid = fork) {
    close $parentfh;
    $servers->{$servername}->{sock} = $sock;
    $servers->{$servername}->{pid}  = $pid;
  } 
  else {
    if (! defined $pid) {
      die qq{Cannot fork: $!};
    }
    $servers = undef();
    my $output = `$script $servername $start_date $end_date $last_name $first_name $dob $gender $zip_code 2>&1`;
    print $parentfh $output;
    close $parentfh;
    exit(0);
  }
}

while (1) {
  my $i = 0;
  foreach my $servername (@servernames) {
    my $line;
    if (exists $servers->{$servername}) {
      $i++;
      if ($servers->{$servername}->{sock}->can_read(0)) {
        foreach my $handle ($servers->{$servername}->{sock}->can_read(0)) {
          recv($handle, $line, 1024 , 0.5);
        }
        $line =~ s/\n//g;
        if ($line =~ m/$servername\|$start_date\|$end_date\|$last_name\|$first_name\|$dob\|$gender\|$zip_code/) {
          my @result_values = split /\|/, $line;
          my $success_flag    = $result_values[9]  || q{0};
          my $error_code      = $result_values[10] || q{?};
          my $elapsed_time    = $result_values[13] || q{?};
          $elapsed_time =~ s/(\.[0-9]{2})[0-9]+$/\1/;
          if ($success_flag) {
            print qq{$servername: Successful Exception:$error_code Time: $elapsed_time\n};
          }
          else {
            print qq{$servername: UNSUCCESSFUL Exception:$error_code Time: $elapsed_time\n};
          }
        }
        else {
          print qq{$servername: UNSUCCESSFUL Error: $line\n};
        }
        #waitpid($servers->{$servername}->{pid});
        #close $servers->{$servername}->{sock};
        delete $servers->{$servername};
      }
    }
  }
  if ($i == 0) {
    last;
  }
}
