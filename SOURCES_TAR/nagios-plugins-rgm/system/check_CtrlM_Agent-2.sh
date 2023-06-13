#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG=en_US

usage() {
echo "Usage :Get_CtrlM_Agent-2.sh"
echo "Get_CtrlM_Agent-2.sh -h ServerCTMCS -a ServerAgent"
exit 2
}

if [ "${4}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-h"`" ]; then HOSTCTMCS="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTCTMCS} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-a"`" ]; then HOSTAGENT="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTAGENT} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
TMPDIR="/tmp/tmp-internal/ctmag/ctmag_${HOSTCTMCS}"


if [ ! -f ${TMPDIR}  ]; then
	echo "CRITICAL: Impossible to find ${TMPDIR}. Please check pre-requisite."
	exit 2
else
	CHECK_TIME="`cat ${TMPDIR} | head -1`"
	CUR_TIME="`date +%s`"
	DELTA_TIME="`expr $CUR_TIME - $CHECK_TIME | sed -e 's:-::g'`"

	if [ $DELTA_TIME -gt 1200 ];then
		echo "CRITICAL: Lastcheck of ${HOSTCTMCS} is older than 20 minutes."
		exit 2
	fi
	if [ -f ${TMPDIR}.running ]; then
		sleep 5
		if [ -f ${TMPDIR}.running ]; then
			echo "CRITICAL: Please check tmp-internal/ctmag_${HOSTCTMCS}.running..."
			exit 2
		fi
	fi

	AGENT_LINE="`cat ${TMPDIR} | grep -v "End_of_check" | grep "^${HOSTAGENT}:"`"
	FAILED=""
	for line in $AGENT_LINE; do
    	FAILED="`echo $line | grep -v "Available"` $FAILED"
	done
	if [ "$AGENT_LINE" == "" ]; then
		FAILED="Impossible to find this agent on the server $HOSTCTMCS."
	fi
    if [ -n "`echo $FAILED | awk '{print $1}'`" ]; then
        STATE="2"
        PLAINSTATE="CRITICAL"
    else
        STATE="0"
        PLAINSTATE="OK"
    fi
fi

echo -n "$PLAINSTATE: $FAILED"
echo "$AGENT_LINE"
exit $STATE
