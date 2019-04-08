#!/bin/bash

# Name: check_hyperv-health
# Checks the health status of your Hyper-V Virtual Machines
# Author: Jurie Botha - jurieb(at)gmail(dot)com

HOST=$1
PSW=$2
CHNT="/srv/eyesofnetwork/nagios/plugins/check_nt"
OKVMS=`$CHNT -H $HOST -s $PSW -p 12489 -v COUNTER -l "\Hyper-V Virtual Machine Health Summary\Health OK"`
CRITVMS=`$CHNT -H $HOST -p 12489 -v COUNTER -l "\\Hyper-V Virtual Machine Health Summary\\Health Critical"`
OKNUM="$OKVMS"
CRITNUM="$CRITVMS"
TOTAL=$(($OKNUM+$CRITNUM))
CMDERR=`$CHNT -H $1 -p 12489 -v COUNTER -l "\\Hyper-V Virtual Machine Health Summary\\Health OK" |grep -i -o "could not fetch information from server"`


if [ "$CMDERR" == "could not fetch information from server" ] ; then
        OUTPUT="${OUTPUT}STATUS UNKNOWN - Unable to Retrieve Results"
        STAT=3
        echo $OUTPUT
        exit 3
else
TOTAL=$(($OKNUM+$CRITNUM))
fi


if [ "$OKVMS" -ne "$TOTAL" ] ; then

	OUTPUT="${OUTPUT}STATUS CRITICAL: One or more VM's are in trouble on $HOST Number of Critical VM's: $CRITNUM\n"
	STAT=2

	else

		OUTPUT="${OUTPUT}STATUS OK: ALL VM's are in good health! Number of OK VM's: $OKNUM\n"
		STAT=0

	fi

echo $OUTPUT\n
exit $STAT
