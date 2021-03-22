#!/bin/bash
# script :  check_lefthand_cluster_vol.sh
# version : 1.1
# Comment : Script voor Nagios to monitor the used space on HP Lefthand Cluster
# Usage :   - Nagiso Command.cfg:
#           $USER1$/check_lefthand_cluster_vol.sh -H $HOSTADDRESS$ $ARG1$
#           - Nagios Host.cfg:
#           check_lefthand_cluster_vol!-C <SNMP Community> -w 85 -c 95
#           - For Free space:
#           check_snmp!-C <SNMP Community> -P 2c -o 1.3.6.1.4.1.9804.3.1.1.2.12.48.1.17.1 -u kb-Free

if [ "$1" = "-H" ] && [ "$3" = "-C" ] && [ "$5" = "-w" ] && [ "$6" -gt "0" ] && [ "$7" = "-c" ] && [ "$8" -gt "$6" ]; then
  host="$2"
  community="$4"
  let beforewarn="$6"-1
  warn="$6"
  let beforecrit="$8"-1
  crit="$8"

  usedspace=`/srv/eyesofnetwork/nagios/plugins/check_snmp -H "$host" -c "$community" -P 2c -o 1.3.6.1.4.1.9804.3.1.1.2.12.48.1.31.1 | awk -F" " '{print $4}'`
  totalspace=`/srv/eyesofnetwork/nagios/plugins/check_snmp -H "$host" -c "$community" -P 2c -o 1.3.6.1.4.1.9804.3.1.1.2.12.48.1.29.1 | awk -F" " '{print $4}'`

  let percent="$totalspace"/100
  let usedpercent="$usedspace"/$percent

  case "$usedpercent" in
    [0-"$beforewarn"]*)
    echo "OK - $usedpercent % of disk space used. | usedspace=$usedspace usedpercent=$usedpercent%;$6;$8"
    exit 0
    ;;
    ["$warn"-"$beforecrit"]*)
    echo "WARNING - $usedpercent % of disk space used. | usedspace=$usedspace usedpercent=$usedpercent%;$6;$8"
    exit 1
    ;;
    ["$crit"-100]*)
    echo "CRITICAL - $usedpercent % of disk space used. | usedspace=$usedspace usedpercent=$usedpercent%;$6;$8"
    exit 2
    ;;
    *)
    echo "UNKNOWN - $usedpercent % of disk space used. | usedspace=$usedspace usedpercent=$usedpercent%;$6;$8"
    exit 3
    ;;
  esac
else
  echo "check_lefthand_cluster_vol.sh v1.0"
  echo ""
  echo "Usage:"
  echo "check_lefthand_cluster_vol.sh -H <hostIP> -C <SNMP Community> -w <warnlevel> -c <critlevel>"
  echo ""
  echo "warnlevel and critlevel is percentage value without %"
  echo ""
  echo "2014 Rink Geervliet"
  echo "Modified for EON and pnp 2015 Michael Aubertin"
  exit
fi
