#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_gedevents.sh
	-t host, service, servicegroups, hostgroups
	-s String to look for (ex: Cam%)
	-S Complement search (ex: equipment like :colsan1a%:)
	-u mysql username
	-p mysql password
	-H Host target
	-w Warning maximum number of events
	-c Critical maximum number of events
	-W Warning maximum number of occurence
	-C Critical maximum number of occurence"
exit 2
}

#ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
ARGS=$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | grep -v ^'-S' | sed -e 's: ::g')
ARGS2="$(echo $@ | sed -e 's:-S :\n&:g' | sed -e "s/:/'/g"| grep ^'-S' | cut -c 4-)"

for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-t")" ]; then TYPE="$(echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]')"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-s")" ]; then STRINGSQL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${STRINGSQL} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-u")" ]; then USERNAME="$(echo ${i} | cut -c 3-)"; if [ ! -n ${USERNAME} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-p")" ]; then PASSWORD="$(echo ${i} | cut -c 3-)"; if [ ! -n ${PASSWORD} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-w")" ]; then WARNING="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-c")" ]; then CRITICAL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-W")" ]; then WARNINGOCC="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-C")" ]; then CRITICALOCC="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done
if [ -n "${ARGS2}" ]; then STRINGCOMPSQL="${ARGS2}"; fi


if [ "${TYPE}" = "" ]; then echo "You must set a type" ; usage; fi
if [ "${TYPE}" != "HOST" ]  && [ "${TYPE}" != "SERVICE" ] && [ "${TYPE}" != "HOSTGROUPS" ] && [ "${TYPE}" != "SERVICEGROUPS" ]; then echo "Incorrect type" ; usage; fi
if [ "${STRINGSQL}" = "" ]; then echo "String SQL required" ; usage; fi
if [ "${USERNAME}" = "" ]; then echo "Username requiered" ; usage; fi
if [ "${PASSWORD}" = "" ]; then echo "Password requiered" ; usage; fi
if [ "${HOSTTARGET}" = "" ]; then echo "Host target requiered" ; usage; fi
if [ "${CRITICAL}" = "" ] && [ "${WARNING}" = "" ] && [ "${CRITICALOCC}" = "" ] && [ "${WARNINGOCC}" = "" ]; then echo "At least a critical or a warning or a warning occurence or a critical occurence threshold is requiered" ; usage; fi

if [[ ! ${CRITICAL} =~ ^[0-9]+$ ]]; then
	CRITICAL=100000
fi
if [[ ! ${WARNING} =~ ^[0-9]+$ ]]; then
	WARNING=100000
fi
if [[ ! ${CRITICALOCC} =~ ^[0-9]+$ ]]; then
	CRITICALOCC=1
fi
if [[ ! ${WARNINGOCC} =~ ^[0-9]+$ ]]; then
	WARNINGOCC=1
fi

if [ "${WARNINGOCC}" == "1" ]; then
	WARNINGOCC="${CRITICALOCC}"
fi

if [ "${CRITICALOCC}" == "1" ]; then
	CRITICALOCC="${WARNINGOCC}"
fi

COUNTWARNING=0
COUNTCRITICAL=0


OUTPUT=" "

if [ ! -d '/tmp/check_gedevents' ]; then mkdir -p /tmp/check_gedevents ; fi
TMPFILE1=$(mktemp /tmp/check_gedevents/check_gedevents.XXXXXX)

###############################################
# Position :
# 1 = occ
# 2 = equipment
# 3 = service
# 4 = state
# 5 = ip_address
# 6 = host_alias
# 7 = hostgroups
# 8 = servicegroups
# 9 = owner
# 10 = comments
#
#mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where equipment like 'Cam%';" --batch | grep -v occ | tr '\t' ';'
##############################################

if [ ${TYPE} == 'HOST' ]; then
	#mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where equipment like '${STRINGSQL}' AND owner IS NOT NULL AND comments IS NOT NULL AND ( occ>$CRITICALOCC OR occ>$WARNINGOCC );" --batch | grep -v occ | tr '\t' ';' | tr ' ' '_'  > ${TMPFILE1}
	mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where equipment like '${STRINGSQL}' ${STRINGCOMPSQL} AND service like 'HOST%' AND owner='' AND comments='' AND ( occ>$CRITICALOCC OR occ>$WARNINGOCC );" --batch | grep -v occ | tr '\t' ';' | tr ' ' '_'  > ${TMPFILE1}

fi

if [ ${TYPE} == 'SERVICE' ]; then
	mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where service like '${STRINGSQL}' ${STRINGCOMPSQL} AND owner='' AND comments='' AND ( occ>$CRITICALOCC OR occ>$WARNINGOCC );" --batch | grep -v occ | tr '\t' ';' | tr ' ' '_'  > ${TMPFILE1}

fi

if [ ${TYPE} == 'HOSTGROUPS' ]; then
	mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where hostgroups like '${STRINGSQL}' ${STRINGCOMPSQL} AND owner='' AND comments='' AND ( occ>$CRITICALOCC OR occ>$WARNINGOCC );" --batch | grep -v occ | tr '\t' ';' | tr ' ' '_'  > ${TMPFILE1}

fi

if [ ${TYPE} == 'SERVICEGROUPS' ]; then
	mysql -u ${USERNAME} -p${PASSWORD} -e "select occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments from ged.nagios_queue_active where servicegroups like '${STRINGSQL}' ${STRINGCOMPSQL} AND owner='' AND comments='' AND ( occ>$CRITICALOCC OR occ>$WARNINGOCC );" --batch | grep -v occ | tr '\t' ';' | tr ' ' '_'  > ${TMPFILE1}

fi

STRINGSQL="$(echo ${STRINGSQL} | sed -e 's:%::g')"

if [ -n "$(cat ${TMPFILE1} | grep "ERROR")"]; then
	nb_object=0
	max_occ=0
	TMPFILE2=$(mktemp /tmp/check_gedevents/check_gedevents.XXXXXX)
	for EVENT in $(cat ${TMPFILE1}); do
			current_occ="$(echo $EVENT | cut -d';' -f1)"
			if [ $current_occ -gt $max_occ ]; then
				max_occ=$current_occ
			fi

			HOST="$(echo $EVENT | cut -d';' -f2)"
			if [ ${TYPE} == 'HOST' ] || [ $TYPE == 'HOSTGROUPS' ]; then
				if [ ! -n "$(cat ${TMPFILE2} | grep ${HOST})" ]; then
					nb_object=$(expr $nb_object + 1)
					echo $EVENT | cut -d';' -f1,2,3,5,6,7 | tr ';' ' ' | sed -e s/$/,/g >> ${TMPFILE2}
				fi
			else
				nb_object=$(expr $nb_object + 1)
				echo $EVENT | cut -d';' -f1,2,3,5,6,7 | tr ';' ' ' | sed -e s/$/,/g >> ${TMPFILE2}
			fi
	done

	cur_crit_occ=0
	cur_warn_occ=0

	if [ ${max_occ} -gt ${CRITICALOCC} ] && [ ${CRITICALOCC} != "1" ]; then
		cur_crit_occ=1
	fi

	if [ $max_occ -gt ${WARNINGOCC} ] && [ ${WARNINGOCC} != "1" ]; then
		cur_warn_occ=1
	fi

	if [ ${nb_object} -gt ${CRITICAL} ] || [ $cur_crit_occ == "1" ]; then
		COUNTCRITICAL=1
		if [ ${TYPE} == 'HOST' ] || [ $TYPE == 'HOSTGROUPS' ]; then
			OUTPUT="$(cat ${TMPFILE2} | awk '{printf ("Equipement %s ayant pour adresse %s est en erreur depuis %d cycle de notifications, ",$2,$4,$1);}')"
		else
			OUTPUT="$(cat ${TMPFILE2} | awk '{printf ("Le service %s de %s ayant pour adresse %s est en erreur depuis %d cycle de notifications, ",$3,$2,$4,$1);}')"
		fi
	else
		if [ ${nb_object} -gt ${WARNING} ] || [ $cur_warn_occ == "1" ]; then
			COUNTWARNING=1
			if [ ${TYPE} == 'HOST' ] || [ $TYPE == 'HOSTGROUPS' ]; then
				OUTPUT="$(cat ${TMPFILE2} | awk '{printf ("Equipement %s ayant pour adresse %s est en erreur depuis %d cycle de notifications, ",$2,$4,$1);}')"
			else
				OUTPUT="$(cat ${TMPFILE2} | awk '{printf ("Le service %s de %s ayant pour adresse %s est en erreur depuis %d cycle de notifications, ",$3,$2,$4,$1);}')"
			fi
		else
			OUTPUT="OK: Les evenements sans prise en charge concernant ${STRINGSQL} sont d'un volume et/ou d'un temps plus petits que les valeurs attendues."
		fi
	fi
else
	COUNTCRITICAL=1
	OUTPUT="CRITICAL: ${STRINGSQL} is in error. Click here for detail, $(cat ${TMPFILE1}) "
fi



if [ $(echo $OUTPUT | tr ',' '\n' | wc -l) -gt 1 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
fi



echo -n "$OUTPUT" | tr ',' '\n'
echo " | ${STRINGSQL}=$nb_object;;;; ${STRINGSQL}_occ=$max_occ"

rm -rf ${TMPFILE1}
rm -rf ${TMPFILE2}

if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0
