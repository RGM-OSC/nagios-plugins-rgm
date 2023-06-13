#!//bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'
#
# Author : Vincent FRICOU (vincent@fricouv.eu)
#
# This script is writed under GPLv3 licence
#
# Name : check_arcgis_rest.sh
# Version 1.0-build
#
# This script is created to run as nagios plugin to check ArcGIS by the RESTfull API
#
CHECKNAME="check_arcgis_rest.sh"
REVISION="0.1-build"

usage () {
echo "Usage :${CHECKNAME} ${REVISION}
        -H Host target
        -u API URI to query (See type to default URI in each case)
        -U Username to generate token
        -P Password to generate token
        -p HTTP Port which host API (Default 80)
        -f Folder of service (Corresponding to service name)
        -s Map service
		-t Type :
			- Report : Authenticated service
				Default URI : /arcgis/admin/services/report
			- Statistics : Authenticated service
				Default URI : /arcgis/admin/services/<Mapservice>.<maptype>/statistics
			- Classic : Classic REST API request, no need to be authenticate
				Default URI : /arcgis/rest/services/<folder>/<mapservice>
			- Secure : Secure REST API request. need to be authenticated
				Default URI : /arcgis/rest/services/secure/<folder>/<mapservice>
		-S Mapservice type :
			- MapServer
        "
exit 3
}

out() {
        if [ $COUNTCRITICAL -ge 1 ] || [ $COUNTWARNING -ge 1 ];then
                if [ $COUNTWARNING -ge 1 ];then
						if [ "$(echo -n "${OUTPUT}" | tr ',' '\n' | wc -l )" -gt 1 ]; then echo "Warning : click for details,"; fi
                        echo -n "${OUTPUT}," | tr ',' '\n'
                fi
                if [ $COUNTCRITICAL -ge 1 ] ; then
						if [ "$(echo -n "${OUTPUT}" | tr ',' '\n' | wc -l )" -gt 1 ]; then echo "Critical : click for details,"; fi
                        echo -n "${OUTPUT}," | tr ',' '\n'
                fi
        else
			if [ "$(echo -n "${OUTPUT}" | tr ',' '\n' | wc -l )" -gt 1 ]
			then
                echo "Ok : click for details,"
                echo -n "${OUTPUT}," | tr ',' '\n'
			else
				echo -n "${OUTPUT}"
			fi
        fi
        if [ -n "$PERF" ]; then
                echo " | ${PERF}"
        fi
        if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
        if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
        exit 0
}
parseargs() {
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-u"`" ]; then URI="`echo ${i} | cut -c 3-`"; if [ ! -n ${URI} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-U"`" ]; then USERNAME="`echo ${i} | cut -c 3-`"; if [ ! -n ${USERNAME} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-P"`" ]; then PASSWORD="`echo ${i} | cut -c 3-`"; if [ ! -n ${PASSWORD} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-p"`" ]; then PORT="`echo ${i} | cut -c 3-`"; if [ ! -n ${PORT} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-t"`" ]; then TYPEG="`echo ${i} | cut -c 3-`"; if [ ! -n ${TYPEG} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-f"`" ]; then FOLDER="`echo ${i} | cut -c 3-`"; if [ ! -n ${FOLDER} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-s"`" ]; then MAPSERVICE="`echo ${i} | cut -c 3-`"; if [ ! -n ${MAPSERVICE} ]; then usage;fi;fi
		if [ -n "`echo ${i} | grep "^\-S"`" ]; then MAPTYPE="`echo ${i} | cut -c 3-`"; if [ ! -n ${MAPTYPE} ]; then usage;fi;fi
done
}
checkargs_mandatory() {
		if [ -z ${HOSTTARGET} ] ; then printf "Missing Host target\n" ; usage ; fi
		if [ -z ${TYPEG} ] ; then printf "Missing type to check\n" ; usage ; fi
		if [[ ${TYPE} == "REPORT" || ${TYPE} == "STATISTICS" || ${TYPE} == "SECURE" ]]
		then
			if [[ ${TYPE} ==  "REPORT" || ${TYPE} == "STATISTICS" ]]
			then
				if [ -z ${USERNAME} ] ; then printf "Missing username\n" ; usage ; fi
				if [ -z ${PASSWORD} ] ; then printf "Missing password\n" ; usage ; fi
				if [ -z ${MAPTYPE} ] ; then printf "Missing map type\n" ; usage ; fi
			elif [[ ${TYPE} == "SECURE" ]]
			then
				if [ -z ${USERNAME} ] ; then printf "Missing username\n" ; usage ; fi
				if [ -z ${PASSWORD} ] ; then printf "Missing password\n" ; usage ; fi
			fi
		fi
		if [ -z ${FOLDER} ] ; then printf "Missing folder\n" ; usage ; fi
		if [ -z ${PORT} ] ; then printf "Missing HTTP port\n" ; usage ; fi
		if [ -z ${FOLDER} ] ; then printf "Missing folder to check\n" ; usage ; fi
		if [ -z ${MAPSERVICE} ] ; then printf "Missing mapservice to check\n" ; usage ; fi
}
generate_token() {
	TOKEN="$(${COMMAND} "http://${HOSTTARGET}:${PORT}/arcgis/tokens/?request=gettoken&username=${USERNAME}&password=${PASSWORD}")"
}
ARGS="$(echo $@ |sed -e 's:-[[:alpha:]] :\n&:g' | sed -e 's: ::g')"
if [ ! -n "${ARGS}" ]; then usage;fi
parseargs
if [ ! -n "${PORT}" ]; then PORT=80 ; fi
TYPE=${TYPEG^^}
if [ ! -n "${URI}" ]
then
	if [ ${TYPE} == "REPORT" ]; then URI="/arcgis/admin/services/";ENDURI="/report"; fi
	if [ ${TYPE} == "STATISTICS" ]; then URI="/arcgis/admin/services/";ENDURI="/statistics"; fi
	if [ ${TYPE} == "CLASSIC" ]; then URI="/arcgis/rest/services/"; fi
	if [ ${TYPE} == "SECURE" ]; then URI="/arcgis/rest/services/secure/"; fi
fi
checkargs_mandatory

COUNTWARNING=0
COUNTCRITICAL=0

COMMAND="/usr/bin/curl -XGET -s -g"
MAPSERVICES=$(echo "/${MAPSERVICE}")
MAPTYPES=$(echo "/${MAPTYPE}")
FORMAT="?f=json"
PARSER="/usr/bin/python -m json.tool"
case ${TYPE} in
	REPORT)
		generate_token
		JSONREQUEST="&parameters=[\"status\"]&services=[{folderName:\"${FOLDER}\",serviceName:\"${MAPSERVICE}\",type:\"${MAPTYPE}\"}]"
		QUERY="$(${COMMAND} "http://${HOSTTARGET}:${PORT}${URI}${ENDURI}${FORMAT}&token=${TOKEN}${JSONREQUEST}" | ${PARSER})"
		FILTEREDQUERY="$(echo ${QUERY}|${PARSER}|grep -e folderName -e serviceName -e configuredState -e realTimeState |sed 's/ //g')"
		QUERYFOLDER="$(echo ${FILTEREDQUERY}|tr ',' '\n'| grep -e folderName | cut -d':' -f2 | sed 's/\"//g')"
		QUERYNAME="$(echo ${FILTEREDQUERY}|tr ',' '\n'| grep -e serviceName | cut -d':' -f2 | sed 's/\"//g')"
		QUERYCONFSTATE="$(echo ${FILTEREDQUERY}|tr ',' '\n'| grep -e configuredState | cut -d':' -f2 | sed 's/\"//g')"
		QUERYREALSTATE="$(echo ${FILTEREDQUERY}|tr ',' '\n'| grep -e realTimeState | cut -d':' -f2 | sed 's/\"//g')"
		if [ -z "${FILTEREDQUERY}" ]
		then
			OUTPUT="Requested ${MAPSERVICE} not exist in reports"
		elif [ "${QUERYREALSTATE}" != "${QUERYCONFSTATE}" ]
		then
			COUNTCRITICAL=$(expr ${COUNTCRITICAL} + 1)
			OUTPUT="${OUTPUT}MapService ${QUERYNAME} in folder ${QUERYFOLDER} is in state ${QUERYREALSTATE}. Expected ${QUERYCONFSTATE},"
		else
			OUTPUT="${OUTPUT}MapService ${QUERYNAME} in folder ${QUERYFOLDER} is in state ${QUERYREALSTATE} same as expected,"
		fi
	;;
	STATISTICS)
		generate_token
		QUERY="$(${COMMAND} "http://${HOSTTARGET}:${PORT}${URI}${MAPSERVICES}.${MAPTYPE}${ENDURI}${FORMAT}&token=${TOKEN}" | ${PARSER})"
		QUERYINIT="$(echo ${QUERY} | ${PARSER} | grep initializing | cut -d':' -f 2 | sed -e 's/ //g' -e 's/\"//g' -e 's/,//g'|tail -1)"
		if [ ! -z "${QUERYINIT}" ]
		then
			if [ ${QUERYINIT} -eq 1 ]
			then
				COUNTWARNING=$(expr ${COUNTWARNING} + 1)
				OUTPUT="Instance ${MAPSERVICE} is running in initialization state"
			else
				OUTPUT="Instance ${MAPSERVICE} is running in normal state"
			fi
		else
			OUTPUT="No running instance ${MAPSERVICE}"
		fi
	;;
	SECURE)
		generate_token
		QUERY="$(${COMMAND} "http://${HOSTTARGET}:${PORT}${URI}${FOLDER}${MAPSERVICES}${FORMAT}&token=${TOKEN}" | ${PARSER} )"
		QUERYTITLE="$(echo ${QUERY}|${PARSER}| grep 'Title' | cut -d':' -f 2 | sed -e 's/^ //g' -e 's/\"//g' -e 's/,//g')"
		QUERYCODE="$(echo ${QUERY}|${PARSER}| grep 'code' | cut -d':' -f 2 | sed -e 's/ //g' -e 's/\"//g' -e 's/,//g')"
		if [ ! -z "${QUERYTITLE}" ]
		then
			OUTPUT="Service ${MAPSERVICE} in folder ${FOLDER} return title : ${QUERYTITLE}"
		else
			if [ ! -z ${QUERYCODE} ]
			then
				COUNTWARNING=$(expr ${COUNTWARNING} + 1)
				OUTPUT="Service ${MAPSERVICE} not found on secure folder ${FOLDER}"
			else
				COUNTCRITICAL=$(expr ${COUNTCRITICAL} + 1)
				OUTPUT="General failure"
			fi
		fi
	;;
	CLASSIC)
		QUERY="$(${COMMAND} "http://${HOSTTARGET}:${PORT}${URI}${FOLDER}${MAPSERVICES}${FORMAT}" | ${PARSER})"
		QUERYTITLE="$(echo ${QUERY}|${PARSER}| grep 'Title' | cut -d':' -f 2 | sed -e 's/^ //g' -e 's/\"//g' -e 's/,//g')"
		QUERYCODE="$(echo ${QUERY}|${PARSER}| grep 'code' | cut -d':' -f 2 | sed -e 's/ //g' -e 's/\"//g' -e 's/,//g')"
		if [ ! -z "${QUERYTITLE}" ]
		then
			OUTPUT="Service ${MAPSERVICE} in folder ${FOLDER} return title : ${QUERYTITLE}"
		else
			if [ ! -z ${QUERYCODE} ]
			then
				COUNTWARNING=$(expr ${COUNTWARNING} + 1)
				OUTPUT="Service ${MAPSERVICE} running on folder ${FOLDER}"
			else
				COUNTCRITICAL=$(expr ${COUNTCRITICAL} + 1)
				OUTPUT="General failure"
			fi
		fi
	;;
	*)
		usage
	;;
esac


out
