#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

CHECKNAME="check_cisco_repoperstatus.sh"
REVISION="0.1"

usage () {
echo "Usage :check_datadomain.sh
        -H Host target
        -C Community (default : public)
        -v SNMP version (default : 2)
        -P SNMP Port (default : 161)
        "
exit 3
}

out() {
	if [ $COUNTWARNING -ge 1 ];then
		echo "Warning : click for details,"
		echo -n "$OUTPUT," | tr ',' '\n'
		exit 1
	fi
	if [ $COUNTCRITICAL -ge 1 ] ; then
		echo "Critical : click for details,"
		echo -n "$OUTPUT," | tr ',' '\n'
		exit 2
	fi
	echo "Ok : click for details,"
	echo -n "$OUTPUT," | tr ',' '\n'
	if [ -n "$PERF" ]; then
        echo " | $PERF"
	fi
	if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
	if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
	exit 0
}

ARGS=$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')
if [ ! -n "${ARGS}" ]; then usage;fi
for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-C")" ]; then COMMUNITY="$(echo ${i} | cut -c 3-)"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-v")" ]; then VERSION="$(echo ${i} | cut -c 3-)"; if [ ! -n ${VERSION} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-P")" ]; then PORT="$(echo ${i} | cut -c 3-)"; if [ ! -n ${PORT} ]; then usage;fi;fi
done
if [ ! -n "${COMMUNITY}" ]; then COMMUNITY="public" ; fi
if [ ! -n "${PORT}" ]; then PORT=161 ; fi
if [ ! -n "${VERSION}" ]; then VERSION="2c" ; fi

COUNTWARNING=0
COUNTCRITICAL=0

OIDRepOperStatus=.1.3.6.1.4.1.9.9.601.1.3.1.1.4
OIDRepIfOperStatus=.1.3.6.1.4.1.9.9.601.1.2.1.1.3

if [ $(snmpwalk -On -v ${VERSION} -c ${COMMUNITY} ${HOSTTARGET} ${OIDRepOperStatus} | cut -d' ' -f4) == '1' ]
then
	OUTPUT="Rep status is OK"
else
	IFNUM=1
	INDEXINT=$(snmpwalk -On -v ${VERSION} -c ${COMMUNITY} ${HOSTTARGET} ${OIDRepIfOperStatus} | cut -d' ' -f4)
	for NIF in ${INDEXINT}
	do
		if [ ${NIF} != "5" ]
		then
			COUNTCRITICAL=$(expr ${COUNTCRITICAL} + 1)
			OUTPUT="${OUTPUT},Interface ${IFNUM} not operating normaly. Status : ${NIF}"
		fi
		IFNUM=$(expr ${IFNUM} + 1)
	done
	if [ ${COUNTCRITICAL} -lt 1 ] && [ -n $(echo ${OUTPUT} | grep OK) ]
	then
		COUNTWARNING=$(expr ${COUNTWARNING} + 1)
		OUTPUT="Rep not operating normally but not interface was shut here"
	fi
fi

out
