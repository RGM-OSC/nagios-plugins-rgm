#!/bin/bash
# Verify the performance of Nagios Active Check in percentual
# Version 1.0
# Ver 1.1 Added output for Performance Data 
# Written By Gatti Davide - davidegatti@hotmail.com

NAGIOSTAT=/srv/eyesofnetwork/nagios/bin/nagiostats # <-- Insert here the full path of nagiostat binary

###############################################################################################
# Script
###############################################################################################

if [ $# -ne 3 ]; then
echo "Usage: $0 <m|f|q|h> <warning threshold> <critical threshold>"
echo ""
echo "m: percent of Services Actively Checked in the last 1 minute"
echo "f: percent of Services Actively Checked in the last 5 minutes"
echo "q: percent of Services Actively Checked in the last 15 minutes"
echo "h: percent of Services Actively Checked in the last 60 minutes"
        exit 1
fi

if [ $2 -gt $3 ]; then
        echo "Critical threshold must be greather or equal than Warning"
        exit 1
fi

if [ ! -f "$NAGIOSTAT" ]; then
        echo  "Cannot find $NAGIOSTAT, verify the nagiostats file position"
        exit 1
fi

NAGVERSION=`$NAGIOSTAT|grep "Nagios Stats"|sed 's/Nagios Stats //'|tr -d ' '`
case $NAGVERSION in
        2.*)
TOTSERVICE=`$NAGIOSTAT|grep "Active Service Checks"|awk -F : '{print $2}'|tr -d ' '`
;;
        3.*)
TOTSERVICE=`$NAGIOSTAT|grep "Services Actively Checked"|awk -F : '{print $2}'|tr -d ' '`
;;
        *)
echo "Version of nagiostats not supported"
        exit 1
;;
esac

case $1 in
        m)
ATTCHECK=`$NAGIOSTAT|grep "Active Services Last"|awk -F '/' '{print $4}'|awk -F ':' '{print $2}'|tr -d ' '`
;;
        f)
ATTCHECK=`$NAGIOSTAT|grep "Active Services Last"|awk -F '/' '{print $5}'|tr -d ' '`
;;
        q)
ATTCHECK=`$NAGIOSTAT|grep "Active Services Last"|awk -F '/' '{print $6}'|tr -d ' '`
;;
        h)
ATTCHECK=`$NAGIOSTAT|grep "Active Services Last"|awk -F '/' '{print $7}'|tr -d ' '`
;;
        *)
echo "Usage: $0 <m|f|q|h> <warning threshold> <critical threshold>"
        exit 1
;;
esac

PERCENTUAL=`echo "($ATTCHECK * 100)/$TOTSERVICE"|bc`
PERF="$PERCENTUAL;$2;$3"

if [ $PERCENTUAL -lt $3 ]; then
        if [ $PERCENTUAL -lt $2 ]; then
                echo "Critical - $PERCENTUAL% of services checked |PERC=$PERF"
                exit 2
        else
                echo "Warning - $PERCENTUAL% of services checked |PERC=$PERF"
                exit 1
        fi
else
        echo "Normal - $PERCENTUAL% of services checked |PERC=$PERF"
        exit 0
fi
