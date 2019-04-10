#!/bin/bash

export LANG="en_US.UTF-8"

export PLUGIN_PATH="/srv/eyesofnetwork/nagios/plugins"
export EXIT_OK=0
export EXIT_WARNING=1
export EXIT_CRITICAL=2
export EXIT_UNKNOWN=3


usage() {
echo "Usage :check_oracle_log_alerts.sh
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

RequestA="select * from ( select * from ( select  substr(d.message_text,instr(d.message_text,'ORA-' ), instr(translate(substr(d.message_text,instr(d.message_text,'ORA-' ),16),':',' '),' ')-1)  erreur_oracle, to_char(cast(D.ORIGINATING_TIMESTAMP as date),'DD/MM/YYYY HH24:MI:SS')||':'|| substr(D.MESSAGE_TEXT,1,57)||':'||D.problem_key message_erreur,decode (sign(1 - ((sysdate  - cast(D.ORIGINATING_TIMESTAMP as date))*24)),1,'CRITICAL','WARNING') criticite from SYS.V_\$DIAG_ALERT_EXT d, v\$instance where  message_text like '%ORA-%' and  cast(D.ORIGINATING_TIMESTAMP as date) > sysdate - 1 and d.adr_home like '%'||instance_name and component_id = 'rdbms' order by D.ORIGINATING_TIMESTAMP desc ) where erreur_oracle in( 'ORA-60', 'ORA-00020', 'ORA-00060', 'ORA-205', 'ORA-00205', 'ORA-257', 'ORA-00257', 'ORA-600', 'ORA-00600', 'ORA-601', 'ORA-00601', 'ORA-602', 'ORA-00602', 'ORA-603', 'ORA-00603', 'ORA-604', 'ORA-00604', 'ORA-605', 'ORA-00605', 'ORA-606', 'ORA-00606', 'ORA-607', 'ORA-00607', 'ORA-609', 'ORA-00609', 'ORA-942', 'ORA-00942', 'ORA-1000', 'ORA-01000', 'ORA-1031', 'ORA-01031', 'ORA-1034', 'ORA-01034', 'ORA-1110', 'ORA-01110', 'ORA-1146', 'ORA-01146', 'ORA-1507', 'ORA-1555', 'ORA-01555', 'ORA-1578', 'ORA-01578', 'ORA-1650', 'ORA-01650', 'ORA-1651', 'ORA-01651', 'ORA-1652', 'ORA-01652', 'ORA-1653', 'ORA-01653', 'ORA-1654', 'ORA-01654', 'ORA-1655', 'ORA-01655', 'ORA-3113', 'ORA-03113', 'ORA-4031', 'ORA-04031', 'ORA-16014', 'ORA-16038', 'ORA-01693', 'ORA-19504', 'ORA-27101', 'ORA-30036')) where rownum = 1
;"

path="/srv/eyesofnetwork/nagios/plugins/OracleError/error_oracle_${HOST}_${DBNAME}.txt"

echo "${RequestA}" | sqlplus $USER/$PASSWORD'@'$HOST':'$PORT/$DBNAME > $path

error=`cat $path | grep ORA-`
crit=`cat $path | egrep 'WARNING|CRITICAL'`

if [  "$error" != '' ]; then
	echo "$crit $error"
	
	if [ "$crit" == "WARNING" ]; then
		exit "$EXIT_WARNING"

	elif [ "$crit" == "CRITICAL" ]; then
		exit "$EXIT_CRITICAL"
	fi
fi
echo "No error Oracle detected"
exit "$EXIT_OK"

