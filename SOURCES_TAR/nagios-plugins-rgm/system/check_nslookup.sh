#! /bin/sh
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

HOSTFOUND="`host $1 | grep "address" | grep -v "SERVFAIL"`"

if [  -n "$HOSTFOUND" ]
then
echo "OK: $HOSTFOUND"
exit 0
else
echo "CRITICAL: Host $1 does'nt exist in dns"
exit $STATE_CRITICAL
fi
