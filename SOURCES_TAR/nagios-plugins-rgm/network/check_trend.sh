#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

usage() {
echo "Usage :check_trend_mailqueue.sh
	-H hostname
	-w Warning
	-c CRITICAL"
exit 2
}

if [ "${6}" = "" ]; then usage; fi

ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HOSTTARGET="`echo ${i} | cut -c 3-`"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-w"`" ]; then WARNING="`echo ${i} | cut -c 3-`"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-c"`" ]; then CRITICAL="`echo ${i} | cut -c 3-`"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done

#if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
#TMPDIR="`mktemp -d /tmp/tmp-internal/trend_MailQueue-internal.XXXXXXXX`"

MailQueue="`snmpwalk -v 2c -c leon $HOSTTARGET .1.3.6.1.4.1.2021.06| grep "101" | cut -d'=' -f2 | cut -d':' -f2 | sed -e 's:"::g' | awk '{printf ("%d",$1);}'`"


if [ "$MailQueue" -lt "$WARNING" ]
then
echo "OK: $MailQueue mails dans l'antispam. | MailQueue=$MailQueue;$WARNING;$CRITICAL"
exit 0

elif [ "$MailQueue" -ge "$WARNING" ] && [ "$MailQueue" -lt "$CRITICAL" ]
then
echo "WARNING: $MailQueue mails dans l'antispam. | MailQueue=$MailQueue;$WARNING;$CRITICAL"
exit 1

else [ "$MailQueue" -ge "$CRITICAL" ]
echo "CRITICAL: $MailQueue mails dans l'antispam. | MailQueue=$MailQueue;$WARNING;$CRITICAL"
exit 2
fi

