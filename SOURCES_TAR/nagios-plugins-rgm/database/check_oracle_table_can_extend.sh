#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="en_US.UTF-8"

export PLUGIN_PATH="/srv/eyesofnetwork/nagios/plugins"
export EXIT_OK=0
export EXIT_WARNING=1
export EXIT_CRITICAL=2
export EXIT_UNKNOWN=3

## Controle parametres
usage() {
echo "Usage :check_oracle_table_can_extend.sh
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

## Requete de controle
RequestA="set heading off
select 'CRITICAL : table '||owner||'.'|| table_name||' cannot extend by ' || to_char(round(T.NEXT_EXTENT/1024/1024,2))||' in tablespace '||t.tablespace_name result    from dba_tables T  where t.next_extent > 5000000 and t.next_extent > ( select    max(a.bytes)largest   FROM dba_free_space a, dba_tablespaces B2 WHERE B2.tablespace_name = a.tablespace_name   AND B2.status = 'ONLINE' and b2.tablespace_name = t.tablespace_name   GROUP BY B2.tablespace_name, B2.extent_management, B2.allocation_type, B2.initial_extent, B2.next_extent)
;"


## Fichier resultat
path="/srv/eyesofnetwork/nagios/plugins/CheckOracleObjects/check_oracle_table_can_extend_${HOST}_${DBNAME}.txt"


## connection
echo "${RequestA}" | sqlplus -s $USER/$PASSWORD'@'$HOST':'$PORT/$DBNAME > $path


## analyse des resultats
if [ $(grep "aucune ligne selectionnee" $path|wc -l) -eq 1 ]; then
    crit=OK
elif [ $(grep "aucune ligne s�lectionn�e" $path|wc -l) -eq 1 ]; then
    crit=OK
elif [ $(grep "no rows selected" $path|wc -l) -eq 1 ]; then
    crit=OK
elif [ $(grep 'CRITICAL' $path|wc -l) -gt 0 ]; then
     crit=CRITICAL
else
     crit=''
fi
#crit=`cat $path | egrep 'OK|WARNING|CRITICAL'`


## Formatage pour Eon
if [  "$crit" != '' ]; then

        if [ "$crit" == "WARNING" ]; then
                echo "$crit"
                exit "$EXIT_WARNING"

        elif [ "$crit" == "CRITICAL" ]; then
                echo "$crit"
                cat $path
                exit "$EXIT_CRITICAL"

        elif [ "$crit" == "OK" ]; then
                echo "OK - No table extend problem detected"
                exit "$EXIT_OK"
        fi
else
        echo 'Wrong connection'
        exit $EXIT_CRITICAL
fi

