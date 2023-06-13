#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_snmp_avaya.sh
        -t Could be cpu,memory,stack
	-C Community
	-H Host target
        -w Warning Free space available
        -c Critical Free space available"
exit 2
}

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
if [ "$TYPE" = "STACK" ]; then
	STACK_USAGE="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -On .1.3.6.1.2.1.47.1.1.1.1.11 | grep "LB" | grep -v ".1.3.6.1.2.1.47.1.1.1.1.11.1 =" | cut -d'=' -f1 | sed 's:.1.3.6.1.2.1.47.1.1.1.1.11.::g'`"
			COUNT_SW="0";
			for i in $STACK_USAGE; do
                                COUNT_SW="`expr $COUNT_SW + 1`"
                        	OUTPUT="$OUTPUT $HOSTTARGET: Stack member $COUNT_SW (`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET -On .1.3.6.1.2.1.47.1.1.1.1.2.$i | cut -d'=' -f2 | cut -d':' -f2 | sed 's:"::g' | sed 's:^ ::g'`) state is"
				OUT_STATE="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET .1.3.6.1.2.1.47.1.1.1.1.16.$i | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
				if [ ! "$OUT_STATE" = "1" ]; then
                                        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                                        OUTPUT="$OUTPUT CRITICAL, "
				else
                                        OUTPUT="$OUTPUT OK, "
				fi

			done

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


if [ `echo $OUTPUT | tr ',' '\n' | wc -l` -gt 2 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
	OUTPUT="`echo $OUTPUT | tr ',' '\n'`"
fi


if [ -n "$PERF" ]; then
	OUTPUT="$OUTPUT | $PERF"
fi
echo -n "$OUTPUT" | tr ',' ' '

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

