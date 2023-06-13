#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

usage() {
echo "Usage :check_flexlm_users.sh
        -H hostname or ipaddr
        -C Connector"
exit 2
}

if [ "${2}" = "" ]; then usage; fi

while getopts H:C: OPTION
do
case $OPTION in
         H)
                HOSTNAME=$OPTARG
             ;;
         C)
                CONNECTOR=$OPTARG
             ;;
        ?)
             usage
             exit
             ;;
 esac
done

/srv/eyesofnetwork/nagios/plugins/lmutil lmstat -c $CONNECTOR@$HOSTNAME -a | grep -h Total

exit 0
