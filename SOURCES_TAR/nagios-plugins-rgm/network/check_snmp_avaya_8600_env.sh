#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_snmp_avaya.sh
        -t Could be cpu, fan, memory, temp, power
	-C Community
	-H Host target
        -w Warning Free space available
        -c Critical Free space available"
exit 2
}

OIDFan=.1.3.6.1.4.1.2272.1.4.7.1.1.2
OIDTemp=.1.3.6.1.4.1.2272.1.4.7.1.1.3
OIDPowerState=.1.3.6.1.4.1.2272.1.4.8.1.1.2

if [ "${6}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPE="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-avaya-check/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-avaya-check/${HOSTTARGET}; fi
if [ ! -f /tmp/tmp-avaya-check/${HOSTTARGET}/snmpwalk_out.txt ]; then touch /tmp/tmp-avaya-check/${HOSTTARGET}/snmpwalk_out.txt ; fi
TMPDIR="/tmp/tmp-avaya-check/${HOSTTARGET}"

snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET 1.3.6.1.4.1.45.1.6.3.1 > $TMPDIR/snmpwalk_out.txt

COUNTWARNING=0
COUNTCRITICAL=0

OUTPUT=" "

PERF=""

if [ ! -n "`cat $TMPDIR/snmpwalk_out.txt`" ]; then
	OUTPUT="$OUTPUT $HOSTTARGET: Could not grab information via SNMP,"
	COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
fi




CURRENT_ERR="0"
if [ "$TYPE" = "CPU" ]; then
	CPU_USAGE="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET 1.3.6.1.4.1.45.1.6.3.8.1.1.5.3.10.0 | cut -d'=' -f2 | cut -d':' -f2  | awk '{printf("%d",$1);}'`"
        PCT_FREE="`echo "100 $CPU_USAGE" | awk '{ printf ("%d", ($1 - $2));}'`"
                        OUTPUT="$OUTPUT $HOSTTARGET: CPU $PCT_FREE% free on $SIZE "
                        if [ $PCT_FREE -lt $WARNING ]; then
                                if [ $PCT_FREE -lt $CRITICAL ]; then
                                        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
					CURRENT_ERR="1"
                                        OUTPUT="$OUTPUT -> CRITICAL, "
                                fi
				if [ $CURRENT_ERR -lt 1 ]; then
                                	COUNTWARNING="`expr $COUNTWARNING + 1`"
                                	OUTPUT="$OUTPUT -> WARNING, "
				fi
                        else
                                OUTPUT="$OUTPUT -> OK, "
                        fi
	PERF="cpu_usage=$CPU_USAGE"
fi


CURRENT_ERR="0"
if [ "$TYPE" = "MEMORY" ]; then
                SIZE="`snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET}  1.3.6.1.4.1.45.1.6.3.8.1.1.12.3.10.0 | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
                USED="`snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET}  1.3.6.1.4.1.45.1.6.3.8.1.1.13.3.10.0 | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
                FREE="`expr $SIZE - $USED`"
                if [ $SIZE -gt 0 ]; then
                        PCT_FREE="`echo "$SIZE $FREE" | awk '{ printf ("%d", (($2 / $1) * 100 ));}'`"
                        OUTPUT="$OUTPUT $HOSTTARGET: Memory $PCT_FREE% free on $SIZE "
                        if [ $PCT_FREE -lt $WARNING ]; then
                                if [ $PCT_FREE -lt $CRITICAL ]; then
                                        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
					CURRENT_ERR="1"
                                        OUTPUT="$OUTPUT -> CRITICAL, "
                                fi

				if [ $CURRENT_ERR -lt 1 ]; then
                                	COUNTWARNING="`expr $COUNTWARNING + 1`"
                                	OUTPUT="$OUTPUT -> WARNING, "
				fi
                        else
                                OUTPUT="$OUTPUT -> OK, "
                        fi
                else
                        OUTPUT="$OUTPUT $HOSTTARGET: Memory null sized on this F |_| [ |< 1 |\| 6 device. \_o< PAN! \_×—  "
                        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                fi
		PERF="memory_size=$SIZE,memory_used=$USED"
fi



if [ "$TYPE" = "FAN" ]; then
		snmpwalk -v 2c -c public $HOSTTARGET $OIDFan | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d\n",$1);}'> ${TMPDIR}/snmpwalk_out_fan.txt
		FanOne=`cat ${TMPDIR}/snmpwalk_out_fan.txt | head -1`
		FanTwo=`cat ${TMPDIR}/snmpwalk_out_fan.txt | grep -n ^ | grep ^1: | cut -d':' -f2`

	if [ $FanOne == "2" ]; then
		if [ $FanTwo == "2" ]; then
			OUTPUT="OK: Fan 1 - Up, Fan 2 - Up"
		else
			OUTPUT="Warning: Fan 1 - Up, Fan 2 - Down"
			COUNTWARNING=1
		fi
	else
		if [ $FanTwo == "2" ]; then
			OUTPUT="Warning: Fan 1 - Down, Fan 2 - Up"
			COUNTWARNING=1

		fi
	fi

fi

if [ "$TYPE" = "TEMP" ]; then
		snmpwalk -v 2c -c public $HOSTTARGET $OIDTemp | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d\n",$1);}'> ${TMPDIR}/snmpwalk_out_temp.txt
		TempOne=`cat ${TMPDIR}/snmpwalk_out_temp.txt | head -1`
		TempTwo=`cat ${TMPDIR}/snmpwalk_out_temp.txt | head -2 | tail -1 | cut -d':' -f2`

	if [ $TempOne -gt $CRITICAL ]; then
		if [ $TempTwo -gt $CRITICAL ]; then
			OUTPUT="Critical: Temp 1 Critical: $TempOne, Temp 2 Critical: $TempTwo"
			COUNTCRITICAL=1
		else
			if [ $TempTwo -gt $WARNING ] && [ $TempTwo -lt $CRITICAL ]; then
				OUTPUT="Critical: Temp 1 Critical: $TempOne, Temp 2 Warning: $TempTwo"
				COUNTCRITICAL=1
			else
				OUTPUT="Critical: Temp 1 Critical: $TempOne, Temp 2 Ok: $TempTwo"
				COUNTCRITICAL=1
			fi
		fi
	fi
	if [ $TempTwo -gt $CRITICAL ]; then
		if [ $TempOne -gt $CRITICAL ]; then
			OUTPUT="Critical: Temp 1 Critical: $TempOne, Temp 2 Critical: $TempTwo"
			COUNTCRITICAL=1
		else
			if [ $TempOne -gt $WARNING ] && [ $TempOne -lt $CRITICAL ]; then
				OUTPUT="Critical: Temp 1 Warning: $TempOne, Temp 2 Critical: $TempTwo"
				COUNTCRITICAL=1
			else
				OUTPUT="Critical: Temp 1 Ok: $TempOne, Temp 2 Critical: $TempTwo"
				COUNTCRITICAL=1
			fi
		fi
	fi

	if [ $TempOne -gt $WARNING ] && [ $TempOne -lt $CRITICAL ]; then
		if [ $TempTwo -gt $CRITICAL ]; then
			OUTPUT="Critical: Temp 1 Warning: $TempOne, Temp 2 Critical: $TempTwo"
			COUNTCRITICAL=1
		else
			if [ $TempTwo -gt $WARNING ] && [ $TempTwo -lt $CRITICAL ]; then
				OUTPUT="Warning: Temp 1 Warning: $TempOne, Temp 2 Warning: $TempTwo"
				COUNTWARNING=1
			else
				OUTPUT="Warning: Temp 1 Warning: $TempOne, Temp 2 Ok: $TempTwo"
				COUNTWARNING=1
			fi
		fi

	fi
	if [ $TempTwo -gt $WARNING ] && [ $TempTwo -lt $CRITICAL ]; then
		if [ $TempOne -gt $CRITICAL ]; then
			OUTPUT="Critical: Temp 1 Critical: $TempOne, Temp 2 Warning: $TempTwo"
			COUNTCRITICAL=1
		else
			if [ $TempOne -gt $WARNING ] && [ $TempOne -lt $CRITICAL ]; then
				OUTPUT="Warning: Temp 1 Warning: $TempOne, Temp 2 Warning: $TempTwo"
				COUNTWARNING=1
			else
				OUTPUT="Warning: Temp 1 Ok: $TempOne, Temp 2 Warning: $TempTwo"
				COUNTWARNING=1
			fi
		fi

	fi

	if [ $COUNTCRITICAL -eq 0 ] && [ $COUNTWARNING -eq 0 ] ; then
		OUTPUT="OK: Temp 1 Ok: $TempOne, Temp 2 Ok: $TempTwo"
	fi
	PERF="TempOne=$TempOne;$WARNING;$CRITICAL,TempTwo=$TempTwo;$WARNING;$CRITICAL"
fi


if [ "$TYPE" = "POWER" ]; then
		snmpwalk -v 2c -c public $HOSTTARGET $OIDPowerState | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d\n",$1);}'> ${TMPDIR}/snmpwalk_out_pow.txt
		PowerStateOne="`cat ${TMPDIR}/snmpwalk_out_pow.txt | head -1`"
		PowerStateTwo="`cat ${TMPDIR}/snmpwalk_out_pow.txt | grep -n ^ | grep ^1: | cut -d':' -f2`"
		PowerStateThree="`cat ${TMPDIR}/snmpwalk_out_pow.txt |  head -3 | tail -1 | cut -d':' -f2`"

		COUNT_EMPTY="0"
		if [ "$PowerStateThree" == "2" ] || [ "$PowerStateTwo" == "2" ] || [ "$PowerStateOne" == "2" ]; then
			if [ "$PowerStateOne" == "3" ]; then
				OUT1="PowerSupply 1: Ok"
			else
				if [ "$PowerStateOne" == "2" ]; then
					OUT1="PowerSupply 1: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT1="PowerSupply 1: Down"
	                                COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
				fi
			fi
			if [ "$PowerStateTwo" == "3" ]; then
				OUT2="PowerSupply 2: Ok"
			else
				if [ "$PowerStateTwo" == "2" ]; then
					OUT2="PowerSupply 2: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT2="PowerSupply 2: Down"
	                                COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
				fi
			fi
			if [ "$PowerStateThree" == "3" ]; then
				OUT3="PowerSupply 3: Ok"
			else
				if [ "$PowerStateThree" == "2" ]; then
					OUT3="PowerSupply 3: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT3="PowerSupply 3: Down"
	                                COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
				fi
			fi
		else
			if [ "$PowerStateOne" == "3" ]; then
				OUT1="PowerSupply 1: Ok"
			else
				if [ "$PowerStateOne" == "2" ]; then
					OUT1="PowerSupply 1: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT1="PowerSupply 1: Down"
	                                COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
				fi
			fi
			if [ "$PowerStateTwo" == "3" ]; then
				OUT2="PowerSupply 2: Ok"
			else
				if [ "$PowerStateTwo" == "2" ]; then
					OUT2="PowerSupply 2: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT2="PowerSupply 2: Down"
	                                COUNTWARNING="`expr $COUNTWARNING + 1`"
				fi
			fi
			if [ "$PowerStateThree" == "3" ]; then
				OUT3="PowerSupply 3: Ok"
			else
				if [ "$PowerStateThree" == "2" ]; then
					OUT3="PowerSupply 3: Empty"
					COUNT_EMPTY="`expr $COUNT_EMPTY + 1`"
				else
					OUT3="PowerSupply 3: Down"
	                                COUNTWARNING="`expr $COUNTWARNING + 1`"
				fi
			fi
		fi
		if [ $COUNT_EMPTY -gt 0 ]; then
			if [ $COUNT_EMPTY -gt 1 ]; then
				COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
			fi
		fi
		if [ $COUNTWARNING -gt 0 ]; then
			if [ $COUNTWARNING -gt 1 ]; then
                                COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
			fi
		fi

		OUTPUT="$OUT1 , $OUT2 , $OUT3"
fi


if [ `echo $OUTPUT | tr ',' '\n' | wc -l` -gt 2 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
fi

echo -n "$OUTPUT" | tr ',' ' '

if [ -n "$PERF" ]; then
	echo " | $PERF"
fi

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

