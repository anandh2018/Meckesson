#!/bin/bash
# William Hampton / sdthgy6 / 24SEP2024
# Checks for delivery of the IQVIA FILE (weekly)


# This command name
export CMD=${0}

# Define the incoming, processed and failed dirs
export INCOMING_DIR=/ds/incomig/prescriber
export PROCESSED_DIR=/ds/incoming/prescriber/.processed
export FAILED_DIR=/ds/incoming/prescriber/.failed

# Check for file once a week
export OM404780_FILE=`find /ds/incoming/prescriber -type f -name 'OM404780*.zip' -mtime -7 -exec basename {} \;`
export OM404780_COUNT=`find /ds/incoming/prescriber -type f -name 'OM404780*.zip' -mtime -7 -exec basename {} \; | wc -l`

# Check if file has been processed
if [ $OM404780_COUNT -ge 1 ];
 then
  perl -we 'use DS::DSLOG; my $log_obj = DS::DSLOG->new(
              APP_ID      => q{PSCBR},
              PROCESS     => "IQVIA_FILE_CHECK",
              EVENT_CODE  => q{SUCCESS},
              LOG_LEVEL   => q{INFO},
              CMD_NAME    => $ENV{CMD},
              MESSAGE     => "Data Services received " . $ENV{OM404780_FILE} . " file for this week.");
    exit 0;'
  #echo "Data Services received an IQVIA file for this week." | mailx -s "IQVIA file check" william.hampton@McKesson.com
 exit 0


# Check to see if the IQVIA file in the incoming directory
elif [ -e  ${INCOMING_DIR}/${OM404780_FILE} ]
 then
  perl -we 'use DS::DSLOG; my $log_obj = DS::DSLOG->new(
              APP_ID      => q{PSCBR},
              PROCESS     => "IQVIA_FILE_CHECK",
              EVENT_CODE  => q{SUCCESS},
              LOG_LEVEL   => q{INFO},
              CMD_NAME    => $ENV{CMD},
              MESSAGE     => "The " . $ENV{OM404780_FILE} . " file is currently in the incoming folder.");
    exit 0;'
#  echo "IQVIA file is in incoming directory" | mailx -s "IQVIA file check" william.hampton@McKesson.com
 exit 0




# Check to see if the IQVIA file in the failed directory
elif [ -e  ${FAILED_DIR}/${OM404780_FILE} ]
 then
  perl -we 'use DS::DSLOG; my $log_obj = DS::DSLOG->new(
              APP_ID      => q{PSCBR},
              PROCESS     => "IQVIA_FILE_CHECK",
              EVENT_CODE  => q{ERROR},
              LOG_LEVEL   => q{ERROR},
              CMD_NAME    => $ENV{CMD},
              MESSAGE     => ""  . $ENV{OM404780_FILE} . " file is in the failed directory.");
    exit 0;'
  #echo "IQVIA file is in the failed directory." | mailx -s "IQVIA file check" william.hampton@McKesson.com
 exit 0
else
  perl -we 'use Env; use DS::DSLOG; my $log_obj = DS::DSLOG->new(
              APP_ID      => q{PSCBR},
              PROCESS     => "IQVIA_FILE_CHECK",
              EVENT_CODE  => q{ERROR},
              LOG_LEVEL   => q{ERROR},
              CMD_NAME    => $ENV{CMD},
              MESSAGE     => "Data Servies has not received an "  . $ENV{OM404780_FILE} . " this week.");
    exit 0;'
  echo "Data Services has not received an IQVIA file for last month." | mailx -s "IQVIA file check (ERROR)" DataServicesNotification@McKesson.com
  exit 1
fi

