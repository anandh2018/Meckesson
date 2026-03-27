#!/bin/bash

# ===============================================================
#    ___  _     __    __     _     __
#   / __\/_\   / / /\ \ \___| |__ / _\_   _____
#  / /  //_\\  \ \/  \/ / _ \ '_ \\ \\ \ / / __|
# / /__/  _  \  \  /\  /  __/ |_) |\ \\ V / (__
# \____|_/ \_/   \/  \/ \___|_.__/\__/ \_/ \___|
#
#                     _ _               __    __           _             
#   /\/\   ___  _ __ (_) |_ ___  _ __  / / /\ \ \___  _ __| | _____ _ __ 
#  /    \ / _ \| '_ \| | __/ _ \| '__| \ \/  \/ / _ \| '__| |/ / _ \ '__|
# / /\/\ \ (_) | | | | | || (_) | |     \  /\  / (_) | |  |   <  __/ |   
# \/    \/\___/|_| |_|_|\__\___/|_|      \/  \/ \___/|_|  |_|\_\___|_|   
#
#                                                                       
# check_CAWS.sh 
# ===============================================================
# Author : Isaac Lim (eg8gpb7)
# VerDate: v1.0 / 15SEP2015
# Correct Address WebService Monitor Worker
# ===============================================================

# ===============================================================
#                      Variable Declarations
# ===============================================================

CA1_PROTO="http"
CA1_HOST="dsgrid01b.ndchealth.com"
CA1_PORT="13080"
CA1_CONTEXT="CorrectAddressWS"
CA1_URL="wsStatus.jsp"

CA2_PROTO="http"
CA2_HOST="dsgrid02b.ndchealth.com"
CA2_PORT="13080"
CA2_CONTEXT="CorrectAddressWS"
CA2_URL="wsStatus.jsp"

CA3_PROTO="http"
CA3_HOST="dsgrid03b.ndchealth.com"
CA3_PORT="13080"
CA3_CONTEXT="CorrectAddressWS"
CA3_URL="wsStatus.jsp"

CA4_PROTO="http"
CA4_HOST="dsgrid04b.ndchealth.com"
CA4_PORT="13080"
CA4_CONTEXT="CorrectAddressWS"
CA4_URL="wsStatus.jsp"

CA5_PROTO="http"
CA5_HOST="dsgrid05b.ndchealth.com"
CA5_PORT="13080"
CA5_CONTEXT="CorrectAddressWS"
CA5_URL="wsStatus.jsp"

CA6_PROTO="http"
CA6_HOST="dsgrid06b.ndchealth.com"
CA6_PORT="13080"
CA6_CONTEXT="CorrectAddressWS"
CA6_URL="wsStatus.jsp"

LB_PROTO="http"
LB_HOST="dsgrid02a.ndchealth.com"
LB_PORT="13080"
LB_CONTEXT="CorrectAddressWS"
LB_URL="wsStatus.jsp"

source .bash_profile 1> /dev/null 2>&1


Usage() {
  echo "CorrectAddress WebService Monitor - invalid target/option \"${1}\""
  echo "Usage:  $0  CA1|CA2|CA3|CA4|CA5|CA6|LB  [-s]"
  echo "  CA1 - (node1) dsgrid01b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  CA2 - (node2) dsgrid02b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  CA3 - (node3) dsgrid03b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  CA4 - (node4) dsgrid04b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  CA5 - (node5) dsgrid05b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  CA6 - (node6) dsgrid06b.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  LB  - (loadbalancer) dsgrid02a.ndchealth.com:13080/CorrectAddressWS/wsStatus.jsp"
  echo "  -s  - silent mode"
}

# Parse the command parameters
if [ "A${1}" == "A" ]
then
  Usage ${1}
  exit 6
elif [ "${1}" == "CA1" ]
then
  PROTO=${CA1_PROTO}
  HOST=${CA1_HOST}
  PORT=${CA1_PORT}
  CONTEXT=${CA1_CONTEXT}
  URL=${CA1_URL}
elif [ "${1}" == "CA2" ]
then
  PROTO=${CA2_PROTO}
  HOST=${CA2_HOST}
  PORT=${CA2_PORT}
  CONTEXT=${CA2_CONTEXT}
  URL=${CA2_URL}
elif [ "${1}" == "CA3" ]
then
  PROTO=${CA3_PROTO}
  HOST=${CA3_HOST}
  PORT=${CA3_PORT}
  CONTEXT=${CA3_CONTEXT}
  URL=${CA3_URL}
elif [ "${1}" == "CA4" ]
then
  PROTO=${CA4_PROTO}
  HOST=${CA4_HOST}
  PORT=${CA4_PORT}
  CONTEXT=${CA4_CONTEXT}
  URL=${CA4_URL}
elif [ "${1}" == "CA5" ]
then
  PROTO=${CA5_PROTO}
  HOST=${CA5_HOST}
  PORT=${CA5_PORT}
  CONTEXT=${CA5_CONTEXT}
  URL=${CA5_URL}
elif [ "${1}" == "CA6" ]
then
  PROTO=${CA6_PROTO}
  HOST=${CA6_HOST}
  PORT=${CA6_PORT}
  CONTEXT=${CA6_CONTEXT}
  URL=${CA6_URL}
elif [ "${1}" == "LB" ]
then
  PROTO=${LB_PROTO}
  HOST=${LB_HOST}
  PORT=${LB_PORT}
  CONTEXT=${LB_CONTEXT}
  URL=${LB_URL}
else
  Usage ${1}
  exit 6
fi

if [ "A${2}" != "A" ]
then
  if [ "${2}" != "-s" ]
  then
    Usage ${2}
    exit 6
  fi
fi

# removes any whitespace/new line/carriage returns
SERVER_STATUS=`curl -s $PROTO://$HOST:$PORT/$CONTEXT/$URL`
SERVER_STATUS="$(echo -e "${SERVER_STATUS}" | tr -d '[[:space:]]')"

if [ "A${SERVER_STATUS}" == "A" ]
then
  if [ "A${2}" == "A" ]
  then
    echo "ERROR! ${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) did not respond at all"
  fi
  exit 2
elif [ "${SERVER_STATUS}" == "0" ]
then
  if [ "A${2}" == "A" ]
  then
    echo "${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) webservice is up"
  fi
  exit 0
elif [ "${SERVER_STATUS}" == "1" ]
then
  if [ "A${2}" == "A" ]
  then
    echo "${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) CorrectAddress Data is out of date, cannot verify any addresses"
  fi
  exit 1
elif [ "${SERVER_STATUS}" == "2" ]
then
  if [ "A${2}" == "A" ]
  then
    echo "${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) webservice is down"
  fi
  exit 2
elif [ "${SERVER_STATUS}" == "3" ]
then
  if [ "A${2}" == "A" ]
  then
    echo "${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) webservice is down, unknown exception"
  fi
  exit 3
else
  if [ "A${2}" == "A" ]
  then
    echo "ERROR! ${1} ($PROTO://$HOST:$PORT/$CONTEXT/$URL) returned invalid response"
    echo "  \"${SERVER_STATUS}\""
  fi
  exit 4
fi

exit 0
