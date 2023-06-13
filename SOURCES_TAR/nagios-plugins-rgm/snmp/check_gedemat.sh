#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_gedemat.sh
       	-H Host target
        -w Warning Free space available (min:max)
        -c Critical Free space available (min:max)
	-p port
	-I Could be SpaceStore, UserStore, ContentStore, ConnectionPool, OpenOffice
	-n ONLY with ContentStore,
		NameSpace could be
			content for /alf_data/documents/contentstore
			alfresco for /tmp/Alfresco
			deleted for /alf_data/documents/audits/contentstore.deleted
		"
exit 2
}


if [ "${6}" = "" ]; then usage; fi

WARNING=0
CRITICAL=0
NAMESPACE="NULL"
ARGS="$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')"

for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-w")" ]; then WARNING="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-c")" ]; then CRITICAL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-p")" ]; then PORT="$(echo ${i} | cut -c 3-)"; if [ ! -n ${PORT} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-I")" ]; then INFO="$(echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]')"; if [ ! -n ${INFO} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-n")" ]; then NAMESPACE="$(echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]')"; if [ ! -n ${NAMESPACE} ]; then usage;fi;fi
done

COUNTWARNING=0
COUNTCRITICAL=0

OUTPUT=" "
VARINFO=''

if [ -n ${NAMESPACE} ]; then
	if [ ${NAMESPACE} = "CONTENT" ];then NAMESPACEREQUIRED="/alf_data/documents/contentstore";fi
	if [ ${NAMESPACE} = "ALFRESCO" ];then NAMESPACEREQUIRED="/tmp/Alfresco";fi
	if [ ${NAMESPACE} = "DELETED" ];then NAMESPACEREQUIRED="/alf_data/documents/audits/contentstore.deleted";fi
fi

ARCHIVESpacesStore="Alfresco:Index=archive/SpacesStore,Name=LuceneIndexes NumberOfDocuments ActualSize"
USERAlfrescoUserStore="Alfresco:Index=user/alfrescoUserStore,Name=LuceneIndexes NumberOfDocuments ActualSize"
ContentStore="Alfresco:Name=ContentStore,Root=$NAMESPACEREQUIRED,Type=org.alfresco.repo.content.filestore.FileContentStore SpaceTotal SpaceFree"
ConnectionPool="Alfresco:Name=ConnectionPool NumActive NumIdle MaxActive"
OpenOffice="Alfresco:Name=OpenOffice available"
JMXLocation="/srv/eyesofnetwork/nagios/plugins"

valuelimit() {
	WARNINGONE="$(echo $WARNING | cut -d':' -f1)"
        WARNINGTWO="$(echo $WARNING | cut -d':' -f2)"
        WARNINGTHREE="$(echo $WARNING | cut -d':' -f3)"
        CRITICALONE="$(echo $CRITICAL | cut -d':' -f1)"
        CRITICALTWO="$(echo $CRITICAL | cut -d':' -f2)"
        CRITICALTHREE="$(echo $CRITICAL | cut -d':' -f3)"
}

if [ "${INFO}" == "SPACESTORE" ];then
	valuelimit
	if [ ! -n ${WARNINGONE} ] || [ ! -n ${WARNINGTWO} ]; then usage;fi

	VARINFO=$(echo get -b $ARCHIVESpacesStore | java -jar $JMXLocation/jmxterm-1.0-alpha-4-uber.jar -lservice:jmx:rmi://ignored/jndi/rmi://$HOSTTARGET:$PORT/alfresco/jmxrmi -p change_asap -u controlRole -v silent -n | tr '\n' ';' | cut -d';' -f1,4 | tr ';' '\n')
	NumberOfDocuments=$(echo $VARINFO | cut -d' ' -f3)
	ActualSize=$(echo $VARINFO | cut -d' ' -f6)

	if [ ${NumberOfDocuments} -gt ${CRITICALONE} ] || [ ${ActualSize} -gt ${CRITICALTWO} ] ; then
		OUTPUT="NumberOfDocuments $NumberOfDocuments : Limit $CRITICALONE,ActualSize $ActualSize : Limit $CRITICALTWO"
                COUNTCRITICAL=1
        else
                if [ ${NumberOfDocuments} -gt ${WARNINGONE} ] || [ ${ActualSize} -gt ${WARNINGTWO} ]; then
			OUTPUT="NumberOfDocuments $NumberOfDocuments : Limit $CRITICALONE,ActualSize $ActualSize : Limit $CRITICALTWO"
                        COUNTWARNING=1
		else
			OUTPUT="NumberOfDocuments $NumberOfDocuments ,ActualSize $ActualSize "
                fi
        fi
	PERF="NumberOfDocuments=$NumberOfDocuments;$WARNINGONE;$CRITICALONE,ActualSize=$ActualSize;$WARNINGTWO;$CRITICALTWO"
fi

if [ "${INFO}" == "USERSTORE" ];then
	valuelimit
	if [ ! -n ${WARNINGONE} ] || [ ! -n ${WARNINGTWO} ]; then usage;fi

	VARINFO=$(echo get -b $USERAlfrescoUserStore | java -jar $JMXLocation/jmxterm-1.0-alpha-4-uber.jar -lservice:jmx:rmi://ignored/jndi/rmi://$HOSTTARGET:$PORT/alfresco/jmxrmi -p change_asap -u controlRole -v silent -n | tr '\n' ';' | cut -d';' -f1,4 | tr ';' '\n')
	NumberOfDocuments=$(echo $VARINFO | cut -d' ' -f3)
	ActualSize=$(echo $VARINFO | cut -d' ' -f6)

	if [ ${NumberOfDocuments} -gt ${CRITICALONE} ] || [ ${ActualSize} -gt ${CRITICALTWO} ] ; then
		OUTPUT="NumberOfDocuments $NumberOfDocuments : Limit $CRITICALONE,ActualSize $ActualSize : Limit $CRITICALTWO"
                COUNTCRITICAL=1
        else
                if [ ${NumberOfDocuments} -gt ${WARNINGONE} ] || [ ${ActualSize} -gt ${WARNINGTWO} ]; then
			OUTPUT="NumberOfDocuments $NumberOfDocuments : Limit $WARNINGONE,ActualSize $ActualSize : Limit $WARNINGTWO"
                        COUNTWARNING=1
		else
			OUTPUT="NumberOfDocuments $NumberOfDocuments,ActualSize $ActualSize"
                fi
        fi
	PERF="NumberOfDocuments=$NumberOfDocuments;$WARNINGONE;$CRITICALONE,ActualSize=$ActualSize;$WARNINGTWO;$CRITICALTWO"
fi

if [ "${INFO}" == "CONTENTSTORE" ];then
	valuelimit
	if [ ! -n ${NAMESPACE} ]; then usage ;fi

	VARINFO=$(echo get -b $ContentStore | java -jar $JMXLocation/jmxterm-1.0-alpha-4-uber.jar -lservice:jmx:rmi://ignored/jndi/rmi://$HOSTTARGET:$PORT/alfresco/jmxrmi -p change_asap -u controlRole -v silent -n | tr '\n' ';' | cut -d';' -f1,4 | tr ';' '\n')
	SpaceTotal=$(echo $VARINFO | cut -d' ' -f3)
	SpaceFree=$(echo $VARINFO | cut -d' ' -f6)

	PctFree=$(echo $SpaceFree $SpaceTotal | awk '{printf("%d",(($1*100)/$2));}' | cut -d',' -f1)
	if [ ${PctFree} -lt ${CRITICALONE} ];then
		OUTPUT="Critical : Space left on $NAMESPACEREQUIRED : $PctFree%"
		COUNTCRITICAL=1
	else
		if [ ${PctFree} -lt ${WARNINGONE} ];then
			OUTPUT="Warning : Space left on $NAMESPACEREQUIRED : $PctFree%"
			COUNTWARNING=1
		else
			OUTPUT="Ok : Space left on $NAMESPACEREQUIRED : $PctFree%"
		fi
	fi
	PERF="SpaceFree=$PctFree;$WARNINGONE;$CRITICALONE"
fi

if [ "${INFO}" == "CONNECTIONPOOL" ];then
	valuelimit
        if [ ! -n ${WARNINGONE} ] || [ ! -n ${WARNINGTWO} ]; then usage;fi

	VARINFO=$(echo get -b $ConnectionPool | java -jar $JMXLocation/jmxterm-1.0-alpha-4-uber.jar -lservice:jmx:rmi://ignored/jndi/rmi://$HOSTTARGET:$PORT/alfresco/jmxrmi -p change_asap -u controlRole -v silent -n | tr '\n' ';' | cut -d';' -f1,4 | tr ';' '\n')
	NumActive=$(echo $VARINFO | cut -d' ' -f3)
        NumIdle=$(echo $VARINFO | cut -d' ' -f6)

	if [ ${NumActive} -gt ${CRITICALONE} ] || [ ${NumIdle} -gt ${CRITICALTWO} ] ; then
                OUTPUT="Active connection $NumActive : Limit $CRITICALONE,Idle connection $NumIdle : Limit $CRITICALTWO"
                COUNTCRITICAL=1
        else
                if [ ${NumActive} -gt ${WARNINGONE} ] || [ ${NumIdle} -gt ${WARNINGTWO} ]; then
                        OUTPUT="Active connection $NumActive : Limit $WARNINGONE,Idle connection $NumIdle : Limit $WARNINGTWO"
                        COUNTWARNING=1
		else
			OUTPUT="Ok : Active connection : $NumActive,Idle connection : $NumIdle"
                fi
        fi
        PERF="ActiveConnection=$NumActive;$WARNINGONE;$CRITICALONE,NumIdle=$NumIdle;$WARNINGTWO;$CRITICALTWO"
fi

if [ "${INFO}" == "OPENOFFICE" ];then
	VARINFO=$(echo get -b $OpenOffice | java -jar $JMXLocation/jmxterm-1.0-alpha-4-uber.jar -lservice:jmx:rmi://ignored/jndi/rmi://$HOSTTARGET:$PORT/alfresco/jmxrmi -p change_asap -u controlRole -v silent -n | tr '\n' ';' | cut -d';' -f1,4 | tr ';' '\n')
	OOOState=$(echo $VARINFO | cut -d' ' -f3)

	if [ ${OOOState} == "false" ]; then
		OUTPUT="OpenOffice : Unavailable"
		COUNTCRITICAL=1
	else
		OUTPUT="OpenOffice : Available"
	fi

fi

if [ $(echo $OUTPUT | tr ',' '\n' | wc -l) -gt 2 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
fi
if [ -n "$PERF" ]; then
        OUTPUT="$OUTPUT | $PERF"
fi
echo -n "$OUTPUT" | tr ',' '\n'


if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

