#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG=en_US

usage() {
echo "Usage :check_apache_access.sh
	-u proxy [on/off]
	-p proxy URL (ex:http://proxy.medicafrance.fr:80)
	-T url to test (ex:http://www.viadeo.com)
	-t timeout connection in seconde
	-C [on/off] check certificate (default on)
	-w Warning (Rate minimum in octet/s. ex: -w 1024)
	-c Critical (Rate minimum in octet/s. ex: -w 1024)"
exit 2
}

if [ "${14}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's: -:\n-:g' | sed -e 's: ::g'`"
for i in $ARGS; do
	if [ -n "`echo ${i} | grep "^\-u"`" ]; then COMMUT_PROXY="`echo ${i} | cut -c 3-`"; if [ ! -n ${COMMUT_PROXY} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-p"`" ]; then PROXY_URL="`echo ${i} | cut -c 3-`"; if [ ! -n ${PROXY_URL} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-T"`" ]; then TEST_URL="`echo ${i} | cut -c 3-`"; if [ ! -n ${TEST_URL} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-t"`" ]; then TIMEOUT="`echo ${i} | cut -c 3-`"; if [ ! -n ${TIMEOUT} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-C"`" ]; then CERT="`echo ${i} | cut -c 3-`"; if [ ! -n ${CERT} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
	if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done


if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
TMPDIR="`mktemp -d /tmp/tmp-internal/web-internal.XXXXXXXX`"



export http_proxy=${PROXY_URL}

if [ "$CERT" == "off" ]; then
	wget -o ${TMPDIR}/wget.out -O /dev/null -t 1 -T ${TIMEOUT} --no-check-certificate -Y ${COMMUT_PROXY} ${TEST_URL}
else
	wget -o ${TMPDIR}/wget.out -O /dev/null -t 1 -T ${TIMEOUT} -Y ${COMMUT_PROXY} ${TEST_URL}
fi



BANDWIDTH="`cat ${TMPDIR}/wget.out |tail -3 | grep "/dev/null" | awk --field-separator=") " '{print $1}' | awk --field-separator="(" '{print $2}'`"

if [ -n "${BANDWIDTH}" ]; then
	VALUE_BANDWIDTH="`echo ${BANDWIDTH} | cut -d' ' -f1 | sed -e 's:,:.:g'`"
	METRIC_BANDWIDTH="`echo ${BANDWIDTH} | cut -d' ' -f2 |sed -e 's:/s::g'`"
	MULTIPLE="1"
	if [ "$METRIC_BANDWIDTH" = "GB" ] ; then MULTIPLE="1073741824" ; fi
	if [ "$METRIC_BANDWIDTH" = "MB" ] ; then MULTIPLE="1048576" ; fi
	if [ "$METRIC_BANDWIDTH" = "KB" ] ; then MULTIPLE="1024" ; fi
	VALUE_BANDWIDTH="`echo "$VALUE_BANDWIDTH*$MULTIPLE" |bc | cut -d'.' -f1`"
else
	echo "CRITICAL: Access web impossible."
	rm -rf ${TMPDIR}
	exit 2
fi

if [ "`echo "${VALUE_BANDWIDTH} < ${WARNING}" | bc`" = "1" ]; then
	if [ "`echo "${VALUE_BANDWIDTH} < ${CRITICAL}" | bc`" = "1" ]; then
		echo "CRITICAL: Bande passante insuffisante: ${BANDWIDTH}"
		rm -rf ${TMPDIR}
		exit 2
	fi
        echo "WARNING: Bande passante faible: ${BANDWIDTH}"
	rm -rf ${TMPDIR}
	exit 1
fi

rm -rf ${TMPDIR}
echo "OK: Bande passante sur ${TEST_URL} de ${BANDWIDTH}"
exit 0
