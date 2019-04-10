#!/bin/bash

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_AKCPinc_sonde.sh
        -t Could be Status, Temperature
        -H Host target
        -w Warning 
        -c Critical"
exit 2
}


if [ "${4}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPE="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done

if [ ! "$TYPE" = "STATUS" ] &&  [ ! "$TYPE" = "TEMPERATURE" ]; then
		echo "The specified type specified using -t ($2) is not handled."
		exit 2
fi

TCP_OK="`/srv/eyesofnetwork/nagios/plugins/check_tcp -H ${HOSTTARGET} -p 80 > /dev/null; echo $?`"
if [ "$TCP_OK" = "0" ]; then

	if [ ! -d /tmp/tmp-AKCPinc-check/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-AKCPinc-check/${HOSTTARGET}; fi
	if [ ! -f /tmp/tmp-AKCPinc-check/${HOSTTARGET}/test_out.txt ]; then touch /tmp/tmp-AKCPinc-check/${HOSTTARGET}/test_out.txt ; fi
	TMPDIR="/tmp/tmp-AKCPinc-check/${HOSTTARGET}"
fi
 
TEST=""

if [ "$TCP_OK" = "0" ]; then
	if [ -n "`find ${TMPDIR}/test_out.txt -mmin +5`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt | grep "Status"`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt | grep "Current Reading"`" ]; then
         wget http://${HOSTTARGET}/senstmp?index=0\&time= -o /dev/null -O $TMPDIR/last_test_out.html
         cat $TMPDIR/last_test_out.html | sed -e 's:&nbsp;::g' | sed -e 's:<tr>:µ:g' | tr 'µ' '\n' > ${TMPDIR}/test_out.txt
	fi
fi

Status="`cat ${TMPDIR}/test_out.txt | grep ">Status" | sed -e 's:td class=:µ:g' | tr 'µ' '\n' | grep "textbold" | cut -d'>' -f2 | cut -d'<' -f1`"
Temperature="`cat ${TMPDIR}/test_out.txt | grep ">Current Reading" | sed -e 's:td class=:µ:g' | tr 'µ' '\n' | grep "textbold" | cut -d'>' -f2 | cut -d'<' -f1 | cut -d' ' -f1`"

#printf "Status=$Status"
#printf "Temperature=$Temperature"

COUNTWARNING=0
COUNTCRITICAL=0

OUTPUT=" "
PERF=""

# So test out is not older than 5 minutes, nor empty, nor mal formed... Hum! Not completely sure yet. :)

if [ ! -n "`cat $TMPDIR/test_out.txt`" ] || [ -n "`cat ${TMPDIR}/test_out.txt | grep "Invalid command"`" ]; then
        OUTPUT="$OUTPUT $HOSTTARGET: Could not grab information,"
        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
fi
if [ ! "$TCP_OK" = "0" ]; then
        OUTPUT="$OUTPUT $HOSTTARGET: Could not connect to Web interface,"
        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
fi

CURRENT_ERR="0"
if [ "$TYPE" = "STATUS" ]; then
        OUTPUT="$OUTPUT Status: ${Status} "
        if [ "$STATUS" = "Normal" ]; then
                    COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                    CURRENT_ERR="1"
                    OUTPUT="$OUTPUT -> CRITICAL, "
        fi
        PERF=""
fi

if [ "$TYPE" = "TEMPERATURE" ]; then
        OUTPUT="$OUTPUT Temperature (Degrés): ${Temperature} "
        if [ "$WARNING" = "" ]; then WARNING=18; fi
        if [ "$CRITICAL" = "" ]; then CRITICAL=32; fi # ATTENTION ICI UTILISER EN FENETRE de qualite

               if [ $Temperature -gt $CRITICAL ] || [ ! -n "$Temperature" ]; then
                    COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                    CURRENT_ERR="1"
                    OUTPUT="$OUTPUT -> CRITICAL, "
               else
                    if [ $Temperature -gt $WARNING ] || [ ! -n "$Temperature" ]; then
                        COUNTWARNING="`expr $COUNTWARNING + 1`"
                        CURRENT_ERR="1"
                        OUTPUT="$OUTPUT -> WARNING, "
                    fi
               fi
        PERF="Temperature=$Temperature"
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