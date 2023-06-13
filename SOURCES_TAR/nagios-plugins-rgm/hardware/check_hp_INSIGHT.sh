#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

cp /dev/null ./result_check_hp_insight.txt


for i in $(cat hosts.csv | grep ECF-WIN2K_ | cut -d';' -f1 | sort -u | grep -v "^sdo" | grep -v "^sab" | grep -v "^sot" | grep -v "^sge"); do
	ipaddr=$(grep $i hosts.csv |  cut -d';' -f3)
	hard_state=$(/srv/eyesofnetwork/nagios/plugins/check_hard_hp_server -H ${ipaddr} -C public)
	state=$?
	if [ $state -eq 0 ]; then
		echo "$i;OK"  >> ./result_check_hp_insight.txt
	fi
	if [ $state -eq 2 ]; then
		echo "$i;OK - HW PROBLEM"  >> ./result_check_hp_insight.txt
	fi
	if [ $state -eq 3 ]; then
		echo $hard_state | grep "no cpq/hp"
		echo "$i;KO"  >> ./result_check_hp_insight.txt
	fi
	echo "$i;$hard_state"
done
