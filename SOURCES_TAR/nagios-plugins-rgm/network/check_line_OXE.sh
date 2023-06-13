#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

TEST="$((echo open $1
sleep 1
echo "mtcl"
#sleep 1
#echo "gestionPABX"
sleep 20
echo "trkstat 3 2"
sleep 2
exit
) | telnet 2> /dev/null |  sed "s/^ *//;s/ *$//;s/ \{1,\}/ /g")"

STATE="$(echo "$TEST" | grep "State" | cut -d' ' -f3 | cut -d' ' -f$2)"

if [ "$STATE" = "B" ]; then
	printf %d 1
	exit
fi
printf %d 0
