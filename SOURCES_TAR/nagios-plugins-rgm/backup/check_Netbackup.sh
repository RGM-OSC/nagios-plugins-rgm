#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

usage() {
echo "Usage :check_Netbackup.sh
        -H hostname or ipaddr
        -C check name (DB, DiskPool, DriveDown, PendingRequest, PluginOST, PeripheralDD9500, InventoryLibrary, Ano, Processes)"
exit 2
}

if [ "${4}" = "" ]; then usage; fi

while getopts H:C:N: OPTION
do
case $OPTION in
         H)
                HOSTNAME=$OPTARG
             ;;
         C)
                CHECK=$OPTARG
             ;;
	 N)
                NUMBER=$OPTARG
             ;;
        ?)
             usage
             exit
             ;;
 esac
done

if [[ $CHECK == "Processes" ]]; then
	cmd=$(/srv/eyesofnetwork/nagios/plugins/check_by_ssh -f -t 120 -H $HOSTNAME -C "/home/nagios/exploit/check_$CHECK.py $NUMBER")
else
	cmd=$(/srv/eyesofnetwork/nagios/plugins/check_by_ssh -f -t 120 -H $HOSTNAME -C /home/nagios/exploit/check_$CHECK.sh)
fi

if [[ $CHECK == "DriveDown" ]]; then
	if [[ $cmd == "" ]]; then
		echo "OK, All Drives is UP."
		exit 0
	else
		echo "CRITICAL, awesome Drives are DOWN. Click for details\n${cmd}"
		exit 2
	fi
fi

if [[ $CHECK == "DB" ]]; then
	echo ${cmd} | grep -q "Database \[NBDB\] is alive and well on server"

	retval=$?
	if [[ $retval == 0 ]]; then
        	echo "OK, Netbackup DB is Alive!"
        	exit 0

	else
        	echo "CRITICAL, Netbackup Database is not Alive!"
        	exit 2
	fi
fi

if [[ $CHECK == "PendingRequest" ]]; then
	echo $cmd | grep -q "No Pending request"
	retval=$?

	if [[ $retval != 0 ]]; then
		echo $cmd | sed -e "s/- Pending request //g"
        	#echo $cmd | awk '{ print substr($0, index($0,$13)) }'
        	exit 2
	else
        	echo "OK, no request pending"
        	exit 0
	fi
fi

if [[ $CHECK == "Ano" ]]; then
        echo $cmd |sed 's/-------------------------------------/\n/g'
        #retval=$?

        if [[ $retval != 0 ]]; then
                echo $cmd
                #echo $cmd | awk '{ print substr($0, index($0,$13)) }'
                exit 2
        else
                echo "OK, no Anomalie"
                exit 0
        fi
fi






if [[ $CHECK == "DiskPool" ]]; then
	total=$(printf "$cmd" | awk '{ print $4 }' | wc -l)
	counter=0
	output=""
	critical=0

	while [ $counter -lt $total ]; do
		let counter++
		if [[ $counter == 1 ]]; then
			state=$(echo "$cmd" | awk '{ print $4 }' | head -$counter)
		else
			state=$(echo "$cmd" | awk '{ print $4 }' | head -$counter | tail -1)
		fi

		if [[ $counter == 1 ]]; then
            		first=$(printf "$cmd" | awk '{ print $1 }' | head -$counter)
            		second=$(printf "$cmd" | awk '{ print $2 }' | head -$counter)
            		third=$(printf "$cmd" | awk '{ print $3 }' | head -$counter)
			four=$(printf "$cmd" | awk '{ print $5 }' | head -$counter)
        	else
            		first=$(printf "$cmd" | awk '{ print $1 }' | head -$counter | tail -1)
            		second=$(printf "$cmd" | awk '{ print $2 }' | head -$counter | tail -1)
            		third=$(printf "$cmd" | awk '{ print $3 }' | head -$counter | tail -1)
            		four=$(printf "$cmd" | awk '{ print $5 }' | head -$counter | tail -1)
       	 	fi
		#output=$(printf "%s%s %s %s, used :%s\n" "$output" "$first" "$second" "$third" "$four")
		if [[ $state == 0 || $four -gt 90 ]]; then
                        critical=1
			output="$output CRITICAL, $first $second $third, used :$four%\n"
		else
			output="$output OK, $first $second $third, used :$four%\n"
                fi
	done

	if [[ $critical == 0 ]]; then
		echo "OK, all disks is in OK state, click for details\n$output"
		exit 0
	else
		printf "CRITICAL, awesome disks have KO state, click for details\n%s\n" "$output"
		exit 2
	fi
fi

if [[ $CHECK == "PluginOST" ]]; then
	if [[ $cmd == 0 ]]; then
		echo "OK, Plugin OST loaded"
		exit 0
	else
		echo "CRITICAL, Plugin OST not loaded"
		exit 2
	fi
fi

if [[ $CHECK == "PeripheralDD9500" ]]; then
	if [[ $cmd == $NUMBER ]]; then
		echo "OK, all peripherals present ($NUMBER)"
		exit 0
	else
		echo "CRITICAL, $cmd peripherals present instead of $NUMBER"
		exit 2
	fi
fi

if [[ $CHECK == "DriveSharedUsage" ]]; then
        if [[ $cmd == "ok" ]]; then
                echo "OK, no drives shared in usage"
                exit 0
        else
                echo "CRITICAL, somes drives shared in usage, click for details\n$cmd"
                exit 2
        fi
fi

if [[ $CHECK == "FrozenTape" ]]; then
        if [[ $cmd == "ok" ]]; then
                echo "OK, no tapes frozen"
                exit 0
        else
                echo "CRITICAL, somes tapes frozen, click for details\n$cmd"
                exit 2
        fi
fi

if [[ $CHECK == "DriveCleaning" ]]; then
        if [[ $cmd == "ok" ]]; then
                echo "OK, no drives to clean"
                exit 0
        else
                echo "CRITICAL, somes drives to clean, click for details\n$cmd"
                exit 2
        fi
fi

if [[ $CHECK == "MediaServerStatus" ]]; then
        if [[ $cmd == "ok" ]]; then
                echo "OK, all media-server are UP"
                exit 0
        else
                echo "CRITICAL, somes media-server are DOWN. Click for details\n$cmd"
                exit 2
        fi
fi

if [[ $CHECK == "Processes" ]]; then
	echo $cmd
	echo $cmd | grep -q CRITICAL
	ret=$?
	if [[ $ret == 0 ]]; then
		exit 2
	else
		exit 0
	fi
fi

if [[ $CHECK == "InventoryLibrary" ]]; then
	STATE=0
	echo "$cmd" | sed "1,4d" > /tmp/file_netbackup_$HOSTNAME
	while read line; do
		nb_actually_tape=$(echo $line | awk '{ print $4 }')
		nb_desire_tape=$(echo $line | awk '{ print $7 }')

		if [ $nb_actually_tape -lt $nb_desire_tape ]; then
			STATE=2
		fi

	done < /tmp/file_netbackup_$HOSTNAME

	if [[ $STATE == 0 ]]; then
		echo "OK, click for details"
	else
		echo "CRITICAL, click for details"
	fi
	cat /tmp/file_netbackup_$HOSTNAME
	exit $STATE
fi
