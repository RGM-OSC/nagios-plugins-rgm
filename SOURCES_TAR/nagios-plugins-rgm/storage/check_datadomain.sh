#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

CHECKNAME="check_datadomain.sh"
REVISION="0.1"

usage () {
echo "Usage :check_datadomain.sh
        -H Host target
        -C Community (default : public)
        -v SNMP version (default : 2)
        -P SNMP Port (default : 161)
        -w Warning (If temp, Form : CPU:Ambient:Other) (default = 65:30:45)
        -c Critical (If temp, Form : CPU:Ambient:Other) (default = 75:40:55)
        -t Type :
        	POWER, Current power module status
        	TEMP, Current temperature sensors (use -w and -c for specific value)
        	DISKSPACE, Current disk occupation (use -w and -c)
        	DEDFACTORW, Deduplication factor for last 7 days (use -w and -c)
        	DEDFACTORD, Deduplication factor for last 24 hours (use -w and -c)
        	DISKSTATE, List all disk current state
        	DISKPERF, Current disk performance
        "
exit 3
}

out() {
	if [ $COUNTCRITICAL -ge 1 ] || [ $COUNTWARNING -ge 1 ];then
		if [ $COUNTWARNING -ge 1 ];then
			echo -n "Warning : Click for detail,$OUTPUT," | tr ',' '\n'
		fi
		if [ $COUNTCRITICAL -ge 1 ] ; then
			echo -n "Crtical : Click for detail,$OUTPUT," | tr ',' '\n'
		fi
	else
		echo -n "OK : Click for detail,$OUTPUT," | tr ',' '\n'
	fi
	if [ -n "$PERF" ]; then
        	echo " | $PERF"
	fi
	if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
	if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
	exit 0
}
ARGS="$(echo $@ |sed -e 's:-[[:alpha:]] :\n&:g' | sed -e 's: ::g')"
#if [ ! -n "${ARGS}" ]; then usage;fi
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-C"`" ]; then COMMUNITY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-v"`" ]; then VERSION="`echo ${i} | cut -c 3-`"; if [ ! -n ${VERSION} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-P"`" ]; then PORT="`echo ${i} | cut -c 3-`"; if [ ! -n ${PORT} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPEG="`echo ${i} | cut -c 3-`"; if [ ! -n ${TYPEG} ]; then usage;fi;fi
done
if [ ! -n "${COMMUNITY}" ]; then COMMUNITY="public" ; fi
if [ ! -n "${PORT}" ]; then PORT=161 ; fi
if [ ! -n "${VERSION}" ]; then VERSION="2c" ; fi
if [ ! -n "${CRITICAL}" ]; then CRITICAL="75:40:55" ; fi
if [ ! -n "${WARNING}" ]; then WARNING="65:30:45" ; fi

TYPE=${TYPEG^^}

COUNTWARNING=0
COUNTCRITICAL=0

if [ ${TYPE} == "ALERTS" ]; then
	OIDAlerts=".1.3.6.1.4.1.19746.1.4.1.1.1"
	AlertSeverity=".1.3.6.1.4.1.19746.1.4.1.1.1.4"

	if [ ${severity} == "INFO" ]; then
		OUTPUT="Info"
	elif [ ${severity} == "WARNING" ]; then
		OUTPUT="Warning"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	elif [ ${severity} == "CRITICAL" ]; then
		OUTPUT="Critical"
		COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
	fi
fi

if [ ${TYPE} == "POWER" ]; then
	PSUNamesIndex=".1.3.6.1.4.1.19746.1.1.1.1.1.1.3.1"
	PSUStatesIndex=".1.3.6.1.4.1.19746.1.1.1.1.1.1.4.1"
	NB_PSU=1
	PSUNames=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $PSUNamesIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';'`
	PSUStates=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $PSUStatesIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';'`
	for state in `echo $PSUStates|tr ';' '\n'`; do
		if [ $state -ne 1 ]; then
			OUTPUT="${OUTPUT}`echo $PSUNames | cut -d';' -f${NB_PSU}` isn't in normal state,"
			COUNTWARNING=`expr $COUNTWARNING + 1`
		else
			OUTPUT="${OUTPUT}`echo $PSUNames | cut -d';' -f${NB_PSU}` is ok,"
		fi
		NB_PSU=`expr $NB_PSU + 1`
	done
	OUTPUT=`echo ${OUTPUT} | sed -e "s/, /,/g"`
fi

if [ ${TYPE} == "TEMP" ]; then
	TEMPNamesIndex=".1.3.6.1.4.1.19746.1.1.2.1.1.1.4"
	TEMPValueIndex=".1.3.6.1.4.1.19746.1.1.2.1.1.1.5"
	TEMPStatesIndex=".1.3.6.1.4.1.19746.1.1.2.1.1.1.6"
	NB_TEMP=1
	TEMPNames=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $TEMPNamesIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`
	TEMPValue=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $TEMPValueIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';'`
	TEMPStates=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $TEMPStatesIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';'`
	for state in `echo $TEMPStates|tr ';' '\n'`; do
		if [ $state -eq 1 ]; then
			if [ "`echo $TEMPNames | cut -d';' -f${NB_TEMP}`" == "CPU temperature" ]; then
				if [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $CRITICAL | cut -d':' -f1` ]; then
					OUTPUT="${OUTPUT}Critical : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is too higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
				elif [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $WARNING | cut -d':' -f1` ]; then
					OUTPUT="${OUTPUT}Warning : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTWARNING=`expr $COUNTWARNING + 1`
				else
					OUTPUT="${OUTPUT}Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is ok : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
				fi
				PERF="$PERF `echo $TEMPNames | cut -d';' -f${NB_TEMP}| tr ' ' '_'`=`echo $TEMPValue | cut -d';' -f${NB_TEMP}`;`echo $WARNING | cut -d':' -f1`;`echo $CRITICAL | cut -d':' -f1`"
			elif [ -n "`echo $TEMPNames | cut -d';' -f${NB_TEMP} | grep -v Ambient`" ]; then
				if [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $CRITICAL | cut -d':' -f3` ]; then
					OUTPUT="${OUTPUT}Critical : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is too higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
				elif [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $WARNING | cut -d':' -f3` ]; then
					OUTPUT="${OUTPUT}Warning : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTWARNING=`expr $COUNTWARNING + 1`
				else
					OUTPUT="${OUTPUT}Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is ok : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
				fi
				PERF="$PERF `echo $TEMPNames | cut -d';' -f${NB_TEMP}| tr ' ' '_'`=`echo $TEMPValue | cut -d';' -f${NB_TEMP}`;`echo $WARNING | cut -d':' -f3`;`echo $CRITICAL | cut -d':' -f3`"
			else
				if [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $CRITICAL | cut -d':' -f2` ]; then
					OUTPUT="${OUTPUT}Critical : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is too higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
				elif [ `echo $TEMPValue | cut -d';' -f${NB_TEMP}` -ge `echo $WARNING | cut -d':' -f2` ]; then
					OUTPUT="${OUTPUT}Warning : Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is higher : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
					COUNTWARNING=`expr $COUNTWARNING + 1`
				else
					OUTPUT="${OUTPUT}Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` is ok : `echo $TEMPValue | cut -d';' -f${NB_TEMP}`°C,"
				fi
				PERF="$PERF `echo $TEMPNames | cut -d';' -f${NB_TEMP}| tr ' ' '_'`=`echo $TEMPValue | cut -d';' -f${NB_TEMP}`;`echo $WARNING | cut -d':' -f2`;`echo $CRITICAL | cut -d':' -f2`"
			fi
		else
			OUTPUT="${OUTPUT}Sensor `echo $TEMPNames | cut -d';' -f${NB_TEMP}` isn't present,"
		fi

		NB_TEMP=`expr $NB_TEMP + 1`
	done
fi

if [ ${TYPE} == "DISKSPACE" ]; then
	DISKNamesIndex=".1.3.6.1.4.1.19746.1.3.2.1.1.3"
	#DISKUsedValueIndex=".1.3.6.1.4.1.19746.1.3.2.1.1.5"
	#DISKFreeValueIndex=".1.3.6.1.4.1.19746.1.3.2.1.1.6"
	DISKUsedPctIndex=".1.3.6.1.4.1.19746.1.3.2.1.1.7"
	NB_DISK=1
	DISKNames=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKNamesIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`
	#DISKUsedValues=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKUsedValueIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`
	#DISKFreeValues=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKFreeValueIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`
	DISKUsedPctValues=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKUsedPctIndex -On | cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`

	for diskname in `echo ${DISKNames} | tr ';' '\n'`; do
		if [ `echo ${DISKUsedPctValues} | cut -d';' -f${NB_DISK}` -ge ${CRITICAL} ]; then
			OUTPUT="${OUTPUT}Critical : Disk `echo $DISKNames | cut -d';' -f${NB_DISK}` is fill at : `echo ${DISKUsedPctValues} | cut -d';' -f${NB_DISK}`%,"
			COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
		elif [ `echo ${DISKUsedPctValues} | cut -d';' -f${NB_DISK}` -ge ${WARNING} ]; then
			OUTPUT="${OUTPUT}Warning : Disk `echo $DISKNames | cut -d';' -f${NB_DISK}` is fill at : `echo ${DISKUsedPctValues} | cut -d';' -f${NB_DISK}`%,"
			COUNTWARNING=`expr $COUNTWARNING + 1`
		else
			OUTPUT="${OUTPUT}Disk `echo $DISKNames | cut -d';' -f${NB_DISK}` is fill at : `echo ${DISKUsedPctValues} | cut -d';' -f${NB_DISK}`%,"
		fi
		PERF="$PERF `echo $DISKNames | cut -d';' -f${NB_DISK}| tr ' ' '_'`=`echo $DISKUsedPctValues | cut -d';' -f${NB_DISK}`;$WARNING;$CRITICAL"
		NB_DISK=`expr $NB_DISK + 1`
	done
fi

if [ ${TYPE} == "DEDFACTORW" ]; then
	OIDDEDUWeekPreCompSize=".1.3.6.1.4.1.19746.1.3.3.1.1.5.1"
	OIDDEDUWeekPostCompSize=".1.3.6.1.4.1.19746.1.3.3.1.1.6.1"
	OIDDEDUWeekFactor=".1.3.6.1.4.1.19746.1.3.3.1.1.9.1"
	DEDUWeekPreCompSize=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUWeekPreCompSize -On| cut -d':' -f2 | sed s/\"//g`
	DEDUWeekPostCompSize=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUWeekPostCompSize -On| cut -d':' -f2 | sed s/\"//g`
	DEDUWeekFactor=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUWeekFactor -On| cut -d':' -f2 | sed s/\"//g`
	if [ `echo ${DEDUWeekFactor} | cut -d'.' -f1` -lt ${CRITICAL} ]; then
		OUTPUT="Deduplication factor: ${DEDUWeekFactor} % PreComp: ${DEDUWeekPreCompSize} GB PostComp: ${DEDUWeekPostCompSize} GB"
		COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
	elif [ `echo ${DEDUWeekFactor} | cut -d'.' -f1` -lt ${WARNING} ]; then
		OUTPUT="Deduplication factor: ${DEDUWeekFactor} % PreComp: ${DEDUWeekPreCompSize} GB PostComp: ${DEDUWeekPostCompSize} GB"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	else
		OUTPUT="Deduplication factor: ${DEDUWeekFactor} % PreComp: ${DEDUWeekPreCompSize} GB PostComp: ${DEDUWeekPostCompSize} GB"
	fi
	PERF="$PERF Deduplication_week_factor=$DEDUWeekFactor;$WARNING;$CRITICAL"
fi

if [ ${TYPE} == "DEDFACTORD" ]; then
	OIDDEDUDayPreCompSize=".1.3.6.1.4.1.19746.1.3.3.1.1.5.0"
	OIDDEDUDayPostCompSize=".1.3.6.1.4.1.19746.1.3.3.1.1.6.0"
	OIDDEDUDayFactor=".1.3.6.1.4.1.19746.1.3.3.1.1.9.0"
	DEDUDayPreCompSize=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUDayPreCompSize -On| cut -d':' -f2 | sed s/\"//g`
	DEDUDayPostCompSize=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUDayPostCompSize -On| cut -d':' -f2 | sed s/\"//g`
	DEDUDayFactor=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDEDUDayFactor -On| cut -d':' -f2 | sed s/\"//g`
	if [ `echo ${DEDUDayFactor} | cut -d'.' -f1` -lt ${CRITICAL} ]; then
		OUTPUT="Deduplication factor: ${DEDUDayFactor} % PreComp: ${DEDUDayPreCompSize} GB PostComp: ${DEDUDayPostCompSize} GB"
		COUNTCRITICAL=`expr $COUNTCRITICAL + 1`
	elif [ `echo ${DEDUDayFactor} | cut -d'.' -f1` -lt ${WARNING} ]; then
		OUTPUT="Deduplication factor: ${DEDUDayFactor} % PreComp: ${DEDUDayPreCompSize} GB PostComp: ${DEDUDayPostCompSize} GB"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	else
		OUTPUT="Deduplication factor: ${DEDUDayFactor} % PreComp: ${DEDUDayPreCompSize} GB PostComp: ${DEDUDayPostCompSize} GB"
	fi
	PERF="$PERF Deduplication_day_factor=$DEDUDayFactor;$WARNING;$CRITICAL"
fi

if [ ${TYPE} == "DISKSTATE" ]; then
	DISKStateIndex=".1.3.6.1.4.1.19746.1.6.1.1.1.8"
	DISKState=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKStateIndex -On| cut -d':' -f2 | sed s/\"//g`
	NB_DISK=0
	HOTSPARE=0;ACTIVE=0;HS=0;NOTPLUG=0;UNKNOW=0
	for state in `echo $DISKState | tr ';' '\n'`; do
		if [ ${state} -eq 5 ]; then
			HOTSPARE=`expr ${HOTSPARE} + 1`
		fi;if [ ${state} -eq 1 ]; then
			ACTIVE=`expr ${ACTIVE} + 1`
		fi;if [ ${state} -eq 0 ]; then
			NOTPLUG=`expr ${NOTPLUG} + 1`
		fi;if [ ${state} -ne 5 ] && [ ${state} -ne 1 ] && [ ${state} -ne 0 ]; then
			UNKNOW=`expr ${UNKNOW} + 1`
		fi
		NB_DISK=`expr $NB_DISK + 1`
	done
	if [ ${HOTSPARE} -eq 0 ]; then
		OUTPUT="${OUTPUT}Warning - HotSpare: ${HOTSPARE},"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	else
		OUTPUT="${OUTPUT}HotSpare: ${HOTSPARE},"
	fi
	if [ ${HS} -gt 0 ]; then
		OUTPUT="${OUTPUT}Warning - Disk HS: ${HS},"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	fi
	if [ ${NOTPLUG} -gt 0 ]; then
		OUTPUT="${OUTPUT}Free disk enclosure: ${NOTPLUG}"
	fi
	if [ ${ACTIVE} -ge 0 ]; then
		OUTPUT="${OUTPUT}Disk active: ${ACTIVE}"
	fi
	if [ ${UNKNOW} -gt 1 ]; then
		OUTPUT="${OUTPUT}Unknown state: ${UNKNOW}"
		COUNTWARNING=`expr $COUNTWARNING + 1`
	fi
fi

if [ ${TYPE} == "DISKPERF" ]; then
	OIDDISKRead=".1.3.6.1.4.1.19746.1.5.1.1.1.10"
	OIDDISKWrite=".1.3.6.1.4.1.19746.1.5.1.1.1.11"
	OIDDISKReplicationReceived=".1.3.6.1.4.1.19746.1.5.1.1.1.15"
	OIDDISKReplicationSent=".1.3.6.1.4.1.19746.1.5.1.1.1.15"
	DISKStates=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $DISKStateIndex -On| cut -d':' -f2 | sed s/\"//g | tr '\n' ';' | sed "s/; /;/g"`
	DISKRead=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDISKRead -On| cut -d':' -f2 | sed s/\"//g`
	DISKWrite=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDISKWrite -On| cut -d':' -f2 | sed s/\"//g`
	DISKRepReceived=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDISKReplicationReceived -On| cut -d':' -f2 | sed s/\"//g`
	DISKRepSent=`snmpwalk -v $VERSION -c $COMMUNITY $HOSTTARGET $OIDDISKReplicationSent -On| cut -d':' -f2 | sed s/\"//g`

	OUTPUT="Read: ${DISKRead}kB/s - Write: ${DISKWrite}kB/s,"
	OUTPUT="${OUTPUT}Replication received: ${DISKRepReceived}kB/s - Replication sent: ${DISKRepSent}kB/s"
	PERF="Disk_read=${DISKRead};;; Disk_Write=${DISKWrite};;; Disk_replication_received=${DISKRepReceived};;; Disk_replication_sent=${DISKRepSent};;;"
fi



out
