#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

# Humidity: snmpwalk -v 1 -c public eaton9155.genoyer.com  -t 10 1.3.6.1.4.1.534.1.6.6
# Temp: snmpwalk -v 1 -c public eaton9155.genoyer.com  -t 10 1.3.6.1.4.1.534.1.6.5

usage() {
echo "Usage :check_eaton_probe.sh
	-T Type [temperature or humidity]
	-C Community
	-H Host
	-t timeout connection in seconde
	-w Warning (Rate minimum in octet/s. ex: -w 1024) enter anything even in case of data only
	-c Critical (Rate minimum in octet/s. ex: -w 1024) enter anything even in case of data only
	-D Data only"
exit 2
}

if [ "${12}" = "" ]; then usage; fi

ARGS="$(echo $@ |sed -e 's:-:\n-:g' | sed -e 's: ::g')"
for i in $ARGS; do
	if [ -n "$(echo ${i} | grep "^\-T")" ]; then TYPE="$(echo ${i} | cut -c 3-)"; if [ ! -n ${TYPE} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-C")" ]; then COMMUNITY="$(echo ${i} | cut -c 3-)"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOST="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOST} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-t")" ]; then TIMEOUT="$(echo ${i} | cut -c 3-)"; if [ ! -n ${TIMEOUT} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-w")" ]; then WARNING="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-c")" ]; then CRITICAL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-D")" ]; then DATA="data"; if [ ! -n ${DATA} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
TMPDIR="$(mktemp -d /tmp/tmp-internal/ups.XXXXXXXX)"



if [ "$TYPE" = "temperature" ]; then
	/usr/bin/snmpwalk -v 1 -Oa -Ov -Ln -c ${COMMUNITY} -t ${TIMEOUT} ${HOST} 1.3.6.1.4.1.534.1.6.5 | cut -d':' -f2 |sed -e 's: ::g' > $TMPDIR/out.txt
else
	/usr/bin/snmpwalk -v 1 -Oa -Ov -Ln -c ${COMMUNITY} -t ${TIMEOUT} ${HOST} 1.3.6.1.4.1.534.1.6.6 | cut -d':' -f2 |sed -e 's: ::g' > $TMPDIR/out.txt
fi

VALUE="$(cat $TMPDIR/out.txt | head -1)"

if [ ! -n "$(echo $VALUE | grep -v "[a-Z]")" ]; then
	echo "CRITICAL: SNMP Response inadapted."
	rm -rf ${TMPDIR}
	exit 2
fi

if [ "$DATA" = "data" ]; then
	printf "%s" $VALUE
	rm -rf ${TMPDIR}
	exit
fi

if [ $VALUE -gt $CRITICAL ]; then
	echo "CRITICAL: The $TYPE exceed the limit of $CRITICAL. Currently: $VALUE"
	rm -rf ${TMPDIR}
	exit 2
fi

if [ $VALUE -gt $WARNING ]; then
	echo "CRITICAL: The $TYPE exceed the limit of $WARNING. Currently: $VALUE"
	rm -rf ${TMPDIR}
	exit 2
fi

rm -rf ${TMPDIR}
if [ "$TYPE" = "temperature" ]; then
	echo "OK: The $TYPE is ok at: $VALUE Celcius."
else
	echo "OK: The $TYPE is ok at: $VALUE%."
fi
rm -rf ${TMPDIR}
exit 0
