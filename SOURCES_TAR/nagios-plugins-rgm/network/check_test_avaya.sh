#!/bin/bash

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_ConnectedAP.sh
       -H Hostname to check
	-C Community SNMP
        -w Warning (mens maximun number of ConnectedAP) 
        -c Critical (means minimum number of ConnectedAP)"
exit2
}


if [ "${8}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-control-wifi-check_5/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-control-wifi-check_5/${HOSTTARGET}; fi
TMPDIR="/tmp/tmp-control-wifi-check_5/${HOSTTARGET}"


snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.45.7.7.1.3.1.2 | sed -e 's: "$:":g' && snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.45.7.2.1.5.1.2 | sed -e 's: "$:":g' | sort -k2 > $TMPDIR/snmpwalk_out.txt 




#snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.45.7.7.1.3.1.2 | awk 'NR == 1 {print;}' > $TMPDIR/snmpwalk_out.txt
#snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.45.7.7.1.3.1.2 | sed -e 's: "$:":g' | print $1; | snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -O 0qv .1.3.6.1.4.1.45.7.2.1.5.1.2 | print $2; > $TMPDIR/snmpwalk_out.txt


if [ "`cat $TMPDIR/snmpwalk_out.txt | head -1`" = "" ]; then 
	echo "CRITICAL: Interogation Controleur WIFI impossible."
#	rm -rf ${TMPDIR}
	exit 2
fi

#LOAD="`cat $TMPDIR/snmp_out.txt | grep "${CONNECTEDAP}" | wc -l`"
#LOAD="`cat $TMPDIR/snmp_out.txt | grep "${CONNECTEDAP}" | sed -e 's:"::g' | tr '\n' ';'`"
LOAD="`cat $TMPDIR/snmpwalk_out.txt`"



if [ $LOAD -lt $CRITICAL ]; then
	echo "CRITICAL: less than $CRITICAL Bytes Received:$LOAD  :$LIST"
#	rm -rf ${TMPDIR}	
	exit 2
fi
if [ $LOAD -gt $WARNING ]; then
	echo "WARNING: More then $WARNING Bytes Received: $LOAD   :$LIST"
#	rm -rf ${TMPDIR}
	exit 1
fi
echo "OK: number of $CONNECTEDAP Bytes Received.  :$LOAD"
#rm -rf ${TMPDIR}
exit 0


