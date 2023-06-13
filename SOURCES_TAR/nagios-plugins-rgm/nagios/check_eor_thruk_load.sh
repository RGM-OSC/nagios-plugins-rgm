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
#   COMMENT      : this plugin test if log nagios has been successfully logged in thruk database.
#
#------------------------------------------------------------------------------
export LANG="fr_FR.UTF-8"

usage ()
{
  nom=`basename $0`
  echo ""
  echo "Usage : $nom -H <hostname> -B <backend>"
  echo " "
  echo "     -H <hostname>"
  echo "     -B <backend thruk>"
  echo " "
  echo "Example : $nom -H server_eor -B 4452b"
  echo " "
exit 1
}

# Check arguments
while getopts ":B:H:" OPTS
do
    case $OPTS in
        B) BACKEND=$OPTARG ;;
        H) HOST=$OPTARG ;;
        *) usage ;;
    esac
done

#if [ "${1}" = "" ]; then usage; fi

#HOST='10.99.2.119'
#BACKEND='4452b'

extractbeg=$(date --date="$(date +%Y-%m-%d --date="yesterday")"  +%s)
extractend=$(($(date --date="$(date +%Y-%m-%d --date="yesterday")"  +%s) + 86399))
extractdate=$(date +%Y-%m-%d --date="yesterday")

#extractbeg=1466546400
#extractend=1466632799

time_day_record=$(MYSQL_PWD="nagios" mysql -unagios -h $HOST -e "SELECT time FROM thruk.${BACKEND}_log where time between $extractbeg and $extractend limit 1;")

if [ -z "$time_day_record" ]; then
	echo "CRITICAL: log nagios hasn't been loaded in thruk database for date $extractdate"
	exit 2
fi

echo "OK: log nagios has been loaded in thruk database for date $extractdate"
exit 0



