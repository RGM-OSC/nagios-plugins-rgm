#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

name_vcenter=$(/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H $1 -C "cat /etc/vmsyslog.conf | tail -2 | grep -v ^$ | cut -d"/" -f3
")

cmd=$(/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H $1 -C "nc -uz $name_vcenter 902")

echo $cmd | grep -q "succeeded"
retval=$?

if [ "$retval" = 0 ]; then
        echo "OK, connection on Vcenter $name_vcenter port UDP 902 succeeded."
        exit 0
else
        echo "CRITICAL, no response from Vcenter $name_vcenter on port UDP 902."
        exit 2
fi

