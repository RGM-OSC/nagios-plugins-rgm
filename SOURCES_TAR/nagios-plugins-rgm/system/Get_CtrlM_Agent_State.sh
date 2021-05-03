#!/bin/bash

# This script use the command NRPE 
# check_nrpe -H XXXXXX -t60 -n -c check_agents_CTRLM
# Then build a list in 

export LANG=en_US

usage() {
echo "Usage :Get_CtrlM_Agent_State.sh"
echo "Get_CtrlM_Agent_State.sh -h ServerCTMCS"
exit 2
}

if [ "${2}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-h"`" ]; then HOSTCTMCS="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTCTMCS} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-internal/ctmag/ ]; then mkdir -p /tmp/tmp-internal/ctmag/; fi
TMPDIR="/tmp/tmp-internal/ctmag/ctmag_${HOSTCTMCS}"

if [ ! -x /srv/eyesofnetwork/nagios/plugins/check_nrpe  ]; then
	echo "Impossible to execute check_nrpe. Please check pre-requisite."
else
	scp nagios@${HOSTCTMCS}:/home/nagios/check_agents_CTRLM/Current_State_agstat_Ready ${TMPDIR}.tmp >> ${TMPDIR}_scplog.txt 2>&1
	if [ ! -s ${TMPDIR}.tmp ]; then
		scp nagios@${HOSTCTMCS}:/home/nagios/check_agents_CTRLM/Current_State_agstat_Ready ${TMPDIR}.tmp >> ${TMPDIR}_scplog.txt 2>&1
		# DEBUG PURPOSE ONLY
			echo "`date` Fic 0 detected. Redo the copy. Thank's Oracle. " >> ${TMPDIR}.debug	
		#
		
	fi
	touch ${TMPDIR}.running
	cat ${TMPDIR}.tmp > ${TMPDIR}
	rm -f ${TMPDIR}.running
fi

# DEBUG PURPOSE ONLY
echo "`date` `cat ${TMPDIR} | head -2 | tail -1`; Nbr Line:`cat ${TMPDIR} | wc -l`; MD5=`md5sum ${TMPDIR} | cut -d' ' -f1`" >> ${TMPDIR}.debug

# /DEBUG
