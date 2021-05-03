#!/bin/bash
 
export LANG="fr_FR.UTF-8"
 
usage() {
echo "Usage :check_http_gearman.sh
    -H Nagios Host target
    -S Nagios Service Descriptation


    Note: You must specify ARG1, ARG2, ARG3 and ARG4 as follow in EON:
    ARG1= Hostname
    ARG2= Port
    ARG3= URL (ex: /atollng_srv/m50/mgservice.asmx/connecteUser?iUserLogin=XX&iUserPassword=XX&iUserProfil=XX&iLang=XX&iConfig=XX)
    ARG5= Expected String and options (ex: -s \"Aucun utilisateur\" -w 10 -c 60)"
exit 2
}
 
CHECK_HTTP="/srv/eyesofnetwork/nagios/plugins/check_http"
MYSQLDB="lilac"
MYSQLUser="root"
MYSQLPass="root66"

if [ "${4}" = "" ]; then usage; fi
 
WARNING=0
CRITICAL=0
 
ARGS="`echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g'`"

#**************** DEBUG ****************
#echo "ARGS: " $ARGS
#***************************************

 
for i in $ARGS; do
        if [ -n "`echo ${i} | grep "^\-H"`" ]; then HostNagios="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n "${HostNagios}" ]; then usage;fi;fi
        if [ -n "`echo ${i} | grep "^\-S"`" ]; then ServiceNagios="`echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]'`"; if [ ! -n "${ServiceNagios}" ]; then usage;fi;fi
done

if [ ! -n "${ServiceNagios}" ]; then usage;fi
if [ ! -n "${HostNagios}" ]; then usage;fi

#**************** DEBUG ****************
#echo "ServiceNagios:" $ServiceNagios
#echo "HostNagios:" $HostNagios
#***************************************



ID_SERV="`echo "select nagios_service.id from nagios_service inner join nagios_host ON nagios_host.id = nagios_service.host  where  LOWER(nagios_service.description) = LOWER('$ServiceNagios') AND LOWER(nagios_host.name) = LOWER('$HostNagios');" | mysql -u$MYSQLUser -p$MYSQLPass $MYSQLDB | grep -v "^id$"`"
PARAMETERS="`echo "select parameter from nagios_service_check_command_parameter where template is NULL AND nagios_service_check_command_parameter.service = (select nagios_service.id from nagios_service inner join nagios_host ON nagios_host.id = nagios_service.host  where  LOWER(nagios_service.description) = LOWER('$ServiceNagios') AND LOWER(nagios_host.name) = LOWER('$HostNagios')) ORDER BY nagios_service_check_command_parameter.id ASC;" | mysql -u$MYSQLUser -p$MYSQLPass $MYSQLDB | grep -v "^parameter$" | sed -e 's: :+++:g' | tr '\n' ' '`"

#**************** DEBUG ****************
#echo "ID_SERV:" $ID_SERV
#echo "PARAMETERS:" $PARAMETERS
#***************************************


NagiosARG1="`echo "$PARAMETERS" | awk '{print $1}' | sed -e 's:+++: :g'`"
NagiosARG2="`echo "$PARAMETERS" | awk '{print $2}' | sed -e 's:+++: :g'`"
NagiosARG3="`echo "$PARAMETERS" | awk '{print $3}' | sed -e 's:+++: :g'`"
NagiosARG4="`echo "$PARAMETERS" | awk '{print $4}' | sed -e 's:+++: :g'`"
NagiosARG5="`echo "$PARAMETERS" | awk '{print $5}' | sed -e 's:+++: :g'`"

#**************** DEBUG ****************
#echo "NagiosARG1:" $NagiosARG1
#echo "NagiosARG2:" $NagiosARG2
#echo "NagiosARG3:" $NagiosARG3
#echo "NagiosARG4:" $NagiosARG4
#echo "NagiosARG5:" $NagiosARG5
#***************************************



if [ ! -n "${NagiosARG1}" ]; then usage;fi
if [ ! -n "${NagiosARG2}" ]; then usage;fi
if [ ! -n "${NagiosARG3}" ]; then usage;fi
if [ ! -n "${NagiosARG4}" ]; then usage;fi
if [ ! -n "${NagiosARG5}" ]; then usage;fi

COUNTWARNING=0
COUNTCRITICAL=0
 
PLUG_CMD="$CHECK_HTTP -H $NagiosARG1 -p $NagiosARG2 -u $NagiosARG3"

# DEBUG Purpose Only.....
#PLUG_CMD="$CHECK_HTTP -H $NagiosARG1 -p $NagiosARG2 -u $NagiosARG3 -v"
#echo "$PLUG_CMD -s ${NagiosARG4[@]} ${NagiosARG5}"
#END Of DEBUG.....

${PLUG_CMD} -s "${NagiosARG4[@]}" ${NagiosARG5}
exit $?
