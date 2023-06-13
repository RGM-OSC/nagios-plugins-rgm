#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'
export LANG="en_US.UTF-8"

usage() {
echo "Usage :check_snmp_ctrl_wifi_avaya.sh
	-C Community
	-H Host target
        -w Warning min,max
        -c Critical min,max
        -N AP Name
	-u Username
	-p Password
	-m mode can be:
		TotalConnectedAP
		TotalConnectionAPFailed
		APUpdateRequired
		ManagedAPBytesRecvd
		ManagedAPBytesTransmit
		ManagedAPAuthenticatedClient
		BySSIDConnectedUsers
		"
exit 2
}

if [ "${10}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-m"`" ]; then MODE="`echo ${i} | sed -e 's: ::g' | cut -c 3-`"; if [ ! -n ${MODE} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-N"`" ]; then APNAME="`echo ${i} | cut -c 3-`"; if [ ! -n ${APNAME} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-u"`" ]; then USERNAME="`echo ${i} | cut -c 3-`"; if [ ! -n ${USERNAME} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-p"`" ]; then PASSWORD="`echo ${i} | cut -c 3-`"; if [ ! -n ${PASSWORD} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then MINWARNING="`echo ${i} | cut -c 3- | cut -d',' -f1`"; if [ ! -n ${MINWARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then MAXWARNING="`echo ${i} | cut -c 3- | cut -d',' -f2`"; if [ ! -n ${MAXWARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then MINCRITICAL="`echo ${i} | cut -c 3-| cut -d',' -f1`"; if [ ! -n ${MINCRITICAL} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then MAXCRITICAL="`echo ${i} | cut -c 3-| cut -d',' -f2`"; if [ ! -n ${MAXCRITICAL} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-internal-wifi-avaya/${HOSTTARGET} ]; then mkdir -p /tmp/tmp-internal-wifi-avaya/${HOSTTARGET} && chown -R nagios.eyesofnetwork /tmp/tmp-internal-wifi-avaya ; fi
if [ ! -f /tmp/tmp-internal-wifi-avaya/${HOSTTARGET}/index_list.txt ]; then touch /tmp/tmp-internal-wifi-avaya/${HOSTTARGET}/index_list.txt ; fi
TMPDIR="/tmp/tmp-internal-wifi-avaya/${HOSTTARGET}"

if [ -n "`find ${TMPDIR}/index_list.txt -mmin 20 -print`" ] || [ ! -n "`cat ${TMPDIR}/index_list.txt | head -2`" ]; then
	snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET} -On 1.3.6.1.4.1.45.7.2.1.5.1.2 | sed -e 's:^.1.3.6.1.4.1.45.7.2.1.5.1.2.::g' > ${TMPDIR}/index_list.txt.tmp
	mv -f ${TMPDIR}/index_list.txt.tmp ${TMPDIR}/index_list.txt
fi

COUNTWARNING=0
COUNTCRITICAL=0
COUNTONEWARNING=0
COUNTONECRITICAL=0
COUNTTWOWARNING=0
COUNTTWOCRITICAL=0

OUTPUT=" "


CURRENT_ERR="0"

if [ -z "`find ${TMPDIR}/AP-Index-list.txt -mmin -60 -print`" ] || [ ! -n "`cat ${TMPDIR}/AP-Index-list.txt | head -2`" ]; then
	snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET 1.3.6.1.4.1.45.7.2.1.5.1.2 -On | cut -d' ' -f1,4 | sed 's:"::g' | cut -d'.' -f15- > ${TMPDIR}/AP-Index-list.txt
fi

if [ "$MODE" = "ManagedAPBytesRecvd" ] || [ "$MODE" = "ManagedAPBytesTransmit" ] || [ "$MODE" = "ManagedAPAuthenticatedClient" ] || [ "$MODE" = "BySSIDConnectedUsers" ]; then
	APRequiredIndex="`cat ${TMPDIR}/AP-Index-list.txt | grep $APNAME | cut -d' ' -f1`"
	if [ -z $APRequiredIndex ]; then
		echo "$APNAME isn't exist in list"
		exit 2
	fi
fi

if [ "$MODE" = "TotalConnectedAP" ]; then
                TotalConnectedAP="`snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET}  1.3.6.1.4.1.45.7.3.1.2.1.6 | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
                if [ $TotalConnectedAP -gt 0 ]; then
                        OUTPUT="$OUTPUT $HOSTTARGET: There is $TotalConnectedAP Access Point connected to this controller. "
                        if [ $TotalConnectedAP -le $MAXWARNING ] ; then
                                if [ $TotalConnectedAP -le $MAXCRITICAL ]  ; then
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
                        OUTPUT="$OUTPUT $HOSTTARGET: Il n'y a pas de borne sur ce controleur. \_o< PAN! \_×—  "
                        COUNTWARNING="`expr $COUNTWARNING + 1`"
                fi
                PERF="TotalConnectedAP=$TotalConnectedAP;$MAXWARNING:;$MAXCRITICAL:"
fi


if [ "$MODE" = "TotalConnectionAPFailed" ]; then
                TotalConnectionAPFailed="`snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET}  1.3.6.1.4.1.45.7.3.1.2.1.10 | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
                if [ $TotalConnectionAPFailed -gt 0 ]; then
                        OUTPUT="$OUTPUT $HOSTTARGET: There is $TotalConnectionAPFailed Access Point failed to connect to this controller. "
                        if [ $TotalConnectionAPFailed -ge $MAXWARNING ] ; then
                                if [ $TotalConnectionAPFailed -ge $MAXCRITICAL ] ; then
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
                        OUTPUT="$OUTPUT $HOSTTARGET: Il n'y a pas de borne en default sur ce controleur."
                        OUTPUT="$OUTPUT -> OK, "
                fi
                PERF="TotalConnectionAPFailed=$TotalConnectionAPFailed;$MAXWARNING;$MAXCRITICAL"
fi

if [ "$MODE" = "APUpdateRequired" ]; then
                APUpdateRequired="`snmpwalk -v 2c -c ${COMMUNITY} ${HOSTTARGET}  1.3.6.1.4.1.45.7.3.1.2.1.22 | cut -d'=' -f2 | cut -d':' -f2 | awk '{printf("%d",$1);}'`"
                if [ $APUpdateRequired -gt 0 ]; then
                        OUTPUT="$OUTPUT $HOSTTARGET: There is $APUpdateRequired Access Point with outdated version of firmware connected to this controller. "
                        if [ $APUpdateRequired -ge $MAXWARNING ] ; then
                                if [ $APUpdateRequired -ge $MAXCRITICAL ] ; then
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
                        OUTPUT="$OUTPUT $HOSTTARGET: Il n'y a pas de borne en default de version sur ce controleur."
                        OUTPUT="$OUTPUT -> OK, "
                fi
                PERF="APUpdateRequired=$APUpdateRequired;$MAXWARNING;$MAXCRITICAL"
fi

if [ "$MODE" = "ManagedAPAuthenticatedClient" ]; then
	snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET .1.3.6.1.4.1.45.7.7.1.6.1.5.$APRequiredIndex | cut -d' ' -f4 | awk '{printf("%d\n",$1);}' > ${TMPDIR}/Auth_Client_$APNAME
	AntennOneUsers="`cat ${TMPDIR}/Auth_Client_$APNAME | head -1`"
	AntennTwoUsers="`cat ${TMPDIR}/Auth_Client_$APNAME | head -2 | tail -1`"
	if [ $AntennOneUsers -gt $MAXWARNING ]; then
		if [ $AntennOneUsers -gt $MAXCRITICAL ]; then
			COUNTONECRITICAL=1
		else
			COUNTONEWARNING=1
		fi
	fi
	if [ $AntennTwoUsers -gt $MAXWARNING ]; then
		if [ $AntennTwoUsers -gt $MAXCRITICAL ]; then
			COUNTTWOCRITICAL=1
		else
			COUNTTWOWARNING=1
		fi
	fi
	if [ $COUNTONECRITICAL -eq 1 ] || [ $COUNTTWOCRITICAL -eq 1 ]; then
		OUTPUT="Critical: Users on first antenn "$AntennOneUsers", Users on second antenn $AntennTwoUsers"
		COUNTCRITICAL=1
	fi
	if [ $COUNTONEWARNING -eq 1 ] || [ $COUNTTWOWARNING -eq 1 ]; then
		OUTPUT="Warning: Users on first antenn "$AntennOneUsers", Users on second antenn $AntennTwoUsers"
		COUNTWARNING=1
	fi
	if [ $COUNTCRITICAL -lt 1 ] && [ $COUNTWARNING -lt 1 ]; then
		OUTPUT="OK: Users on first antenn "$AntennOneUsers", Users on second antenn $AntennTwoUsers"
	fi
	TotalConnectedUsers="`expr $AntennOneUsers + $AntennTwoUsers`"
        PERF="TotalConnectedAP=$TotalConnectedUsers;$MAXWARNING:;$MAXCRITICAL:"
fi

if [ "$MODE" = "ManagedAPBytesRecvd" ]; then
	OIDRecvdBytes=.1.3.6.1.4.1.45.7.7.1.3.1.2
	PastValueRecvd="`cat ${TMPDIR}/AP_Received_$APNAME`"
	ActualBytesRecvd="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $OIDRecvdBytes.$APRequiredIndex | cut -d' ' -f4`"
	DiffValueRecvd="`expr $ActualBytesRecvd - $PastValueRecvd`"

	OUTPUT="Last minutes received Bytes : $DiffValueRecvd"
	PERF="ManagedAPBytesRecvd=$DiffValueRecvd"

	snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $OIDRecvdBytes.$APRequiredIndex | cut -d' ' -f4 > ${TMPDIR}/AP_Received_$APNAME
fi

if [ "$MODE" = "ManagedAPBytesTransmit" ]; then
	OIDTransmitBytes=.1.3.6.1.4.1.45.7.7.1.3.1.4
	PastValueTransmit="`cat ${TMPDIR}/AP_Transmit_$APNAME`"
	ActualBytesTransmit="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $OIDTransmitBytes.$APRequiredIndex | cut -d' ' -f4`"
	DiffValueTransmit="`expr $ActualBytesTransmit - $PastValueTransmit`"

	OUTPUT="Last minutes received Bytes : $DiffValueTransmit"
	PERF="ManagedAPBytes=$DiffValueTransmit"

	snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $OIDTransmitBytes.$APRequiredIndex | cut -d' ' -f4 > ${TMPDIR}/AP_Transmit_$APNAME
fi

if [ "$MODE" = "BySSIDConnectedUsers" ]; then
	OIDAPMacAddress=.1.3.6.1.2.1.17.4.3.1.1
	APMacAddress="`snmpwalk -v 2c -c $COMMUNITY $HOSTTARGET $OIDAPMacAddress.$APRequiredIndex | cut -d' ' -f 4- | sed -e "s/ /:/g" | sed -e "s/:$//g"`"
	BaseAPMacAddress="`echo $APMacAddress | cut -d':' -f-5`"
TEST="`(
		sleep 5
		awk 'BEGIN { printf("%c",0x19);}'
		sleep 3
		echo "C"
		sleep 1
		echo "show wireless ap vap status $APMacAddress"
		sleep 1
		awk 'BEGIN { printf("%c",0x20);}'
		echo "exit"
		sleep 1
		echo "L"
		) | sshpass -p $PASSWORD ssh -t -t $USERNAME@$HOSTTARGET 2> /dev/null | grep "[1-2] \/ [1-5]" | cut -d' ' -f2,9- > ${TMPDIR}/By_SSID_Connected_Users_$APNAME`"
	OUTPUT="`cat ${TMPDIR}/By_SSID_Connected_Users_$APNAME | tr '\r' ' ' |  sed 's:  *: :g' | sed -e 's: $:,:g'`"

	PERF=""
	LIST_SSID="`echo "$OUTPUT" | awk '{print $2}' | tr '\n' ',' | sort -u | tr ' ' '+' | tr ',' ' ' | tr ' ' '\n' | sort -u | tr '\n' ' '`"
	for ssid in $LIST_SSID; do
		current_value="0"
		for i in `echo $OUTPUT | tr ',' '\n' | grep ${ssid} | tr ' ' '+' | sed 's:^+::g'`; do
			antenne_val="`echo $i | sed -e 's:,::g' | cut -d'+' -f3`"
			current_value="`expr $current_value + $antenne_val`"
		done
	PERF="$PERF $ssid=$current_value;;;;"
	done
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

