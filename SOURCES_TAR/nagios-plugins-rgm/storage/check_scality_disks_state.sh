#!/bin/bash
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'
# /****************************************************************/
# /* Copyright (C) 2019-2026 SCC France. All rights reserved.     */
# /* Propriété intellectuelle SCC France. Tout droits réservés.   */
# /****************************************************************/
# /*                                                              */
# /* Ce document est une propriété exclusive de SCC France        */
# /* Ce document est considéré comme propriétaire et confidentiel */
# /*                                                              */
# /****************************************************************/
# /*                                                              */
# /* This document is the property of SCC France                  */
# /* This document is considered proprietary and confidential     */
# /*                                                              */
# /****************************************************************/
# /*                                                              */
# /* This document may not be reproduced or transmitted in any    */
# /* form, in whole or in part, without the express written       */
# /* permission of SCC France                                     */
# /*                                                              */
# /****************************************************************/
# /*                                                              */
# /* Ce document ne peut pas etre reproduit ou transmit sous      */
# /* aucune forme ni d'aucune manière en partie, par extrait ou   */
# /* intégralement sans l'accord écrit préalable de SCC France.   */
# /*                                                              */
# /****************************************************************/

PROGNAME=$(basename $0)
RELEASE="Revision 1.0"
AUTHOR="Michael Aubertin (maubertin@fr.scc.com)"
DEBUG=0
OUT_LOG="/dev/null"


USERAGENT="user-agent: Monitoring RGM"

LANG='fr_FR.UTF-8'
FONT_ALARM="\e[1;37;4;41m"
FONT_NORMAL="\e[0m"
FONT_INFO="\e[36m"

MSGOK="\e[92m  [OK]\e[0m"
MSGERR="\e[91m  [FAILED]\e[0m"
MSGSKP="\e[1;34m  [SKIPPED]\e[0m"
MSGINFO="\e[1;33m  [INFO]\e[0m"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3


# Functions plugin usage
function mi_debug() {
    [[ "${DEBUG}" == "1" ]] && echo -e "[DEBUG]: $*"
}

print_release() {
    echo "$RELEASE $AUTHOR"
}


print_usage() {
      echo ""
      echo "$PROGNAME $RELEASE - Scality disks check"
      echo ""
      echo "Usage: $PROGNAME -H ScalitySupervisor -u username -p password [ -D ] | [-h | --help] | [-v | --version]"
      echo ""
      echo "    -h  Show this page"
      echo "    -v  Version"
      echo "    -D  Debug"
      echo "    -H  Hostname of scality supervisor node"
      echo "    -u  Monitoring user (Should be low privilege RO account)"
      echo "    -p  password"
      echo "    -w  Warning minimum GB available per disks"
      echo "    -c  Critical minimum GB available per disks"
      echo ""
}

print_help() {
                print_usage
        echo ""
        print_release $PROGNAME $RELEASE
        echo ""
        exit 0
}


#     #    #      ###   #     #
##   ##   # #      #    ##    #
# # # #  #   #     #    # #   #
#  #  # #     #    #    #  #  #
#     # #######    #    #   # #
#     # #     #    #    #    ##
#     # #     #   ###   #     #

# Make sure the correct number of command line arguments have been supplied
if [ $# -lt 10 ]; then
	print_usage
	exit $STATE_UNKNOWN
fi

ARGNUM="$#"

# Grab the command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            exit $STATE_OK
            ;;
        -v | --version)
            print_release
            exit $STATE_OK
            ;;
        -D)
            echo "DEBUG DETECTED"
            DEBUG=1
            ;;
        -H)
            shift
            HOSTNAME="$1"
            ;;
        -u)
            shift
            USERNAME="$1"
            ;;
        -p)
            shift
            PASSWORD="$1"
            ;;
        -w)
            shift
            WARNING="$1"
            ;;
        -c)
            shift
            CRITICAL="$1"
            ;;

        *)  echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
        esac
shift
done

if [ $DEBUG -gt 0 ]; then
  echo "DEBUG: $DEBUG"
fi


OUTPUT="$(curl --max-time 7 -s -u "${USERNAME}:${PASSWORD}" -X GET "http://${HOSTNAME}/api/v0.1/disks/")"
RETURNCODE="$(echo $?)"
OUTPUT_FILTERED="$(echo $OUTPUT | cut -c -10 | head -1)"

mi_debug $OUTPUT
mi_debug $RETURNCODE

if [ "${OUTPUT_FILTERED}" != "{\"_items\":" ];then
  echo "Le hostname $HOSTNAME ne semble pas être un cluster Scality"
	exit 3
fi

DisksList="$(echo $OUTPUT | jq -r '._items[] | .id')"
mi_debug "Nodelist: $DisksList"

if [ ! -n "$(echo ${DisksList} | grep -v null)" ];then
  echo "Le hostname $HOSTNAME ne semble pas présenté de disks !!!"
    exit 3
fi

OUTPUT_HEADER="OK"
EXIT_STATUS=$STATE_OK
OUTPUT_MAIN=""
OUTPUT_PERF=""


for disk in $DisksList; do
  DISKINFO="$(echo $OUTPUT | jq -r --arg disk_id "$disk" '._items[] | select(.id == $disk_id) | "name: \(.name), ring: \(.rings | join(";")), state: \(.state | join(";")) ,status: \(.status), diskspace_available: \(.diskspace_available)"')"
  mi_debug $OUTPUT

  DISKNAME="$(echo "${DISKINFO}" | sed "s: ::g" | cut -d',' -f1 | cut -d':' -f2)"
  DISKRING="$(echo "${DISKINFO}" | sed "s: ::g" | cut -d',' -f2 | cut -d':' -f2)"
  DISKSTATE="$(echo "${DISKINFO}" | sed "s: ::g" | cut -d',' -f3 | cut -d':' -f2)"
  DISKSTATUS="$(echo "${DISKINFO}" | sed "s: ::g" | cut -d',' -f4 | cut -d':' -f2)"
  DISKAVAILBYTES="$(echo "${DISKINFO}" | sed "s: ::g" | cut -d',' -f5 | cut -d':' -f2)"
  DISKAVAILGB="$(expr $DISKAVAILBYTES / 1000000000)"

  if [ "${DISKSTATUS}" != "OK" ]; then
    OUTPUT_HEADER="CRITICAL"
    EXIT_STATUS=$STATE_CRITICAL
  fi

  if [ -n "$OUTPUT_MAIN" ]; then
    OUTPUT_MAIN="$OUTPUT_MAIN \\n $DISKNAME ($DISKRING): ($DISKSTATE) $DISKSTATUS Available: $DISKAVAILGB GB"
  else
    OUTPUT_MAIN="$DISKNAME ($DISKRING): ($DISKSTATE) $DISKSTATUS Available: $DISKAVAILGB GB"
  fi

  if [ -n "$OUTPUT_PERF" ]; then
    OUTPUT_PERF="$OUTPUT_PERF \\n$DISKNAME=${DISKAVAILGB}GB;$WARNING;$CRITICAL"
  else
    OUTPUT_PERF="| $DISKNAME=${DISKAVAILGB}GB;$WARNING;$CRITICAL"
  fi

  if [ ! $OUTPUT_HEADER == "CRITICAL" ]; then
    if [ $DISKAVAILGB -lt $WARNING ]; then
        if [ $DISKAVAILGB -lt $CRITICAL ]; then
         OUTPUT_HEADER="CRITICAL"
         EXIT_STATUS=$STATE_CRITICAL
        else
         OUTPUT_HEADER="WARNING"
         EXIT_STATUS=$STATE_WARNING
        fi
    fi
  fi

done

mi_debug $OUTPUT_HEADER
mi_debug $EXIT_STATUS

if [ -n "$OUTPUT_PERF" ]; then
    printf "$OUTPUT_HEADER:$OUTPUT_MAIN | $OUTPUT_PERF \\n"
else
    printf "$OUTPUT_HEADER:$OUTPUT_MAIN \\n"
fi


exit $EXIT_STATUS
