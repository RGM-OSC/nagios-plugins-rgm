#!/bin/bash

STATE=99

PRIMARY=".1.3.6.1.4.1.9.9.147.1.2.1.1.1.3.6"
SECONDARY=".1.3.6.1.4.1.9.9.147.1.2.1.1.1.3.7"

ACTIVEVALUE=9
STANDBYVALUE=10

COUNTWARNING=0
COUNTCRITICAL=0

LocationPrimary=""
LocationSecondary=""

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_pix_failover_2.sh
        -C Community
        -H Host Address
	-P Primary Location
	-S Secondary Location"
exit 2
}

if [ "${4}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-P"`" ]; then LocationPrimary="`echo ${i} | cut -c 3-`"; if [ ! -n ${LocationPrimary} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-S"`" ]; then LocationSecondary="`echo ${i} | cut -c 3-`"; if [ ! -n ${LocationSecondary} ]; then usage;fi;fi
done

if [ $COMMUNITY == NULL ]; then
	usage
fi

if [ $HOSTTARGET == NULL ]; then
	usage
fi

PrimaryValueOID=`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $PRIMARY | cut -d' ' -f4-`
	### Debug Test
	#PrimaryValueOID=11
SecondaryValueOID=`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $SECONDARY | cut -d' ' -f4-`
	### Debug Test
	#SecondaryValueOID=11

if [ $PrimaryValueOID == ${ACTIVEVALUE} ]; then
	if [ $SecondaryValueOID == ${STANDBYVALUE} ]; then
		OUTPUT="OK: Primary $LocationPrimary: Active, Secondary $LocationSecondary: Passive"
	else
		OUTPUT="Warning: Primary $LocationPrimary: Active, Secondary $LocationSecondary: Problem"
		COUNTWARNING=1
	fi
fi

if [ $PrimaryValueOID == ${STANDBYVALUE} ]; then
	if [ $SecondaryValueOID == ${ACTIVEVALUE} ]; then
		OUTPUT="OK: Primary $LocationPrimary: Passive, Secondary $LocationSecondary: Active"
	else
		if [ $SecondaryValueOID == 10 ]; then
			OUTPUT="Critical: Primary $LocationPrimary: Passive, Secondary $LocationSecondary: Passive"
			COUNTCRITICAL=2
		else
			OUTPUT="Critical: Primary $LocationPrimary: Passive, Secondary $LocationSecondary: Problem"
			COUNTCRITICAL=2
		fi
	fi
fi

if [ $PrimaryValueOID != ${ACTIVEVALUE} ] && [ $PrimaryValueOID != ${STANDBYVALUE} ]; then
	if [ $SecondaryValueOID != ${ACTIVEVALUE} ]; then
		if [ $SecondaryValueOID != ${STANDBYVALUE} ]; then
			OUTPUT="Critical: Primary $LocationPrimary: Problem, Secondary $LocationSecondary: Problem"
			COUNTCRITICAL=2
		else
			OUTPUT="Critical: Primary $LocationPrimary: Problem, Secondary $LocationSecondary: Passive"
			COUNTCRITICAL=2
		fi
	else 
			OUTPUT="Warning: Primary $LocationPrimary: Problem, Secondary $LocationSecondary: Active"
			COUNTWARNING=1
	fi
fi

echo -n "$OUTPUT" | tr ',' ' '

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

