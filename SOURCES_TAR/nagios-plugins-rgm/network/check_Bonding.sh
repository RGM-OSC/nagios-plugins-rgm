#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

usage() {
echo "Usage :check_Bonding.sh
        -H hostname or ipaddr"
exit 2
}

if [ "${2}" = "" ]; then usage; fi

while getopts H: OPTION
do
case $OPTION in
         H)
             HOSTNAME=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
 esac
done

cmd=$(/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H $HOSTNAME -t 10 -C "exploit/check_linux_bonding --ignore-num-ad")

echo $cmd | grep -q "2 slaves"
ret=$?

if [[ $ret != 0 ]]; then
	echo "CRITICAL, $cmd"
	exit 2
else
	echo "OK, $cmd"
	exit 0
fi
