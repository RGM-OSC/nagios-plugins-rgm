#!/bin/bash

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_pix_vpn_session.sh
        -C Community
        -H Host target
	-w Warning
	-c Critical"
exit 2
}

COUNTCRITICAL="0"
COUNTWARNING="0"
OUTPUT="0"
WARNING="1000"
CRITICAL="1000"

if [ "${4}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
done

VPNSessions="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET .1.3.6.1.4.1.9.9.392.1.3.38 | cut -d' ' -f4`"
if [ "$VPNSessions" -gt "$WARNING" ]; then
	if [ "$VPNSessions" -gt "$CRITICAL" ]; then
		OUTPUT="Critical, VPN sessions : $VPNSessions"
		COUNTCRITICAL=1
	else  
		OUTPUT="Warning, VPN sessions : $VPNSessions" 
		COUNTWARNING=1
	fi
else
	OUTPUT="Ok, VPN sessions : $VPNSessions"
fi
 
PERF="VPN_Sessions=$VPNSessions;;;"


echo -n "$OUTPUT" | tr ',' ' '

if [ -n "$PERF" ]; then
        echo " | $PERF"
fi

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0
