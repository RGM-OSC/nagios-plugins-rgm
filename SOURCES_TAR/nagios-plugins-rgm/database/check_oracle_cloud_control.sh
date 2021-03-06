#!/bin/bash

export LANG="en_US.UTF-8"

export PLUGIN_PATH="/srv/eyesofnetwork/nagios/plugins"
export EXIT_OK=0
export EXIT_WARNING=1
export EXIT_CRITICAL=2
export EXIT_UNKNOWN=3


usage() {
echo "Usage :check_check_cloud_control.sh
        -u username
	-s password
	-h hostname
        -p port
        -b database" 
exit 2
}

#if [ "${10}" = "" ]; then usage; fi

while getopts u:s:h:p:b: OPTION
do
case $OPTION in
         u)
                USER=$OPTARG
             ;;
         s)
                PASSWORD=$OPTARG
             ;;
         h)
		HOST=$OPTARG
             ;;
         p)
		PORT=$OPTARG
             ;;
         b)
		DBNAME=$OPTARG
             ;;
	?)
             usage
             exit
             ;;
 esac
done

#RequestA="select * from ( select substr(d.message_text,1,instr(d.message_text,' ')-1 ) erreur_oracle, to_char(cast(D.ORIGINATING_TIMESTAMP as date),'DD/MM/YYYY HH24:MI:SS')||':'|| substr(D.MESSAGE_TEXT,1,57)||':'||D.problem_key message_erreur,decode (sign(1 - ((sysdate  - cast(D.ORIGINATING_TIMESTAMP as date))*24)),1,'CRITICAL','WARNING') criticite from SYS.V_\$DIAG_ALERT_EXT d where  message_text like 'ORA-%' and  cast(D.ORIGINATING_TIMESTAMP as date) > sysdate - 1 and component_id = 'rdbms' order by 1 desc  ) where rownum = 1;"

#RequestA=" select statut Analyse_Backup_RMAN from ( select backup_type, incremental_level, round(sum(original_input_bytes)/1024/1024/1024,2) GB_in, round(sum(output_bytes)/1024/1024/1024,2) GB_out, decode (status,'A','Available','CRITICAL: status='||status) statut, min(to_char(start_time,'YYYY/MM/DD HH24:MI')) date_debut, max(to_char(completion_time,'YYYY/MM/DD HH24:MI')) date_fin from v\$backup_set_details where start_time > sysdate - 1 group by backup_type, incremental_level, status, session_key, session_recid, session_stamp) where statut ='Error' union all select decode (count(*),0, 'WARNING:Pas de backup depuis 24h','OK') backups_OK from ( select to_char(completion_time,'YYYY/MM/DD') date_backup from v\$backup_set_details where start_time > sysdate -1 and status = 'A' group by  to_char(completion_time,'YYYY/MM/DD') order by to_char(completion_time,'YYYY/MM/DD') desc)

cd /tmp/tmp-internal-Solaris/infos_solaris
crit=''
if [ `grep "Down" $HOST.grid.log|wc -l` -ge 1 ]; then
  crit=CRITICAL ;
fi 

if [ `grep "Up" $HOST.grid.log|wc -l` -eq 3 ]; then
  crit=OK ;
fi


#path="/srv/eyesofnetwork/nagios/plugins/error_rman_${HOST}_${DBNAME}.txt"

#echo "${RequestA}" | sqlplus $USER/$PASSWORD'@'$HOST':'$PORT/$DBNAME > $path

#crit=`cat $path | egrep 'OK|WARNING|CRITICAL'`

if [  "$crit" != '' ]; then
	
	if [ "$crit" == "WARNING" ]; then
		echo "$crit"
		exit "$EXIT_WARNING"

	elif [ "$crit" == "CRITICAL" ]; then
                cat $HOST.grid.log
		exit "$EXIT_CRITICAL"

	elif [ "$crit" == "OK" ]; then
		echo "No error grid detected"
                cat $HOST.grid.log
		exit "$EXIT_OK"
	fi
else
	echo 'Wrong connection'
	exit $EXIT_CRITICAL

fi
