#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="en_US.UTF-8"

export PLUGIN_PATH="/srv/eyesofnetwork/nagios/plugins"
export EXIT_OK=0
export EXIT_WARNING=1
export EXIT_CRITICAL=2
export EXIT_UNKNOWN=3


usage() {
echo "Usage :check_oracle_export_task.sh
        -u username
	-s password
	-h hostname
        -p port
        -b database"
exit 2
}

if [ "${10}" = "" ]; then usage; fi

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
#;"
#RequestA="select statut||' -> '||handle_name||' ['|| to_char(completion_time,'YYYY/MM/DD HH24:MI:SS')||']' resultat from ( select handle handle_name, completion_time, decode(sign(completion_time - (sysdate - (27/24))),1,'OK', decode(sign(completion_time - (sysdate - 5)),1,'WARNING','CRITICAL')) statut from v\$backup_piece where handle like 'ctrl%' and status = 'A' order by completion_time desc) where rownum=1;"

#path="/srv/eyesofnetwork/nagios/plugins/RmanError/error_rman_${HOST}_${DBNAME}.txt"
#path="/tmp/error_rman_${HOST}_${DBNAME}.temp"
#getStatus="/srv/eyesofnetwork/nagios/plugins/RmanError/error_rman_${HOST}_${DBNAME}.txt"
getDirectory="/tmp/tmp-internal-Solaris/infos_solaris"
getFile="Export_${HOST}_${DBNAME}.lst"
getStatus="/tmp/tmp-internal-Solaris/infos_solaris/Export_${HOST}_${DBNAME}.lst"

datelimite=$(date "+%s") - 86400
echo datelimite = $datelimite
datefichier=$(stat -c %y $getStatus|awk -F"." '{print $1}')
echo datefichier = $datefichier
datefichierSec=$(date -d "${datefichier}" "+%s")
echo datefichierSec = $datefichierSec
#echo "${RequestA}" | sqlplus $USER/$PASSWORD'@'$HOST':'$PORT/$DBNAME | egrep 'OK|WARNING|CRITICAL' > $getStatus

# On teste l existence du fichier
if [ -s $getStatus ] ; then

  # Si le fichier est recent (datejour ou date veille) on teste le contenu sinon erreur
  if [ $datefichier == $datejour ] -o [ $datefichier == $dateveille ]  ; then
##  if [ "`grep WARNING $getStatus | wc -l`" -eq 1 ]; then
##		echo "`cat $getStatus`"
##		exit "$EXIT_WARNING"
##  elif [ "`grep CRITICAL $getStatus | wc -l`" -eq 1 ]; then
##		echo "`cat $getStatus`"
##		exit $EXIT_CRITICAL
##  elif [ "`grep OK $getStatus | wc -l`" -eq 1 ]; then
##		echo "`cat $getStatus`"
##		exit $EXIT_OK
##  fi
  else
	echo 'CRITICAL -> Export log too old $getFile : $datefichier'
	exit $EXIT_CRITICAL
  fi
else
	echo 'CRITICAL -> No export log  available'
	exit $EXIT_CRITICAL
fi
