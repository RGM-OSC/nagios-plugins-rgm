#!/bin/bash


export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_foxbox.sh
	-u mysql username
	-p mysql password
	-d database
	-H Host target
	-n Sender number (Like 33123456789)"
exit 2
}

out() {
	if [ $COUNTWARNING -ge 1 ];then
		echo "Warning : click for details,"
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

ARGS=`echo $@ |sed -e 's:-[a-Z] :\n&:g' | grep -v ^'-S' | sed -e 's: ::g'`

for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-u"`" ]; then DBUSER="`echo ${i} | cut -c 3-`"; if [ ! -n ${DBUSER} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-p"`" ]; then DBPASS="`echo ${i} | cut -c 3-`"; if [ ! -n ${DBPASS} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-d"`" ]; then DB="`echo ${i} | cut -c 3-`"; if [ ! -n ${DB} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-n"`" ]; then SNUM="`echo ${i} | cut -c 3-`"; if [ ! -n ${SNUM} ]; then usage;fi;fi
done


if [ "${DBUSER}" = "" ]; then echo "Username requiered" ; usage; fi
if [ "${DBPASS}" = "" ]; then echo "Password requiered" ; usage; fi
if [ "${HOSTTARGET}" = "" ]; then echo "Host target requiered" ; usage; fi
if [ "${DB}" = "" ]; then echo "You must specify a database to bind." ; usage; fi
if [ "${SNUM}" = "" ]; then echo "You must specify sender number." ; usage; fi

COUNTWARNING=0
COUNTCRITICAL=0

NUM="From: ${SNUM}"

QUERY="SELECT msgdate FROM ${DB}.inpmsglog WHERE gsmnumber LIKE '%${NUM}%' AND message LIKE '%test%';"

SQL=$(mysql -B -h ${HOSTTARGET} -u ${DBUSER} -p${DBPASS} ${DB} -e "${QUERY}" | tail -1|cut -d':' -f2-)
TESTTS=$(date -d "${SQL}" +"%s")
NOW=$(date +"%s")

if [ ${NOW} -gt $(expr ${TESTTS} + 7200) ]
then 
	OUTPUT="Test is older than 2 hour, Last ${SQL}"
	COUNTWARNING=$(expr ${COUNTWARNING} + 1 )
elif [ ${NOW} -gt $(expr ${TESTTS} + 10800) ]
then
	OUTPUT="Test is older than 3 hour, Last ${SQL}"
	COUNTCRITICAL=$(expr ${COUNTCRITICAL} + 1 )
else
	OUTPUT="FoxBox operating normaly, Last ${SQL}"
fi

out
