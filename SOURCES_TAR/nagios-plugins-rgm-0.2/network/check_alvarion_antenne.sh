#!/bin/bash

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_alvarion_antenne.sh
        -t Could be Ethernet, Status, Noise
        -H Host target
        -w Warning 
        -c Critical"
exit 2
}


if [ "${4}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPE="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;
fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done

if [ ! "$TYPE" = "ETHERNET" ] && [ ! "$TYPE" = "STATUS" ] && [ ! "$TYPE" = "NOISE" ]; then
		echo "The specified type specified using -t ($2) is not handled."
		exit 2
fi

TCP_OK="`/srv/eyesofnetwork/nagios/plugins/check_tcp -H ${HOSTTARGET} -p 23 > /dev/null; echo $?`"
if [ "$TCP_OK" = "0" ]; then

	if [ ! -d /tmp/tmp-alvarion-check/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-alvarion-check/${HOSTTARGET}; fi
	if [ ! -f /tmp/tmp-alvarion-check/${HOSTTARGET}/test_out.txt ]; then touch /tmp/tmp-alvarion-check/${HOSTTARGET}/test_out.txt ; fi
	TMPDIR="/tmp/tmp-alvarion-check/${HOSTTARGET}"
fi

TEST=""

if [ "$TCP_OK" = "0" ]; then
	if [ -n "`find ${TMPDIR}/test_out.txt -mmin +5`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt`" ] || [ -n "`cat ${TMPDIR}/test_out.txt | grep "Invalid command"`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt | grep "Ethernet port state"`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt | grep "Unit Status"`" ] || [ ! -n "`cat ${TMPDIR}/test_out.txt | grep "^Noise Floor Current Value"`" ]; then
(echo open ${HOSTTARGET}
sleep 15
echo "1"
sleep 10
printf "RO@SPIE"
sleep 8
echo -e "\015"
sleep 3
echo "1"
sleep 3
echo "s"
sleep 10
echo -e "\x1b\x5b\x44"
sleep 3
echo -e "\x1b\x5b\x44"
sleep 3
echo -e "\x1b\x5b\x44"
sleep 3
echo -e "\x1b\x5b\x44"
sleep 3
echo "x"
sleep 2
exit
) | telnet 2> /dev/null > $TMPDIR/test_out.txt
	fi
fi

#echo "$TEST" > $TMPDIR/test_out.txt

COUNTWARNING=0
COUNTCRITICAL=0

OUTPUT=" "
PERF=""

# So test out is not older than 5 minutes, nor empty, nor mal formed... Hum! Not completely sure yet. :)

if [ "$TCP_OK" = "0" ]; then
    if [ ! -n "`cat $TMPDIR/test_out.txt`" ] || [ -n "`cat ${TMPDIR}/test_out.txt | grep "Invalid command"`" ]; then
        OUTPUT="$OUTPUT $HOSTTARGET: Could not grab information,"
        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
    fi
else
        OUTPUT="$OUTPUT $HOSTTARGET: Could not connect to telnet port,"
        COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
fi

CURRENT_ERR="0"
if [ "$TYPE" = "ETHERNET" ]; then
		#Ethernet port state                         : 100 Mbps, Full-Duplex
        EtherState="` cat $TMPDIR/test_out.txt | grep "Ethernet port state" | cut -d':' -f2 | sed -e 's:,:;:g' | tr '\r' ' '`"
        EtherSpeed="`echo $EtherState | awk '{print $1}'`"
        OUTPUT="$OUTPUT $HOSTTARGET: Ethernet link: ${EtherState} "
        if [ "$WARNING" = "" ]; then WARNING=100; fi
        if [ "$CRITICAL" = "" ]; then CRITICAL=100; fi
        if [ $WARNING -gt $CRITICAL ]; then CRITICAL=$WARNING; fi

               if [ $EtherSpeed -lt $CRITICAL ] || [ ! -n "$EtherSpeed" ]; then
                    COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                    CURRENT_ERR="1"
                    OUTPUT="$OUTPUT -> CRITICAL, "
               fi
        PERF="ether_speed=$EtherSpeed"
fi

if [ "$TYPE" = "STATUS" ]; then
        STATUS="` cat $TMPDIR/test_out.txt | grep "^Unit Status" | cut -d':' -f2 | sed -e 's:,:;:g' | tr '\r' ' '`"
        OUTPUT="$OUTPUT $HOSTTARGET: Status: ${STATUS} "
        if [ ! "$STATUS" = " ASSOCIATED  " ]; then
                    COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                    CURRENT_ERR="1"
                    OUTPUT="$OUTPUT -> CRITICAL, Seems to be NOT ASSOCIATED"
        fi
        PERF=""
fi

if [ "$TYPE" = "NOISE" ]; then
		#Noise Floor Current Value                   : -90
        NoiseRate="` cat $TMPDIR/test_out.txt | grep "^Noise Floor Current Value" | cut -d':' -f2 | sed -e 's:-::g' | tr '\r' ' ' | awk '{print $1}'`"
        OUTPUT="$OUTPUT $HOSTTARGET: Noise Floor Current Value: -${NoiseRate}Db "
        if [ "$WARNING" = "" ]; then WARNING=100; fi
        if [ "$CRITICAL" = "" ]; then CRITICAL=100; fi
        if [ $WARNING -lt $CRITICAL ]; then CRITICAL=$WARNING; fi

               if [ $NoiseRate -gt $CRITICAL ]; then
                    COUNTCRITICAL="`expr $COUNTCRITICAL + 1`"
                    CURRENT_ERR="1"
                    OUTPUT="$OUTPUT -> CRITICAL, "
               fi
        PERF="Noise_Rate=$NoiseRate"
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
