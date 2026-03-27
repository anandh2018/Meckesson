#!/usr/bin/bash

#Author: William Hampton

#Checks that the rxbc_mrdd_delta_extract.pl is extracting current days worth of data.

if [ $(find /ds/env/prod/RXBC/common/log -name "mrdd_delta*" -mtime 0.1 -exec grep -iP 'starting to process post-date' {} \; | wc -l) -gt 0 ]; then
    echo "Yesterday's post-date data has been processed for the MRDD Delta Load"  | mailx -s "MRDD Delta Load Data Check" william.hampton@McKesson.com
else 
    echo "Yesterdays's post-date data has not been processed for the MRDD Delta Load" | mailx -s "MRDD Delta Load Data Check" DataServicesNotification@McKesson.com
fi   
