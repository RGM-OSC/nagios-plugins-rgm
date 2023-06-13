#!/bin/sh
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

#------------------------------------------------------------------------------
#
#   PROJECT      :  EyesOfNetwork EyesOfReport load project
#
#   AUTOR        :  Benoit Village - Axians
#
#   DATE         :  Octobre 2016
#
#   HELP         :  see "usage"
#
#   COMMENT      : this plugin test if log nagios has been successfully logged in ods database.
#
#------------------------------------------------------------------------------
export LANG="fr_FR.UTF-8"

usage ()
{
  nom=$(basename $0)
  echo ""
  echo "Usage : $nom -H <hostname>"
  echo " "
  echo "     -H <hostname>"
  echo " "
  echo "Example : $nom -H server_eor "
  echo " "
exit 1
}

# Check arguments
while getopts ":S:H:" OPTS
do
    case $OPTS in
        H) HOST=$OPTARG ;;
        *) usage ;;
    esac
done

#if [ "${8}" = "" ]; then usage; fi

#HOST='sma6261'
#SOURCE='mrg_fjd'

extractbeg=$(date --date="$(date +%Y-%m-%d --date="yesterday")"  +%s)
extractend=$(($(date --date="$(date +%Y-%m-%d --date="yesterday")"  +%s) + 86399))
extractdate=$(date +%Y-%m-%d --date="yesterday")
today=$(date +%Y-%m-%d)

time_day_record=$(MYSQL_PWD="nagios" mysql -unagios -h $HOST -e "SELECT chg_id FROM eor_dwh.d_chargement where chg_etl_name ='ETL_DTM_APPLI_LINK_ANA_CONTRACT_UNVAIL_MONTH' and chg_date='$today' limit 1;")

if [ -z "$time_day_record" ]; then
	echo "CRITICAL: Nightly ETL seems to be not finished for date $extractdate : Check logs"
	exit 2
fi

echo "OK: Nightly ETL is finished for date $extractdate"
exit 0



