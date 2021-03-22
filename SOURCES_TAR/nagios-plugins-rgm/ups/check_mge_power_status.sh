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

if [ "${10}" = "" ]; then usage; fi

if [ -d /tmp/tmp-mge-power ]; then rm -rf /tmp/tmp-mge-power; fi
TMPDIR="`mktemp -d /tmp/tmp-mge-power`"

cd $TMPDIR
wget -o /dev/null --http-user=${4} --http-passwd=${6} -r -l1 http://${2}/main.html?2,1 > /dev/null

SENSOR="`cat ${2}/iload.html | grep "Amps" |cut -d ';' -f2 | cut -d' ' -f1`"
COUNT="`cat ${2}/iload.html | grep "Amps" |cut -d ';' -f2 | cut -d' ' -f1 | wc -l`"

J="0"

while (true); do
	J="`expr $J + 1`"
    	VALUE="`echo $SENSOR |cut -d' ' -f$J`"
        if [ ! "`echo "$VALUE >= ${10}" | bc`" = "0" ]; then
                CODE_RETOUR=2
                echo -n "CRITICAL -> "
        else
                if [ ! "`echo "$VALUE >= ${8}" | bc`" = "0" ]; then
                        CODE_RETOUR=1
                        echo -n "WARNING -> "
                fi
        fi
	echo -n "Input Load $J= `echo $SENSOR |cut -d' ' -f$J` Amps; "
	COUNT="`expr $COUNT - 1`"
	if [ $COUNT -eq 0 ]; then break; fi
done
echo ""
rm -rf ${TMPDIR}
exit 0

