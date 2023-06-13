#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_vplex.sh
        -u
        -p
        -H Host target
        -t Type : ehealth (For engine health status), DIRECTORS (directors global health),
        DIRTHRESHOLD (directors sensors threshold), FANS (fans global status),
        FANSTHRESHOLD (fans sensors threshold), MGMTMD (mgmt modules global health),
        PSU (PSU global health), PSUTHRESHOLD (PSU sensors threshold), PSUDC (PSU battery state),
        SBPSU (stand by PSU global status), SBPSUCOND (switch cycle test result)
        "
exit 2
}

out() {
	if [ $(echo $OUTPUT | tr ',' '\n' | wc -l) -gt 1 ] ;then
		if [ $COUNTCRITICAL -gt 0 ] ; then
			if [ $COUNTWARNING -gt 0 ] && [ $COUNTCRITICAL -le 0 ];then
				echo "Warning : click for details,"
				echo -n "$OUTPUT," | tr ',' '\n'
				#echo " | "
				rm -f ${TMPDIR}/engine-*/*_*
				exit 1
			fi
			echo "Critical : click for details,"
			echo -n "$OUTPUT," | tr ',' '\n'
			rm -f ${TMPDIR}/engine-*/*_*
			exit 2
		fi
	fi
	echo "Ok : click for details,"
	echo -n "$OUTPUT," | tr ',' '\n'
	##echo " | ConfiguredMask=$CONFMASK;;$NMASKCOUNT"
	rm -f ${TMPDIR}/engine-*/*_*
	exit 0
}


ARGS=$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')
for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-u")" ]; then USERNAME="$(echo ${i} | cut -c 3-)"; if [ ! -n ${USERNAME} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-p")" ]; then PASSWORD="$(echo ${i} | cut -c 3-)"; if [ ! -n ${PASSWORD} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-t")" ]; then TYPE="$(echo ${i^^} | cut -c 3-)"; if [ ! -n ${TYPE} ]; then usage;fi;fi
done

if [ "${USERNAME}" = "" ]; then echo "Username requiered (-u)"; exit 2; fi
if [ "${PASSWORD}" = "" ]; then echo "Password requiered (-p)"; exit 2; fi
if [ "${HOSTTARGET}" = "" ]; then echo "Host target requiered (-H)"; exit 2; fi
if [ "${TYPE}" = "" ]; then echo "Type requiered (-t)"; exit 2; fi

TMPDIR="/tmp/check_vplex/${HOSTTARGET}"
COUNTCRITICAL=0
COUNTWARNING=0

# Get list of vPlex engines
if [ ! -f ${TMPDIR}/engines-list ] || [ ! -n $(find ${TMPDIR}/engines-list -mtime 1) ]; then
	echo "$(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines" | grep engine- | cut -d '"' -f 4)" > ${TMPDIR}/engines-list
fi
ENGINES=$(cat ${TMPDIR}/engines-list)
for ENGINE in $(echo $ENGINES); do
	mkdir -p /tmp/check_vplex/${HOSTTARGET}/${ENGINE}
done


if [ ${TYPE} == "EHEALTH" ] ; then
	#NB_ENGINE=`cat $ENGINES | wc -l`
	for ENGINE in $ENGINES ; do
		echo "${ENGINE}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}" |  grep -A 1 -e health-state -e operational-status | cut -d'"' -f 4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/engine_global_health
		sed -i -e "s/:--:/;/g" ${TMPDIR}/${ENGINE}/engine_global_health -e "s/:$/;/" ${TMPDIR}/${ENGINE}/engine_global_health -e "s/\n/;/g" ${TMPDIR}/${ENGINE}/engine_global_health

		if [ $(cat ${TMPDIR}/${ENGINE}/engine_global_health | cut -d';' -f 1,2 | cut -d':' -f 2) != "ok" ]; then
			COUNTCRITICAL=$(expr $COUNTCRITICAL + 1)
		fi
		if [ $(cat ${TMPDIR}/${ENGINE}/engine_global_health | cut -d';' -f 1,3 | cut -d':' -f 2) != "online" ]; then
			COUNTCRITICAL=$(expr $COUNTCRITICAL + 1)
		fi
	done
	OUTPUT="$(cat ${TMPDIR}/engine-*/engine_global_health | tr ';' ' ')"
fi

if [ ${TYPE} == "DIRECTORS" ]; then
	NB_DIRECTOR=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/directors-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/directors-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/directors" | grep director- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/directors-list
		fi
		DIRECTORS=$(cat ${TMPDIR}/${ENGINE}/directors-list | tr ';' '\n')
		for DIRECTOR in $DIRECTORS ; do
			NB_DIRECTOR=$(expr $NB_DIRECTOR + 1)
			echo "${DIRECTOR}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/directors/${DIRECTOR}" | grep -A 2 -e communication-status -e health-state -e operational-status | sed -e "/},/d" -e "/\[$/d" -e 's/"//g' -e "s/ //g" -e "s/,/:/g" | cut -d':' -f2- | tr '\n' ';')" >> ${TMPDIR}/${ENGINE}/director_global_state
			sed -i -e "s/;--;/;/g" -e "s/;$//" -e "s/:;/:/g" ${TMPDIR}/${ENGINE}/director_global_state
			if [ $(cat ${TMPDIR}/${ENGINE}/director_global_state | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "ok" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
			if [ $(cat ${TMPDIR}/${ENGINE}/director_global_state | tail -1 | cut -d';' -f 3| cut -d':' -f2) != "ok" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
			if [ $(cat ${TMPDIR}/${ENGINE}/director_global_state | tail -1 | cut -d';' -f 4| cut -d':' -f2) != "ok" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_DIRECTOR / 2) ]; then
		COUNTCRITICAL=1
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/director_global_state | tr ';' ' '| sed "s/ $/,/g")"
fi

if [ ${TYPE} == "DIRTHRESHOLD" ]; then
	NB_DIRECTOR=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/directors-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/directors-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/directors" | grep director- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/directors-list
		fi
		DIRECTORS=$(cat ${TMPDIR}/${ENGINE}/directors-list | tr ';' '\n')
		for DIRECTOR in $DIRECTORS ; do
			NB_DIRECTOR=$(expr $NB_DIRECTOR + 1)
			echo "${DIRECTOR}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/directors/${DIRECTOR}" | grep -A 1 -e temperature-threshold-exceeded -e voltage-threshold-exceeded | cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/director_threshold
			sed  -i -e "s/:--:/;/g" -e "s/:$/;/" -e "s/\n/;/g" ${TMPDIR}/${ENGINE}/director_threshold
			if [ $(cat ${TMPDIR}/${ENGINE}/director_threshold | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "false" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
			if [ $(cat ${TMPDIR}/${ENGINE}/director_threshold | tail -1 | cut -d';' -f 3| cut -d':' -f2) != "false" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_DIRECTOR / 2) ]; then
		COUNTCRITICAL=1
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/director_threshold | tr ';' ' ')"
fi

if [ ${TYPE} == "FANS" ]; then
	NB_FAN=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/fans-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/fans-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/fans" | grep fan- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/fans-list
		fi
		FANS=$(cat ${TMPDIR}/${ENGINE}/fans-list | tr ';' '\n')
		for FAN in $FANS ; do
			NB_FAN=$(expr $NB_FAN + 1)
			echo "${FAN}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/fans/${FAN}" | grep -A 1 -e operational-status |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/fan_global_state
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/fan_global_state
			if [ $(cat ${TMPDIR}/${ENGINE}/fan_global_state | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "online" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_FAN / 2) ]; then
		COUNTCRITICAL=1
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/fan_global_state | tr ';' ' ')"
fi

if [ ${TYPE} == "FANSTHRESHOLD" ]; then
	NB_FAN=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/fans-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/fans-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/fans" | grep fan- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/fans-list
		fi
		FANS=$(cat ${TMPDIR}/${ENGINE}/fans-list | tr ';' '\n')
		for FAN in $FANS ; do
			NB_FAN=$(expr $NB_FAN + 1)
			echo "${FAN}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/fans/${FAN}" | grep -A 1 -e speed-threshold-exceeded |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/fan_threshold
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/fan_threshold
			if [ $(cat ${TMPDIR}/${ENGINE}/fan_threshold | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "false" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_FAN / 2) ]; then
		COUNTCRITICAL=1
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/fan_threshold | tr ';' ' ')"
fi

if [ ${TYPE} == "MGMTMOD" ]; then
	NB_MGMTMOD=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/mgmtmods-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/mgmtmods-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/mgmt-modules" | grep mgmt-module- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/mgmtmods-list
		fi
		MGMTMODS=$(cat ${TMPDIR}/${ENGINE}/mgmtmods-list| tr ';' '\n')
		for MGMTMOD in $MGMTMODS ; do
			NB_MGMTMOD=$(expr $NB_MGMTMOD + 1)
			echo "${MGMTMOD}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/mgmt-modules/${MGMTMOD}" | grep -A 1 -e operational-status |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/mgmtmod_global_state
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/mgmtmod_global_state
			if [ $(cat ${TMPDIR}/${ENGINE}/mgmtmod_global_state | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "online" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_MGMTMOD / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/mgmtmod_global_state | tr ';' ' ')"
fi

if [ ${TYPE} == "PSU" ]; then
	NB_PSU=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/psus-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/psus-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies" | grep power-supply- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/psus-list
		fi
		PSUS=$(cat ${TMPDIR}/${ENGINE}/psus-list| tr ';' '\n')
		for PSU in $PSUS ; do
			NB_PSU=$(expr $NB_PSU + 1)
			echo "${PSU}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies/${PSU}" | grep -A 1 -e operational-status |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/psu_global_state
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/psu_global_state
			if [ $(cat ${TMPDIR}/${ENGINE}/psu_global_state | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "online" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_PSU / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/psu_global_state | tr ';' ' ')"
fi

if [ ${TYPE} == "PSUDC" ]; then
	NB_PSU=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/psus-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/psus-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies" | grep power-supply- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/psus-list
		fi
		PSUS=$(cat ${TMPDIR}/${ENGINE}/psus-list| tr ';' '\n')
		for PSU in $PSUS ; do
			NB_PSU=$(expr $NB_PSU + 1)
			echo "${PSU}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies/${PSU}" | grep -A 1 -e onDC |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/psu_DC
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/psu_DC
			if [ $(cat ${TMPDIR}/${ENGINE}/psu_DC | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "false" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_PSU / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/psu_DC | tr ';' ' ' )"
fi

if [ ${TYPE} == "PSUTHRESHOLD" ]; then
	NB_PSU=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/psus-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/psus-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies" | grep power-supply- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/psus-list
		fi
		PSUS=$(cat ${TMPDIR}/${ENGINE}/psus-list| tr ';' '\n')
		for PSU in $PSUS ; do
			NB_PSU=$(expr $NB_PSU + 1)
			echo "${PSU}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/power-supplies/${PSU}" | grep -A 1 -e temperature-threshold-exceeded |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/psu_threshold
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" ${TMPDIR}/${ENGINE}/psu_threshold
			if [ $(cat ${TMPDIR}/${ENGINE}/psu_threshold | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "false" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_PSU / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/psu_threshold | tr ';' ' ')"
fi

if [ ${TYPE} == "SBPSU" ]; then
	NB_SBPSU=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/sbpsus-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/sbpsus-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/stand-by-power-supplies" | grep power-supply- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/sbpsus-list
		fi
		SBPSUS=$(cat ${TMPDIR}/${ENGINE}/sbpsus-list| tr ';' '\n')
		for SBPSU in $SBPSUS ; do
			NB_SBPSU=$(expr $NB_SBPSU + 1)
			echo "${SBPSU}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/stand-by-power-supplies/${SBPSU}" | grep -A 1 -e operational-status -e battery-status|  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/sbpsu_global_state
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" -e "s/ seconds/_seconds/g" ${TMPDIR}/${ENGINE}/sbpsu_global_state
			if [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_global_state | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "fully-charged" ]; then
				COUNTWARNING=1
			fi
			if [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_global_state | tail -1 | cut -d';' -f 3 | cut -d':' -f2) != "online" ]; then
				COUNTWARNING=$(expr $COUNTWARNING + 1)
			fi
		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_SBPSU / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$(cat ${TMPDIR}/engine-*/sbpsu_global_state | tr ';' ' ')"
fi

if [ ${TYPE} == "SBPSUCOND" ]; then
	NB_SBPSU=0
	for ENGINE in $ENGINES ; do
		if [ ! -f ${TMPDIR}/${ENGINE}/sbpsus-list ] || [ ! -n $(find ${TMPDIR}/${ENGINE}/sbpsus-list -mtime 1) ]; then
			echo $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/stand-by-power-supplies" | grep power-supply- | cut -d'"' -f 4 | tr '\n' ';') >> ${TMPDIR}/${ENGINE}/sbpsus-list
		fi
		SBPSUS=$(cat ${TMPDIR}/${ENGINE}/sbpsus-list| tr ';' '\n')
		for SBPSU in $SBPSUS ; do
			NB_SBPSU=$(expr $NB_SBPSU + 1)
			echo "${SBPSU}; $(curl -s -k -H Username:$USERNAME -H Password:$PASSWORD "https://$HOSTTARGET/vplex/engines/${ENGINE}/stand-by-power-supplies/${SBPSU}/conditioning" | grep -A 1 -e enabled -e in-progress -e previous-cycle-result |  cut -d'"' -f4 | tr '\n' ':')" >> ${TMPDIR}/${ENGINE}/sbpsu_conditioning
			sed -i -e "s/:--:/;/g" -e "s/:$/;/" -e "s/ seconds/_seconds/g" ${TMPDIR}/${ENGINE}/sbpsu_conditioning

			if [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f 2 | cut -d':' -f2) == "true" ] && [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f3 | cut -d':' -f2) == "false" ]; then
				if [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f 4 | cut -d':' -f2) != "PASS" ]; then
					COUNTWARNING=1
				fi
			elif [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f 2 | cut -d':' -f2) == "true" ] && [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f3 | cut -d':' -f2) != "false" ]; then
				OUTPUT="Conditioning test is running,"
			elif [ $(cat ${TMPDIR}/${ENGINE}/sbpsu_conditioning | tail -1 | cut -d';' -f 2 | cut -d':' -f2) != "true" ]; then
				COUNTWARNING=1
			fi

		done
	done
	if [ $COUNTWARNING -gt $(expr $NB_SBPSU / 2) ]; then
		COUNTCRITICAL=2
	fi
	OUTPUT="$OUTPUT$(cat ${TMPDIR}/engine-*/sbpsu_conditioning | tr ';' ' ')"
fi
out
