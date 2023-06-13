#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_nvr.sh
        -t Could be stsurveil, stcam, strecords, recordsdate
	-C Community
	-H Host target
	-p SNMP Port
        -c Warning"
exit 2
}

if [ "${6}" = "" ]; then usage; fi

WARNING=1

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPE="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
  	if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-p"`" ]; then SNMPPORT="`echo ${i} | cut -c 3-`"; if [ ! -n ${SNMPPORT} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
done


COUNTWARNING=0
COUNTCRITICAL=0


OUTPUT=" "

OIDSystemName=.1.3.6.1.4.1.26956.1
OIDSurveilState=.1.3.6.1.4.1.26956.2
OIDCamState=.1.3.6.1.4.1.26956.3
OIDRecordsState=.1.3.6.1.4.1.26956.5
OIDCamNumber=.1.3.6.1.4.1.26956.7
OIDRecordDate=.1.3.6.1.4.1.26956.8

if [ ${SNMPPORT} -eq 10161 ]; then
	INSTANCE=1
fi
if [ ${SNMPPORT} -eq 20161 ]; then
	INSTANCE=2
fi
if [ ${SNMPPORT} -eq 30161 ]; then
	INSTANCE=3
fi


stcam(){
	CamST=`snmpwalk -v 1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDCamState | cut -d' ' -f4`
	ConvCamST=`echo "obase=2;$CamST" | bc`
	CamSTBin=`for i in $(seq 1 ${#ConvCamST}); do echo $(echo $ConvCamST | cut -c $i); done | tr '\n' ','`

	NBCamInstance=`snmpwalk -v1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDCamNumber | cut -d' ' -f4`
	VoiceNB=1
	while [[ $NBCamInstance -ge 1 ]]; do
		Cam=`snmpwalk -v 1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On ${OIDRecordDate}.$NBCamInstance`
		CamName=`echo ${Cam} | cut -d' ' -f 4- | cut -d' ' -f3-| sed s/\"//g` #C’est là que ça merde
		CamNameType=`echo ${Cam} | cut -d' ' -f3 | cut -d':' -f1`
		if [ "${CamNameType}" == "STRING" ] && [ "$(printf ${CamSTBin} | cut -d',' -f$VoiceNB)" != "" ]; then
			if  [ `echo $CamSTBin | cut -d',' -f$VoiceNB` -eq 0 ]; then
				OUTPUT2=`echo "$OUTPUT2, Cam $NBCamInstance $CamName not recorded"`
			fi
		elif [ "$(printf ${CamSTBin} | cut -d',' -f$VoiceNB)" != "" ]; then
			if [ `echo $CamSTBin | cut -d',' -f$VoiceNB` -eq 0 ]; then
				OUTPUT2=`echo "$OUTPUT2, Cam $NBCamInstance can't be properly verified"`
			fi
		fi


		NBCamInstance=$(expr $NBCamInstance - 1)
		VoiceNB=$(expr $VoiceNB + 1)
	done

	OUTPUT1=`echo $OUTPUT2 | tr ',' '\n' | grep -v properly | sed "/^$/d" | tr '\n' ','`
	OUTPUTCR=`echo $OUTPUT2 | tr ',' '\n' | grep properly | sed "/^$/d" | tr '\n' ','`


	NBVoiceHS=`echo $OUTPUT1 | awk 'BEGIN{FS=OFS=","} {x=x+NF-1} END {print x}' `
	if [ ${NBVoiceHS} -eq -1 ]; then
		NBVoiceHS=$(expr $NBVoiceHS + 1)
	fi

	if [ ${NBVoiceHS} -ge ${WARNING} ]; then
		COUNTWARNING=1
		OUTPUTSTCAM="Warning : You have $NBVoiceHS record voice HS and `echo $OUTPUTCR | wc -l` voice can't be properly verified on instance $INSTANCE,$OUTPUT2"
	else
		OUTPUTSTCAM="Ok : You have only $NBVoiceHS record voice HS and `echo $OUTPUTCR | wc -l` voice can't be properly verified on instance $INSTANCE,$OUTPUT2"
	fi
}



if [ "${TYPE}" == "STSURVEIL" ]; then
	SurveilST=`snmpwalk -v 1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDSurveilState | cut -d' ' -f4`

	if [ ${SurveilST} -eq 1 ]; then
		OUTPUT="Ok : Active Surveillance on instance ${INSTANCE}"
	else
		COUNTCRITICAL=1
		OUTPUT="Critical : Surveillance wasn't active on instance ${INSTANCE}"
	fi
fi

if [ "${TYPE}" == "STCAM" ]; then
	if [ "${8}" = "" ]; then usage; fi
	stcam
	OUTPUT=`echo $OUTPUTSTCAM`
fi

if [ "${TYPE}" == "STRECORDS" ]; then
	RecordsST=`snmpwalk -v 1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDRecordsState | cut -d' ' -f4`
	ConvRecordsST=`echo "obase=2;$RecordsST" | bc`
	RecordsSTBin=`for i in $(seq 1 ${#ConvRecordsST}); do echo $(echo $ConvRecordsST | cut -c $i); done | tr '\n' ','`

	NBCamInstance=`snmpwalk -v1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDCamNumber | cut -d' ' -f4`
	VoiceNB=1
	while [[ $NBCamInstance -ge 1 ]]; do

		if [ `echo $RecordsSTBin | cut -d',' -f$VoiceNB` -eq 0 ]; then
			OUTPUT1=`echo "$OUTPUT1 Voice $NBCamInstance free,"`
		fi

		NBCamInstance=$(expr $NBCamInstance - 1)
		VoiceNB=$(expr $VoiceNB + 1)
	done

	NBVoiceFree=`echo $OUTPUT1 | awk 'BEGIN{FS=OFS=","} {x=x+NF-1} END {print x}' `
	if [ ${NBVoiceFree} -eq -1 ] || [ ${NBVoiceFree} -eq 0 ]; then
		NBVoiceFree=$(expr $NBVoiceFree + 1)
	fi
	OUTPUT="You have $NBVoiceFree free on instance $INSTANCE"
fi

if [ "${TYPE}" == "RECORDSDATE" ]; then
	NBCamInstance=`snmpwalk -v1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On $OIDCamNumber | cut -d' ' -f4`
	VoiceNB=1
	while [ $VoiceNB -le $NBCamInstance ]
	do
		RecordString=`snmpwalk -v 1 -c ${COMMUNITY} ${HOSTTARGET}:${SNMPPORT} -On ${OIDRecordDate}.$VoiceNB | cut -d' ' -f 3-`
		RecordType=`echo $RecordString | cut -d':' -f1`
		if [ "${RecordType}" = "STRING" ]; then
			RecordDate=`echo $RecordString | cut -d' ' -f2-`
			RecordStart=`echo $RecordDate | cut -d' ' -f1 | sed "s/\"/ /g"`
			RecordEnd=`echo $RecordDate | cut -d' ' -f2 | sed "s/\"/ /g"`
			CamName=`echo $RecordDate | cut -d' ' -f3- | sed s/\"//g`
			OUTPUT="$OUTPUT, $VoiceNB $CamName:,	Start:$RecordStart ; End:$RecordEnd"
		else
			OUTPUT="$OUTPUT, $VoiceNB Can't be properly read"
		fi
		VoiceNB=`expr $VoiceNB + 1`
	done
	stcam
	if [ $COUNTWARNING -gt 0 ];then
		OUTPUT="Warning on instance $INSTANCE:,$OUTPUT2,$OUTPUT"
	else
		OUTPUT="On instance $INSTANCE:,$OUTPUT2,$OUTPUT"
	fi
fi



if [ "${TYPE}" == "STCAM" ] || [ "${TYPE}" == "RECORDSDATE" ]; then
	echo -n "$OUTPUT" | tr ',' '\n'
else

	if [ `echo $OUTPUT | tr ',' '\n' | wc -l` -gt 2 ] ;then
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, "; fi
		if [ ! $COUNTWARNING -gt 0 ] ; then echo "OK: Click for detail, "; fi
	fi
	echo -n "$OUTPUT" | tr ',' ' '
fi


if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

