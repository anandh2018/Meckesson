#!/bin/bash

mrun /ds/production/medhistory-empi/apache2/i386-linux-thread-multi/bin/apache_restart.sh -- ds16 ds17 ds18 ds19 ds20 ds21
mrun /ds/production/medhistory/apache2/i386-linux-thread-multi/bin/apache_restart.sh -- ds16 ds17 ds18 ds19 ds20 ds21
