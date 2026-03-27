#!/bin/sh

#####################################
# B.Oliver
# 11-30-22
# create_audit_logs.sh
# Will create audit logs for next year
######################################


t_NEXT_YEAR=$(date -d "$THIS_YEAR +1 year" +%Y)

 cd /dsmounts/ds/data_sources/audit_logs/ || exit

 if [ -L "/dsmounts/xfs20/data_sources/audit_logs/""$t_NEXT_YEAR""01" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs20/data_sources/audit_logs/""$t_NEXT_YEAR""01"" DataServicesNotification@mckesson.com 

 else
    ln -s /dsmounts/xfs20/data_sources/audit_logs/"$t_NEXT_YEAR"01
    mkdir /dsmounts/xfs20/data_sources/audit_logs/"$t_NEXT_YEAR"01

fi
 
if [ -L "/dsmounts/xfs21/data_sources/audit_logs/""$t_NEXT_YEAR""02" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs21/data_sources/audit_logs/""$t_NEXT_YEAR""02"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs21/data_sources/audit_logs/"$t_NEXT_YEAR"02
    mkdir /dsmounts/xfs21/data_sources/audit_logs/"$t_NEXT_YEAR"02

fi

if [ -L "/dsmounts/comp01/data_sources/audit_logs/""$t_NEXT_YEAR""03" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp01/data_sources/audit_logs/""$t_NEXT_YEAR""03"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp01/data_sources/audit_logs/"$t_NEXT_YEAR"03
    mkdir /dsmounts/comp01/data_sources/audit_logs/"$t_NEXT_YEAR"03

fi

if [ -L "/dsmounts/comp02/data_sources/audit_logs/""$t_NEXT_YEAR""04" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp02/data_sources/audit_logs/""$t_NEXT_YEAR""04"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp02/data_sources/audit_logs/"$t_NEXT_YEAR"04
    mkdir /dsmounts/comp02/data_sources/audit_logs/"$t_NEXT_YEAR"04

fi

if [ -L "/dsmounts/comp03/data_sources/audit_logs/""$t_NEXT_YEAR""05" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp03/data_sources/audit_logs/""$t_NEXT_YEAR""05"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp03/data_sources/audit_logs/"$t_NEXT_YEAR"05
    mkdir /dsmounts/comp03/data_sources/audit_logs/"$t_NEXT_YEAR"05

fi

if [ -L "/dsmounts/xfs02/data_sources/audit_logs/""$t_NEXT_YEAR""06" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs02/data_sources/audit_logs/""$t_NEXT_YEAR""06"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs02/data_sources/audit_logs/"$t_NEXT_YEAR"06
    mkdir /dsmounts/xfs02/data_sources/audit_logs/"$t_NEXT_YEAR"06

fi

if [ -L "/dsmounts/xfs05/data_sources/audit_logs/""$t_NEXT_YEAR""07" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs05/data_sources/audit_logs/""$t_NEXT_YEAR""07"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs05/data_sources/audit_logs/"$t_NEXT_YEAR"07
    mkdir /dsmounts/xfs05/data_sources/audit_logs/"$t_NEXT_YEAR"07

fi

if [ -L "/dsmounts/xfs06/data_sources/audit_logs/""$t_NEXT_YEAR""08" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs06/data_sources/audit_logs/""$t_NEXT_YEAR""08"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs06/data_sources/audit_logs/"$t_NEXT_YEAR"08
    mkdir /dsmounts/xfs06/data_sources/audit_logs/"$t_NEXT_YEAR"08

fi

if [ -L "/dsmounts/xfs07/data_sources/audit_logs/""$t_NEXT_YEAR""09" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs07/data_sources/audit_logs/""$t_NEXT_YEAR""09"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs07/data_sources/audit_logs/"$t_NEXT_YEAR"09
    mkdir /dsmounts/xfs07/data_sources/audit_logs/"$t_NEXT_YEAR"09

fi

if [ -L "/dsmounts/xfs08/data_sources/audit_logs/""$t_NEXT_YEAR""10" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs08/data_sources/audit_logs/""$t_NEXT_YEAR""10"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs08/data_sources/audit_logs/"$t_NEXT_YEAR"10
    mkdir /dsmounts/xfs08/data_sources/audit_logs/"$t_NEXT_YEAR"10

fi

if [ -L "/dsmounts/xfs09/data_sources/audit_logs/""$t_NEXT_YEAR""11" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs09/data_sources/audit_logs/""$t_NEXT_YEAR""11"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs09/data_sources/audit_logs/"$t_NEXT_YEAR"11
    mkdir /dsmounts/xfs09/data_sources/audit_logs/"$t_NEXT_YEAR"11

fi

if [ -L "/dsmounts/xfs10/data_sources/audit_logs/""$t_NEXT_YEAR""12" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs10/data_sources/audit_logs/""$t_NEXT_YEAR""12"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs10/data_sources/audit_logs/"$t_NEXT_YEAR"12
    mkdir /dsmounts/xfs10/data_sources/audit_logs/"$t_NEXT_YEAR"12

fi


 cd /dsmounts/ds/data_sources/mms_index/ || exit

 if [ -L "/dsmounts/xfs20/data_sources/mms/""$t_NEXT_YEAR""01" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs20/data_sources/mms/""$t_NEXT_YEAR""01"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs20/data_sources/mms/"$t_NEXT_YEAR"01
    mkdir /dsmounts/xfs20/data_sources/mms/"$t_NEXT_YEAR"01

fi

if [ -L "/dsmounts/xfs21/data_sources/mms/""$t_NEXT_YEAR""02" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs21/data_sources/mms/""$t_NEXT_YEAR""02"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs21/data_sources/mms/"$t_NEXT_YEAR"02
    mkdir /dsmounts/xfs21/data_sources/mms/"$t_NEXT_YEAR"02

fi

if [ -L "/dsmounts/comp01/data_sources/mms/""$t_NEXT_YEAR""03" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp01/data_sources/mms/""$t_NEXT_YEAR""03"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp01/data_sources/mms/"$t_NEXT_YEAR"03
    mkdir /dsmounts/comp01/data_sources/mms/"$t_NEXT_YEAR"03

fi

if [ -L "/dsmounts/comp02/data_sources/mms/""$t_NEXT_YEAR""04" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp02/data_sources/mms/""$t_NEXT_YEAR""04"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp02/data_sources/mms/"$t_NEXT_YEAR"04
    mkdir /dsmounts/comp02/data_sources/mms/"$t_NEXT_YEAR"04

fi

 if [ -L "/dsmounts/comp03/data_sources/mms/""$t_NEXT_YEAR""05" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/comp03/data_sources/mms/""$t_NEXT_YEAR""05"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/comp03/data_sources/mms/"$t_NEXT_YEAR"05
    mkdir /dsmounts/comp03/data_sources/mms/"$t_NEXT_YEAR"05

fi

if [ -L "/dsmounts/xfs02/data_sources/mms/""$t_NEXT_YEAR""06" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs02/data_sources/mms/""$t_NEXT_YEAR""06"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs02/data_sources/mms/"$t_NEXT_YEAR"06
    mkdir /dsmounts/xfs02/data_sources/mms/"$t_NEXT_YEAR"06

fi

if [ -L "/dsmounts/xfs05/data_sources/mms/""$t_NEXT_YEAR""07" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs05/data_sources/mms/""$t_NEXT_YEAR""07"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs05/data_sources/mms/"$t_NEXT_YEAR"07
    mkdir /dsmounts/xfs05/data_sources/mms/"$t_NEXT_YEAR"07

fi

if [ -L "/dsmounts/xfs06/data_sources/mms/""$t_NEXT_YEAR""08" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs06/data_sources/mms/""$t_NEXT_YEAR""08"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs06/data_sources/mms/"$t_NEXT_YEAR"08
    mkdir /dsmounts/xfs06/data_sources/mms/"$t_NEXT_YEAR"08

fi

if [ -L "/dsmounts/xfs07/data_sources/mms/""$t_NEXT_YEAR""09" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs07/data_sources/mms/""$t_NEXT_YEAR""09"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs07/data_sources/mms/"$t_NEXT_YEAR"09
    mkdir /dsmounts/xfs07/data_sources/mms/"$t_NEXT_YEAR"09

fi

if [ -L "/dsmounts/xfs08/data_sources/mms/""$t_NEXT_YEAR""10" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs08/data_sources/mms/""$t_NEXT_YEAR""10"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs08/data_sources/mms/"$t_NEXT_YEAR"10
    mkdir /dsmounts/xfs08/data_sources/mms/"$t_NEXT_YEAR"10

fi

if [ -L "/dsmounts/xfs09/data_sources/mms/""$t_NEXT_YEAR""11" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs09/data_sources/mms/""$t_NEXT_YEAR""11"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs09/data_sources/mms/"$t_NEXT_YEAR"11
    mkdir /dsmounts/xfs09/data_sources/mms/"$t_NEXT_YEAR"11

fi

if [ -L "/dsmounts/xfs10/data_sources/mms/""$t_NEXT_YEAR""12" ];then

         echo -e "Audit directory already exists, please check" |  mail -s "Audit directory already exists "/dsmounts/xfs10/data_sources/mms/""$t_NEXT_YEAR""12"" DataServicesNotification@mckesson.com

 else
    ln -s /dsmounts/xfs10/data_sources/mms/"$t_NEXT_YEAR"12
    mkdir /dsmounts/xfs10/data_sources/mms/"$t_NEXT_YEAR"12

fi


echo -e "The below Audit directories were created, please verify and delete necessary data from previous years directories:\n\n
 /dsmounts/ds/data_sources/audit_logs/"$t_NEXT_YEAR"01-"$t_NEXT_YEAR"12\n/dsmounts/ds/data_sources/mms_index/"$t_NEXT_YEAR"01-"$t_NEXT_YEAR"12"  | 
 mail -s "Audit directories created for ""$t_NEXT_YEAR""" DataServicesNotification@mckesson.com
