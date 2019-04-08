#!/bin/bash

usage() {
echo "Usage :check_temp_mge_sensor.sh
	-H HOSTNAME
	-l login
	-p passwd
	-w Warning
	-c Critical"
exit 2
}

CODE_RETOUR=0

if [ "${10}" = "" ]; then usage; fi

if [ -d /tmp/tmp-mge-sensor ]; then rm -rf /tmp/tmp-mge-sensor; fi
TMPDIR="`mktemp -d /tmp/tmp-mge-sensor`"

cd $TMPDIR
wget -o /dev/null --http-user=${4} --http-passwd=${6} -r -l1 http://${2}/main.html?2,2 > /dev/null

SENSOR="`cat ${2}/sensors.html | grep "Deg" |cut -d ';' -f2 | cut -d'.' -f1`"
COUNT="`cat ${2}/sensors.html | grep "Deg" |cut -d ';' -f2 | cut -d'.' -f1 | wc -l`"

J="0"
while (true); do
	J="`expr $J + 1`"
	VALUE="`echo $SENSOR |cut -d' ' -f$J`"
	if [ $VALUE -gt ${10} ]; then 
		CODE_RETOUR=2
		echo -n "CRITICAL -> "
	else 
		if [ $VALUE -gt ${8} ]; then
			CODE_RETOUR=1
			echo -n "WARNING -> "
		fi
	fi
	echo -n "Sensor $J=$VALUE .C; "
	COUNT="`expr $COUNT - 1`"
	if [ $COUNT -eq 0 ]; then break; fi
done
echo ""
rm -rf $TMPDIR
exit $CODE_RETOUR

