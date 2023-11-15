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
      echo "$PROGNAME $RELEASE - Scality cluster check"
      echo ""
      echo "Usage: $PROGNAME -H ScalitySupervisor -u username -p password [ -D ] | [-h | --help] | [-v | --version]"
      echo ""
      echo "    -h  Show this page"
      echo "    -v  Version"
      echo "    -D  Debug"
      echo "    -H  Hostname of scality supervisor node"
      echo "    -u  Monitoring user (Should be low privilege RO account)"
      echo "    -p  password"
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
if [ $# -lt 6 ]; then
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

OUTPUT="$(curl --max-time 7 -s -u "${USERNAME}:${PASSWORD}" -X GET "http://${HOSTNAME}/api/v0.1/s3_clusters/")"
OUTPUT_FILTERED="$(echo $OUTPUT | cut -c -10 | head -1)"
RETURNCODE="$(echo $?)"


mi_debug $OUTPUT
mi_debug $RETURNCODE

if [ "${OUTPUT_FILTERED}" != "{\"_items\":" ];then
  echo "Le hostname $HOSTNAME ne semble pas être un cluster Scality"
	exit 3
fi

OUTPUT="$(curl --max-time 7 -s -u "${USERNAME}:${PASSWORD}" -X GET "http://${HOSTNAME}/api/v0.1/s3_clusters/")"
RETURNCODE="$(echo $?)"

mi_debug $OUTPUT
mi_debug $RETURNCODE

OUTPUT_MAIN="$(echo $OUTPUT | jq ' ._items[] | "cluster:\(.name), status:\(.cluster_health)"')"
OUTPUT_STATUS="$(echo $OUTPUT | jq -r ' ._items[] | .cluster_health')"
OUTPUT_PERF=""

OUTPUT_HEADER="OK"
EXIT_STATUS=$STATE_OK

if [ $RETURNCODE -gt 0 ]; then
  OUTPUT_HEADER="UNKNOWN"
  OUTPUT_MAIN="Impossible de contacter $HOSTNAME."
  EXIT_STATUS=$STATE_UNKNOWN
fi

if [ "$OUTPUT_STATUS" != "NOMINAL" ];then
  OUTPUT_HEADER="CRITICAL"
  EXIT_STATUS=$STATE_CRITICAL
fi


if [ -n "$OUTPUT_PERF" ]; then
  echo "$OUTPUT_HEADER: $OUTPUT_MAIN | $OUTPUT_PERF"
else
  echo "$OUTPUT_HEADER: $OUTPUT_MAIN"
fi

exit $EXIT_STATUS
