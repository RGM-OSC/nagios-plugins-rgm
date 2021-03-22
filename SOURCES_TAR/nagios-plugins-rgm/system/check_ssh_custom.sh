#!/bin/bash
# Check custom made by Vincent FRICOU
# To check ssh port on switch but without mount a critical state

CHECK=/srv/eyesofnetwork/nagios/plugins/check_tcp
HOSTADDRESS=$1
PORT=$2


${CHECK} -H ${HOSTADDRESS} -p ${PORT} 2>&1 >/dev/null
if [ $? == 0 ]
then
	echo "$(${CHECK} -H ${HOSTADDRESS} -p ${PORT})"
	exit 0
else
	echo "Specified port ${PORT} on ${HOSTADDRESS} isn't available"
	exit 1
fi
