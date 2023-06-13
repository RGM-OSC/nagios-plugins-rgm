#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'
export LANG="en_US.UTF-8"

usage() {
echo "Usage :check_snmp_ctrl_wifi_avaya.sh
        -C Community
        -H Host target
	-i Interface target
        -w Warning
        -c Critical
        -m Mode
		Discards : Discards number
		Errors : Errors number
	"
exit 2
}

if [ "${12}" = "" ]; then usage; fi

ARGS="$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')"
for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-m")" ]; then MODE="$(echo ${i} | sed -e 's: ::g' | cut -c 3-)"; if [ ! -n ${MODE} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-C")" ]; then COMMUNITY="$(echo ${i} | cut -c 3-)"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-i")" ]; then IFTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${IFTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-w")" ]; then WARNING="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-c")" ]; then CRITICAL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-avaya-interfaces/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-avaya-interfaces/${HOSTTARGET} && chown -R nagios.eyesofnetwork /tmp/tmp-avaya-interfaces ; fi
TMPDIR="/tmp/tmp-avaya-interfaces/${HOSTTARGET}"

COUNTWARNING=0
COUNTCRITICAL=0

OIDInOctets=.1.3.6.1.2.1.2.2.1.10
OIDInDiscards=.1.3.6.1.2.1.2.2.1.13
OIDInErrors=.1.3.6.1.2.1.2.2.1.14
OIDOutOctets=.1.3.6.1.2.1.2.2.1.16
OIDOutDiscards=.1.3.6.1.2.1.2.2.1.19
OIDOutErrors=.1.3.6.1.2.1.2.2.1.20

if [ ${MODE} = "ERRORS" ];then
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_InErrors.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_InErrors.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInErrors.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_InErrors.txt
	fi
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_OutErrors.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_OutErrors.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutErrors.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_OutErrors.txt
	fi

	INERRVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInErrors.$IFTARGET | cut -d' ' -f4)
	OUTERRVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutErrors.$IFTARGET | cut -d' ' -f4)
	OLDINERRVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_InErrors.txt)
	OLDOUTERRVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_OutErrors.txt)

	INERRCURDIFF=$(expr $INERRVAL - $OLDINERRVAL)
	OUTERRCURDIFF=$(expr $OUTERRVAL - $OLDOUTERRVAL)

	if [ ${INERRCURDIFF} -ge ${WARNING} ] || [ ${OUTERRCURDIFF} -ge ${WARNING} ];then
		if [ ${INERRCURDIFF} -gt ${CRITICAL} ] || [ ${OUTERRCURDIFF} -gt ${CRITICAL} ];then
			COUNTCRITICAL=1
			OUTPUTIN="Critical : Inbound interface errors in last hour : ${INERRCURDIFF}"
			OUTPUTOUT="Critical : Outbound interface errors in last hour : ${OUTERRCURDIFF}"
		else
			COUNTWARNING=1
			OUTPUTIN="Warning : Inbound interface errors in last hour : ${INERRCURDIFF}"
			OUTPUTOUT="Warning : Outbound interface errors in last hour : ${OUTERRCURDIFF}"
		fi
	else
		OUTPUTIN="Ok : Inbound interface errors in last hour : ${INERRCURDIFF}"
		OUTPUTOUT="Ok : Outbound interface errors in last hour : ${OUTERRCURDIFF}"
	fi
	OUTPUT=${OUTPUTIN},${OUTPUTOUT}
	PERF="InErr:$INERRCURDIFF;$WARNING;$CRITICAL,OutErr:$OUTERRCURDIFF;$WARNING;$CRITICAL"
fi


if [ ${MODE} = "DISCARDS" ];then
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInDiscards.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt
	fi
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutDiscards.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt
	fi

	INDISVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInDiscards.$IFTARGET | cut -d' ' -f4)
	OUTDISVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutDiscards.$IFTARGET | cut -d' ' -f4)
	OLDINDISVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt)
	OLDOUTDISVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt)

	INDISCURDIFF=$(expr $INDISVAL - $OLDINDISVAL)
	OUTDISCURDIFF=$(expr $OUTDISVAL - $OLDOUTDISVAL)

	if [ ${INDISCURDIFF} -ge ${WARNING} ] || [ ${OUTDISCURDIFF} -ge ${WARNING} ];then
		if [ ${INDISCURDIFF} -gt ${CRITICAL} ] || [ ${OUTDISCURDIFF} -gt ${CRITICAL} ];then
			COUNTCRITICAL=1
			if [ ${INDISCURDIFF} -gt ${CRITICAL} ];then
				OUTPUTIN="Critical : Inbound interface discards in last hour : ${INDISCURDIFF}"
			else
				OUTPUTOUT="Critical : Outbound interface discards in last hour : ${OUTDISCURDIFF}"
			fi
		else
			COUNTWARNING=1
			if [ ${INDISCURDIFF} -ge ${WARNING} ];then
				OUTPUTIN="Warning : Inbound interface discards in last hour : ${INDISCURDIFF}"
			else
				OUTPUTOUT="Warning : Outbound interface discards in last hour : ${OUTDISCURDIFF}"
			fi
		fi
	else
		OUTPUTIN="Ok : Inbound interface discards in last hour : ${INDISCURDIFF}"
		OUTPUTOUT="Ok : Outbound interface discards in last hour : ${OUTDISCURDIFF}"
	fi
	OUTPUT=${OUTPUTIN},${OUTPUTOUT}
	PERF="InDiscards:$INDISCURDIFF;$WARNING;$CRITICAL,OutDiscards:$OUTDISCURDIFF;$WARNING;$CRITICAL"
fi


if [ ${MODE} = "DISCARDSRATE" ];then
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInDiscards.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt
	fi
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutDiscards.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt
	fi
	INDISVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInDiscards.$IFTARGET | cut -d' ' -f4)
	OUTDISVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutDiscards.$IFTARGET | cut -d' ' -f4)
	OLDINDISVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_InDiscards.txt)
	OLDOUTDISVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_OutDiscards.txt)

	INDISCURDIFF=$(expr $INDISVAL - $OLDINDISVAL)
	OUTDISCURDIFF=$(expr $OUTDISVAL - $OLDOUTDISVAL)

	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_InOctets.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_InOctets.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInOctets.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_InOctets.txt
	fi
	if [ -n "$(find ${TMPDIR}/interface_${IFTARGET}_OutOctets.txt -mmin 60 -print)" ] || [ ! -n "$(cat ${TMPDIR}/interface_${IFTARGET}_OutOctets.txt)" ]; then
	        snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutOctets.$IFTARGET | cut -d' ' -f4 > ${TMPDIR}/interface_${IFTARGET}_OutOctets.txt
	fi

	INOCTVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDInOctets.$IFTARGET | cut -d' ' -f4)
	OUTOCTVAL=$(snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On $OIDOutOctets.$IFTARGET | cut -d' ' -f4)
	OLDINOCTVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_InOctets.txt)
	OLDOUTOCTVAL=$(cat ${TMPDIR}/interface_${IFTARGET}_OutOctets.txt)

	INOCTCURDIFF=$(expr $INOCTVAL - $OLDINOCTVAL)
	OUTOCTCURDIFF=$(expr $OUTOCTVAL - $OLDOUTOCTVAL)

	if [ ! -n ${INOCTCURDIFF} ];then
		INRATE=$(expr $INDISCURDIFF / $INOCTCURDIFF)
	fi

	if [ ! -n ${OUTOCTCURDIFF} ];then
		OUTRATE=$(expr $OUTDISCURDIFF / $OUTOCTCURDIFF)
	fi

	INPCTRATE=$(expr $INRATE * 100)
	OUTPCTRATE=$(expr $OUTRATE * 100)

	if [ ${INPCTRATE} -ge ${WARNING} ] || [ ${OUTPCTRATE} -ge ${WARNING} ];then
		if [ ${INPCTRATE} -gt ${CRITICAL} ] || [ ${OUTPCTRATE} -gt ${CRITICAL} ];then
			if [ ${INPCTRATE} -gt ${CRITICAL} ];then
				OUTPUTIN="Critical : Inbound interface discards in last hour : ${INDISCURDIFF}"
			else
				OUTPUTOUT="Critical : Outbound interface discards in last hour : ${OUTDISCURDIFF}"
			fi
		else
			COUNTWARNING=1
			if [ ${INPCTRATE} -ge ${WARNING} ];then
				OUTPUTIN="Warning : Inbound interface discards in last hour : ${INDISCURDIFF}"
			else
				OUTPUTOUT="Warning : Outbound interface discards in last hour : ${OUTDISCURDIFF}"
			fi
		fi
	else
		OUTPUTIN="Ok: Inbound interface discards rate : ${INPCTRATE}%"
		OUTPUTOUT="Ok: Outbound interface discards rate : ${OUTPCTRATE}%"
	fi
	OUTPUT=${OUTPUTIN},${OUTPUTOUT}
	PERF="InRate:$INPCTRATE;$WARNING;$CRITICAL,OutRate:$OUTPCTRATE;$WARNING;$CRITICAL"
fi

if [ `echo $OUTPUT | tr ',' '\n' | wc -l` -ge 2 ] ;then
        if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
                echo "CRITICAL: Click for detail, "
        else
                if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
                if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
        fi
        if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
        OUTPUT="$(echo $OUTPUT | tr ',' '\n')"
fi


if [ -n "$PERF" ]; then
        OUTPUT="$OUTPUT | $PERF"
fi
echo -n "$OUTPUT" | tr ',' ' '

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0
