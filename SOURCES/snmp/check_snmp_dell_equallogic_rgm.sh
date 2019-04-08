#!/bin/bash

# check_snmp_dell_equallogic
# Description : Check the status of Dell EqualLogic storage
# Version : 1.0
# Author : Yoann LAMY
# Licence : GPLv2

# Commands
CMD_BASENAME="/bin/basename"
CMD_SNMPGET="/usr/bin/snmpget"
CMD_SNMPWALK="/usr/bin/snmpwalk"
CMD_AWK="/bin/awk"
CMD_GREP="/bin/grep"
CMD_BC="/usr/bin/bc"
CMD_EXPR="/usr/bin/expr"

# Script name
SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="1.0"

# Plugin return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# 'eqlMemberName', EQLMEMBER-MIB
OID_MEMBER_ID=".1.3.6.1.4.1.12740.2.1.1.1.9"

# 'eqlControllerBatteryStatus', EQLMEMBER-MIB
OID_BATTERY_STATUS=".1.3.6.1.4.1.12740.4.1.1.1.5.1"

# 'eqlMemberModel', EQLMEMBER-MIB
OID_MODEL=".1.3.6.1.4.1.12740.2.1.11.1.1.1"

# 'eqlMemberSerialNumber', EQLMEMBER-MIB
OID_SERIALNUMBER=".1.3.6.1.4.1.12740.2.1.11.1.2.1"

# 'eqlMemberNumberOfControllers', EQLMEMBER-MIB
OID_NUMBERCONTROLLERS=".1.3.6.1.4.1.12740.2.1.11.1.3.1"

# 'eqlMemberNumberOfDisks', EQLMEMBER-MIB
OID_NUMBERDISKS=".1.3.6.1.4.1.12740.2.1.11.1.4.1"

# 'eqlMemberNumberOfConnections', EQLMEMBER-MIB
OID_CONNECTIONS_ISCSI=".1.3.6.1.4.1.12740.2.1.12.1.1"

# 'eqlMemberHealthDetailsFanName', EQLMEMBER-MIB
OID_FAN_NAME=".1.3.6.1.4.1.12740.2.1.7.1.2.1"

# 'eqlMemberHealthDetailsFanValue', EQLMEMBER-MIB
OID_FAN_VALUE=".1.3.6.1.4.1.12740.2.1.7.1.3.1"

# 'eqlMemberHealthStatus', EQLMEMBER-MIB
OID_HEALTH_STATUS=".1.3.6.1.4.1.12740.2.1.5.1.1.1"

# 'eqlMemberReadOpCount', EQLMEMBER-MIB
OID_IO_READ=".1.3.6.1.4.1.12740.2.1.12.1.6.1"

# 'eqlMemberWriteOpCount', EQLMEMBER-MIB
OID_IO_WRITE=".1.3.6.1.4.1.12740.2.1.12.1.7.1"

# 'eqlMemberReadAvgLatency', EQLMEMBER-MIB
OID_LATENCY_READ=".1.3.6.1.4.1.12740.2.1.12.1.4.1"

# 'eqlMemberWriteAvgLatency', EQLMEMBER-MIB
OID_LATENCY_WRITE=".1.3.6.1.4.1.12740.2.1.12.1.5.1"

# 'eqlControllerPrimaryOrSecondary', EQLCONTROLLER-MIB
OID_CONTROLLER_PRIMSEC=".1.3.6.1.4.1.12740.4.1.1.1.9.1"

# 'eqlDiskId', EQLDISK-MIB
OID_DISK_ID=".1.3.6.1.4.1.12740.3.1.1.1.10.1"

# 'eqlDiskTypeEnum', EQLDISK-MIB
OID_DISK_TYPE=".1.3.6.1.4.1.12740.3.1.1.1.12.1"

# 'eqlDiskSize', EQLDISK-MIB
OID_DISK_TOTAL=".1.3.6.1.4.1.12740.3.1.1.1.6.1"

# 'eqlDiskStatus', EQLDISK-MIB
OID_DISK_STATUS=".1.3.6.1.4.1.12740.3.1.1.1.8.1"

# 'eqlIpAdEntIfName', EQLIPADDR-MIB
OID_NETWORK_NAME=".1.3.6.1.4.1.12740.9.1.1.2.1"

# 'ifDescr', IF-MIB
OID_NETWORK_ID=".1.3.6.1.2.1.2.2.1.2"

# 'ifOperStatus', IF-MIB
OID_NETWORK_STATUS=".1.3.6.1.2.1.2.2.1.8"
      
# 'eqlMemberHealthDetailsPowerSupplyName', EQLMEMBER-MIB
OID_POWERSUPPLY_NAME=".1.3.6.1.4.1.12740.2.1.8.1.2.1"

# 'eqlMemberHealthDetailsPowerSupplyCurrentState', EQLMEMBER-MIB
OID_POWERSUPPLY_STATUS=".1.3.6.1.4.1.12740.2.1.8.1.3.1"

# 'eqlMemberStatusRaidStatus', EQLMEMBER-MIB
OID_RAID_STATUS=".1.3.6.1.4.1.12740.2.1.13.1.1.1"

# 'eqlMemberHealthDetailsTemperatureName', EQLMEMBER-MIB
OID_TEMPERATURE_NAME=".1.3.6.1.4.1.12740.2.1.6.1.2.1"

# 'eqlMemberHealthDetailsTemperatureValue', EQLMEMBER-MIB
OID_TEMPERATURE_VALUE=".1.3.6.1.4.1.12740.2.1.6.1.3.1"

# 'eqlMemberTotalStorage', EQLMEMBER-MIB
OID_USAGE_TOTAL=".1.3.6.1.4.1.12740.2.1.10.1.1.1"

# 'eqlMemberUsedStorage', EQLMEMBER-MIB
OID_USAGE_USED=".1.3.6.1.4.1.12740.2.1.10.1.2.1"

# 'eqlMemberSnapStorage', EQLMEMBER-MIB
OID_USAGE_SNAPSHOTS=".1.3.6.1.4.1.12740.2.1.10.1.3.1"

# 'eqlMemberReplStorage', EQLMEMBER-MIB
OID_USAGE_REPLICAS=".1.3.6.1.4.1.12740.2.1.10.1.4.1"

# 'eqliscsiVolumeName', EQLVOLUME-MIB
OID_VOLUME_NAME=".1.3.6.1.4.1.12740.5.1.7.1.1.4"

# 'eqliscsiVolumeAdminStatus', EQLVOLUME-MIB
OID_VOLUME_STATUS=".1.3.6.1.4.1.12740.5.1.7.1.1.9"

# 'eqliscsiVolumeSize', EQLVOLUME-MIB
OID_VOLUME_TOTAL=".1.3.6.1.4.1.12740.5.1.7.1.1.8"

# 'eqliscsiVolumeStatusAllocatedSpace', EQLVOLUME-MIB
OID_VOLUME_USED=".1.3.6.1.4.1.12740.5.1.7.7.1.13"

# 'eqliscsiVolumeStoragePoolIndex', EQLVOLUME-MIB
OID_VOLUME_STORAGEPOOL_ID=".1.3.6.1.4.1.12740.5.1.7.1.1.22"

# 'eqlStoragePoolName', EQLSTORAGEPOOL-MIB
OID_STORAGEPOOL_NAME=".1.3.6.1.4.1.12740.16.1.1.1.3.1"

# Default variables
DESCRIPTION="Unknown"
STATE=$STATE_UNKNOWN
CODE=0

# Default options
COMMUNITY="public"
HOSTNAME="127.0.0.1"
NAME=""
TYPE="info"
NETWORK="eth0"
DISK=1
VOLUME="vss-control"
WARNING=0
CRITICAL=0

# Option processing
print_usage() {
  echo "Usage: ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t redundancy"
  echo "  $SCRIPTNAME -H ADDRESS"
  echo "  $SCRIPTNAME -C STRING"
  echo "  $SCRIPTNAME -n STRING"
  echo "  $SCRIPTNAME -t STRING"
  echo "  $SCRIPTNAME -i STRING"
  echo "  $SCRIPTNAME -d INTEGER"
  echo "  $SCRIPTNAME -v STRING"
  echo "  $SCRIPTNAME -w INTEGER" 
  echo "  $SCRIPTNAME -c INTEGER" 
  echo "  $SCRIPTNAME -h"
  echo "  $SCRIPTNAME -V"
}

print_version() {
  echo $SCRIPTNAME version $VERSION
  echo ""
  echo "This nagios plugins comes with ABSOLUTELY NO WARRANTY."
  echo "You may redistribute copies of the plugins under the terms of the GNU General Public License v2." 
}

print_help() {
  print_version
  echo ""
  print_usage
  echo ""
  echo "Check the status of Dell EqualLogic storage"
  echo ""
  echo "-H ADDRESS"
  echo "   Name or IP address of host (default: 127.0.0.1)"
  echo "-C STRING"
  echo "   Community name for the host's SNMP agent (default: public)"
  echo "-n STRING"
  echo "   Member name"
  echo "-t STRING"
  echo "   Check type (battery, connection, controller, disk, fan, health, info, io, latency, network, redundancy, temperature, usage, raid, volume) (default: info)"
  echo "-i STRING"
  echo "   Network interface (default: eth0)"
  echo "-d INTEGER"
  echo "   Disk number (default: 1)"
  echo "-v STRING"
  echo "   Volume name (default: vss-control)"
  echo "-w INTEGER"
  echo "   Warning level for size in percent (default: 0)"
  echo "-c INTEGER"
  echo "   Critical level for size in percent (default: 0)"  
  echo "-h"
  echo "   Print this help screen"
  echo "-V"
  echo "   Print version and license information"
  echo ""
  echo ""
  echo "This plugin uses 'snmpget' and 'snmpwalk' commands included with the NET-SNMP package."
  echo "This plugin support performance data output (connection, fan, io, latency, temperature, usage, volume)."
}

while getopts H:C:n:t:i:d:v:w:c:hV OPT
do
  case $OPT in
    H) HOSTNAME="$OPTARG" ;;
    C) COMMUNITY="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    t) TYPE="$OPTARG" ;;
    i) NETWORK="$OPTARG" ;;
    d) DISK=$OPTARG ;;
    v) VOLUME="$OPTARG" ;;   
    w) WARNING=$OPTARG ;;
    c) CRITICAL=$OPTARG ;; 
    h) 
      print_help
      exit $STATE_UNKNOWN
      ;;
    V)
      print_version
      exit $STATE_UNKNOWN
      ;;
   esac
done

# Plugin processing
size_convert() {
  if [ $VALUE -ge 1099511627776 ]; then
    VALUE=`echo "scale=2 ; ( ( ( $VALUE / 1024 ) / 1024 ) / 1024 ) / 1024" | $CMD_BC`
    VALUE="$VALUE To"  
  elif [ $VALUE -ge 1073741824 ]; then
    VALUE=`echo "scale=2 ; ( ( $VALUE / 1024 ) / 1024 ) / 1024" | $CMD_BC`
    VALUE="$VALUE Go"  
  elif [ $VALUE -ge 1048576 ]; then
    VALUE=`echo "scale=2 ; ( $VALUE / 1024 ) / 1024" | $CMD_BC`
    VALUE="$VALUE Mo"
  else
    VALUE=`echo "scale=2 ; $VALUE / 1024" | $CMD_BC`
    VALUE="$VALUE Octets"
  fi
}

if [ -n "$NAME" ]; then
  MEMBER_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME $OID_MEMBER_ID | $CMD_GREP -i $NAME | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
  #echo "MEMBER NAME: $NAME"
  #echo "MEMBER_ID: $MEMBER_ID"
  if [ -n "$MEMBER_ID" ]; then

    if [ $TYPE = "battery" ]; then
      # Check battery status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t battery)
      DESCRIPTION="Member '${NAME}' - Battery status :"
      COMMA=", "
      for CONTROLLER_ID in 1 2; do
        BATTERY_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_BATTERY_STATUS}.${MEMBER_ID}.${CONTROLLER_ID}`
        case $BATTERY_STATUS in
          1)
            DESCRIPTION="$DESCRIPTION cache battery in controller $CONTROLLER_ID is fully functional ${COMMA}"
            STATE=$STATE_OK
          ;;
          2)
            DESCRIPTION="$DESCRIPTION cache battery failure in controller $CONTROLLER_ID"
            STATE=$STATE_CRITICAL
            break
          ;;
          3)
            DESCRIPTION="$DESCRIPTION cache battery in controller $CONTROLLER_ID is charging "
            STATE=$STATE_WARNING
            break
          ;;
          4)
            DESCRIPTION="$DESCRIPTION cache battery in controller $CONTROLLER_ID voltage is low"
            STATE=$STATE_CRITICAL
            break
          ;;
          5)
            DESCRIPTION="$DESCRIPTION cache battery in controller $CONTROLLER_ID voltage is low and is charging"
            STATE=$STATE_CRITICAL
            break
          ;;
          6)
            DESCRIPTION="$DESCRIPTION Missing cache battery in controller $CONTROLLER_ID"
            STATE=$STATE_CRITICAL
            break
          ;;
          *)
            DESCRIPTION="$DESCRIPTION cache battery in controller $CONTROLLER_ID status unknown"
            STATE=$STATE_UNKNOWN
            break
          ;;
        esac
        COMMA=""
      done
    elif [ $TYPE = "connection" ]; then
      # Number of connection (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t connection -w 15 -c 20)
      CONNECTIONS_ISCSI=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_CONNECTIONS_ISCSI}.${MEMBER_ID}`
      if [ -n "$CONNECTIONS_ISCSI" ]; then
        if [ $WARNING != 0 ] || [ $CRITICAL != 0 ]; then
          if [ $CONNECTIONS_ISCSI -gt $CRITICAL ] && [ $CRITICAL != 0 ]; then
            STATE=$STATE_CRITICAL
          elif [ $CONNECTIONS_ISCSI -gt $WARNING ] && [ $WARNING != 0 ]; then
            STATE=$STATE_WARNING
          else
            STATE=$STATE_OK
          fi
        else
          STATE=$STATE_OK
        fi
        DESCRIPTION="Member '${NAME}' - Number of iSCSI connections : ${CONNECTIONS_ISCSI} | con_iscsi=${CONNECTIONS_ISCSI};$WARNING;$CRITICAL;0"
      fi
    elif [ $TYPE = "controller" ]; then
      # Controllers status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t controller)
      CONTROLLER_NUMBER=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_CONTROLLER_PRIMSEC}.${MEMBER_ID} | wc -l`
      DESCRIPTION="Member '${NAME}' - Controllers status :"
      if [ $CONTROLLER_NUMBER = 2 ]; then
        DESCRIPTION="$DESCRIPTION both controllers are fully functional"
        STATE=$STATE_OK
      else
        DESCRIPTION="$DESCRIPTION A controller has failed"
        STATE=$STATE_WARNING
      fi
    elif [ $TYPE = "disk" ]; then
      # Disks storage status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t disk -d 1)
      DISK_SLOT=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_DISK_ID}.${MEMBER_ID}.${DISK}`
      DISK_TYPE=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_DISK_TYPE}.${MEMBER_ID}.${DISK}`         
      DISK_TOTAL=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_DISK_TOTAL}.${MEMBER_ID}.${DISK}`
      DISK_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_DISK_STATUS}.${MEMBER_ID}.${DISK}`
      DISK_TOTAL=`$CMD_EXPR $DISK_TOTAL \* 1048576`
      case $DISK_TYPE in      
        1)
          DISK_TYPE_TEXT="SATA"
        ;;
        2)
          DISK_TYPE_TEXT="SAS"
        ;;
        *)
          DISK_TYPE_TEXT="Unknown"
        ;;        
      esac       
      VALUE=$DISK_TOTAL
      size_convert
      DISK_TOTAL=$VALUE
      DESCRIPTION="Member '${NAME}' - Disk ${DISK} (slot ${DISK_SLOT}) status (type : ${DISK_TYPE_TEXT} and size ${DISK_TOTAL} ) :"
      case $DISK_STATUS in
        1)
          DESCRIPTION="$DESCRIPTION Disk is online. RAID is fully fonctionnal"
          STATE=$STATE_OK
        ;;
        2)
          DESCRIPTION="$DESCRIPTION Spare disk"
          STATE=$STATE_OK
        ;;
        3)
          DESCRIPTION="$DESCRIPTION Disk failures"
          STATE=$STATE_CRITICAL
        ;;
        4)
          DESCRIPTION="$DESCRIPTION Disk is offline"
          STATE=$STATE_WARNING
        ;;
        5)
          DESCRIPTION="$DESCRIPTION Disk failures"
          STATE=$STATE_WARNING
        ;;
        6)
          DESCRIPTION="$DESCRIPTION Disk is too small"
          STATE=$STATE_CRITICAL
        ;;
        7)
          DESCRIPTION="$DESCRIPTION Disk failure : cannot be converted to spare "
          STATE=$STATE_CRITICAL
        ;;
        8)
          DESCRIPTION="$DESCRIPTION Disk is unsupported. cannot be converted to spare"
          STATE=$STATE_CRITICAL
        ;;
        *)
          DESCRIPTION="$DESCRIPTION Disk : status unknown"
          STATE=$STATE_UNKNOWN
        ;;
      esac
    elif [ $TYPE = "fan" ]; then
      # Check fans RPM (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t fan)
      DESCRIPTION="Member '${NAME}' - Fan speed  :"
      for FAN_ID in `$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_FAN_NAME} | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`; do
        FAN_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_FAN_NAME}.${MEMBER_ID}.${FAN_ID} | $CMD_AWK -F '"' '{print $2}'`
        FAN_VALUE=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_FAN_VALUE}.${MEMBER_ID}.${FAN_ID}`
        DESCRIPTION="$DESCRIPTION '${FAN_NAME}' : ${FAN_VALUE} tr/min, "
        PERFORMANCE_DATA="$PERFORMANCE_DATA '${FAN_NAME}'=${FAN_VALUE}"
      done
      DESCRIPTION="$DESCRIPTION | $PERFORMANCE_DATA"
      STATE=$STATE_OK
    elif [ $TYPE = "health" ]; then
      # Check global system status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t health)
      HEALTH_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_HEALTH_STATUS}.${MEMBER_ID}`
      DESCRIPTION="Member '${NAME}' - Global system status : "
      case $HEALTH_STATUS in
        1)
          DESCRIPTION="$DESCRIPTION OK"
          STATE=$STATE_OK
        ;;
        2)
          DESCRIPTION="$DESCRIPTION Warning"
          STATE=$STATE_WARNING
        ;;
        3)
          DESCRIPTION="$DESCRIPTION Critical"
          STATE=$STATE_CRITICAL
        ;;
        *)
          DESCRIPTION="$DESCRIPTION Unknown"
          STATE=$STATE_UNKNOWN
        ;;
      esac
    elif [ $TYPE = "info" ]; then
      # Information (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t info)
      MODEL=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_MODEL}.${MEMBER_ID} | $CMD_AWK -F '"' '{print $2}'`
      SERIALNUMBER=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_SERIALNUMBER}.${MEMBER_ID} | $CMD_AWK -F '"' '{print $2}'`
      CONTROLLERS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_NUMBERCONTROLLERS}.${MEMBER_ID}`
      DISKS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_NUMBERDISKS}.${MEMBER_ID}`
      DESCRIPTION="Member '${NAME}' - Info : Storage Array Dell EqualLogic '${MODEL}' (${SERIALNUMBER}) has $CONTROLLERS controllers and $DISKS hard drives"
      STATE=$STATE_OK
    elif [ $TYPE = "io" ]; then
      # Check I/O performance (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t io)
      IO_READ=`$CMD_SNMPGET -t 2 -r 2 -v 2c -c $COMMUNITY -Ovq $HOSTNAME ${OID_IO_READ}.${MEMBER_ID}`
      IO_WRITE=`$CMD_SNMPGET -t 2 -r 2 -v 2c -c $COMMUNITY -Ovq $HOSTNAME ${OID_IO_WRITE}.${MEMBER_ID}`
      DESCRIPTION="Member '${NAME}' -  I/O Operations Per Second : Read counter's value is ${IO_READ} and write counter's value is $IO_WRITE | read=${IO_READ}c;0;0;0 write=${IO_WRITE}c;0;0;0"
      STATE=$STATE_OK
    elif [ $TYPE = "latency" ]; then
      # Check average latency (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t latency)
      LATENCY_READ=`$CMD_SNMPGET -t 2 -r 2 -v 2c -c $COMMUNITY -Ovq $HOSTNAME ${OID_LATENCY_READ}.${MEMBER_ID}`
      LATENCY_WRITE=`$CMD_SNMPGET -t 2 -r 2 -v 2c -c $COMMUNITY -Ovq $HOSTNAME ${OID_LATENCY_WRITE}.${MEMBER_ID}`
      DESCRIPTION="Member '${NAME}' - Reading average latency value is : $LATENCY_READ ms, writing average latency value is $LATENCY_WRITE ms | read=${LATENCY_READ};0;0;0 write=${LATENCY_WRITE};0;0;0"
      STATE=$STATE_OK
    elif [ $TYPE = "network" ]; then
      # Network interface status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t network -i eth0)
      NETWORK_IP=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_NETWORK_NAME}.${MEMBER_ID} | $CMD_GREP -i $NETWORK | $CMD_AWK '{print $1}' | $CMD_AWK -F "${MEMBER_ID}." '{print $2}'`
      NETWORK_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_NETWORK_ID} | $CMD_GREP -i $NETWORK | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`
      NETWORK_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_NETWORK_STATUS}.${NETWORK_ID}`
      DESCRIPTION="Member '${NAME}' - Network interface '${NETWORK}' (${NETWORK_IP}) status :"
      if [ $NETWORK_STATUS = "up" ]; then
         DESCRIPTION="$DESCRIPTION Network interface is fully fonctionnal"
         STATE=$STATE_OK
        else
          DESCRIPTION="$DESCRIPTION Network interface failure"
          STATE=$STATE_CRITICAL
      fi
    elif [ $TYPE = "redundancy" ]; then
      # Power supply status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t redundancy)
      DESCRIPTION="Member '${NAME}' - Power supply status :"
      COMMA=", "
      for POWERSUPPLY_ID in 1 2; do
        POWERSUPPLY_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_POWERSUPPLY_NAME}.${MEMBER_ID}.${POWERSUPPLY_ID} | $CMD_AWK -F '"' '{print $2}'`
        POWERSUPPLY_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_POWERSUPPLY_STATUS}.${MEMBER_ID}.${POWERSUPPLY_ID}`
        case $POWERSUPPLY_STATUS in
          1)
            DESCRIPTION="$DESCRIPTION '${POWERSUPPLY_NAME}' is fully fonctionnal${COMMA}"
            STATE=$STATE_OK
          ;;
          2)
            DESCRIPTION="$DESCRIPTION '${POWERSUPPLY_NAME}' power cord is missing"
            STATE=$STATE_WARNING
            break
          ;;
          3)
            DESCRIPTION="$DESCRIPTION '${POWERSUPPLY_NAME}' failure"
            STATE=$STATE_CRITICAL
            break
          ;;
          *)
            DESCRIPTION="$DESCRIPTION '${POWERSUPPLY_NAME}' status unknown"
            STATE=$STATE_UNKNOWN
            break
          ;;
        esac
        COMMA=""
      done
    elif [ $TYPE = "raid" ]; then
      # RAID status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t raid)
      RAID_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_RAID_STATUS}.${MEMBER_ID}`
      DESCRIPTION="Member '${NAME}' - RAID status :"
      case $RAID_STATUS in
        1)
          DESCRIPTION="$DESCRIPTION RAID is fully fonctionnal"
          STATE=$STATE_OK
        ;;
        2)
          DESCRIPTION="$DESCRIPTION RAID is running in degraded mode"
          STATE=$STATE_CRITICAL
        ;;
        3)
          DESCRIPTION="$DESCRIPTION Verifying integrity of RAID drives "
          STATE=$STATE_WARNING
        ;;
        4)
          DESCRIPTION="$DESCRIPTION RAID is rebuilding"
          STATE=$STATE_WARNING    
        ;;
        5)
          DESCRIPTION="$DESCRIPTION RAID failure"
          STATE=$STATE_CRITICAL
        ;;
        6)
          DESCRIPTION="$DESCRIPTION RAID failure"
          STATE=$STATE_CRITICAL
        ;;    
        7)
          DESCRIPTION="$DESCRIPTION RAID is resizing"
          STATE=$STATE_WARNING
        ;;            
        *)
          DESCRIPTION="$DESCRIPTION RAID is in unknown state"
          STATE=$STATE_UNKNOWN          
        ;;
      esac
    elif [ $TYPE = "temperature" ]; then
      # Check temperature (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t temperature)
      DESCRIPTION="Member '${NAME}' - Temperatures :"
      for TEMPERATURE_ID in `$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_TEMPERATURE_NAME} | $CMD_AWK '{ print $1}' | $CMD_AWK -F "." '{print $NF}'`; do
        TEMPERATURE_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_TEMPERATURE_NAME}.${MEMBER_ID}.${TEMPERATURE_ID} | $CMD_AWK -F '"' '{print $2}'`
        TEMPERATURE_VALUE=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_TEMPERATURE_VALUE}.${MEMBER_ID}.${TEMPERATURE_ID}`
        DESCRIPTION="$DESCRIPTION '${TEMPERATURE_NAME}' : ${TEMPERATURE_VALUE} Degres Celcius, "
        PERFORMANCE_DATA="$PERFORMANCE_DATA '${TEMPERATURE_NAME}'=${TEMPERATURE_VALUE}"
      done
      DESCRIPTION="$DESCRIPTION | $PERFORMANCE_DATA"
      STATE=$STATE_OK
    elif [ $TYPE = "usage" ]; then
      # Disk usage (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t usage -w 90 -c 95)
      USAGE_TOTAL=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_USAGE_TOTAL}.${MEMBER_ID}`
      USAGE_USED=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_USAGE_USED}.${MEMBER_ID}`
      USAGE_SNAPSHOTS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_USAGE_SNAPSHOTS}.${MEMBER_ID}`
      USAGE_REPLICAS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_USAGE_REPLICAS}.${MEMBER_ID}`

      if [ $USAGE_TOTAL != 0 ]; then
        USAGE_TOTAL=`$CMD_EXPR $USAGE_TOTAL \* 1048576`
        USAGE_USED=`$CMD_EXPR $USAGE_USED \* 1048576`
        USAGE_SNAPSHOTS=`$CMD_EXPR $USAGE_SNAPSHOTS \* 1048576`
        USAGE_REPLICAS=`$CMD_EXPR $USAGE_REPLICAS \* 1048576`

        USAGE_USED_POURCENT=`$CMD_EXPR \( $USAGE_USED \* 100 \) / $USAGE_TOTAL`
        USAGE_SNAPSHOTS_POURCENT=`$CMD_EXPR \( $USAGE_SNAPSHOTS \* 100 \) / $USAGE_TOTAL`
        USAGE_REPLICAS_POURCENT=`$CMD_EXPR \( $USAGE_REPLICAS \* 100 \) / $USAGE_TOTAL`

        PERFDATA_WARNING=0
        PERFDATA_CRITICAL=0

        if [ $WARNING != 0 ] || [ $CRITICAL != 0 ]; then
          PERFDATA_WARNING=`$CMD_EXPR \( $USAGE_TOTAL \* $WARNING \) / 100`
          PERFDATA_CRITICAL=`$CMD_EXPR \( $USAGE_TOTAL \* $CRITICAL \) / 100`

          if [ $USAGE_USED_POURCENT -gt $CRITICAL ] && [ $CRITICAL != 0 ]; then
            STATE=$STATE_CRITICAL
          elif [ $USAGE_USED_POURCENT -gt $WARNING ] && [ $WARNING != 0 ]; then
            STATE=$STATE_WARNING
          else
            STATE=$STATE_OK
          fi
        else
          STATE=$STATE_OK
        fi

        VALUE=$USAGE_TOTAL
        size_convert
        USAGE_TOTAL_FORMAT=$VALUE

        VALUE=$USAGE_USED
        size_convert
        USAGE_USED_FORMAT=$VALUE

        DESCRIPTION="Member '${NAME}' - Used disk space : $USAGE_USED_FORMAT with a total disk space of $USAGE_TOTAL_FORMAT (${USAGE_USED_POURCENT}%) with ${USAGE_SNAPSHOTS_POURCENT}% for snapshots and ${USAGE_REPLICAS_POURCENT}% for replication | total=${USAGE_TOTAL}B;$PERFDATA_WARNING;$PERFDATA_CRITICAL;0 used=${USAGE_USED}B;0;0;0 snapshots=${USAGE_SNAPSHOTS}B;0;0;0 replicas=${USAGE_REPLICAS}B;0;0;0"
      fi
    elif [ $TYPE = "volume" ]; then
      # Volume status (Usage : ./check_snmp_dell_equallogic -H 127.0.0.1 -C public -n BAIE01 -t volume -v volume01 -w 90 -c 95)
      echo "OID passe en argument: ${OID_VOLUME_NAME}.${MEMBER_ID}"
      VOLUME_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_VOLUME_NAME}.${MEMBER_ID} | $CMD_GREP -i $VOLUME | $CMD_AWK '{print $1}' | $CMD_AWK -F "." '{print $NF}'`

      #VOLUME_ID=`$CMD_SNMPWALK -t 2 -r 2 -v 1 -c $COMMUNITY $HOSTNAME ${OID_VOLUME_NAME}.${MEMBER_ID} | $CMD_GREP -i $VOLUME | $CMD_AWK '{print $1}' | sed -e "s/$OID_VOLUME_NAME//"`
      echo "VOLUME_ID RECUPERE: $VOLUME_ID"





      VOLUME_STATUS=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_VOLUME_STATUS}.${MEMBER_ID}.${VOLUME_ID}`
      VOLUME_STORAGEPOOL_ID=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_VOLUME_STORAGEPOOL_ID}.${MEMBER_ID}.${VOLUME_ID}`
      VOLUME_STORAGEPOOL_NAME=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_STORAGEPOOL_NAME}.${VOLUME_STORAGEPOOL_ID} | $CMD_AWK -F '"' '{print $2}'`
      case $VOLUME_STATUS in
        1)
          VOLUME_STATUS_DESC="online"
        ;;
        2)
          VOLUME_STATUS_DESC="offline"
        ;;
        3)
          VOLUME_STATUS_DESC="online, lost blocks"
        ;;
        4)
          VOLUME_STATUS_DESC="online, lost and ignored blocks"
        ;;
        5)
          VOLUME_STATUS_DESC="offline, lost and ignored blocks"
        ;;
        *)
          VOLUME_STATUS_DESC="unknwon"
        ;;
      esac
      DESCRIPTION="Member '${NAME}' - Volume '${VOLUME}' (${VOLUME_STATUS_DESC}) in RAID group '${VOLUME_STORAGEPOOL_NAME}' :"
      VOLUME_TOTAL=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_VOLUME_TOTAL}.${MEMBER_ID}.${VOLUME_ID}`
      VOLUME_USED=`$CMD_SNMPGET -t 2 -r 2 -v 1 -c $COMMUNITY -Ovq $HOSTNAME ${OID_VOLUME_USED}.${MEMBER_ID}.${VOLUME_ID}`

      if [ $VOLUME_TOTAL != 0 ]; then     
        VOLUME_TOTAL=`$CMD_EXPR $VOLUME_TOTAL \* 1048576`
        VOLUME_USED=`$CMD_EXPR $VOLUME_USED \* 1048576`
        VOLUME_USED_POURCENT=`$CMD_EXPR \( $VOLUME_USED \* 100 \) / $VOLUME_TOTAL`
        PERFDATA_WARNING=0
        PERFDATA_CRITICAL=0

        if [ $WARNING != 0 ] || [ $CRITICAL != 0 ]; then
          PERFDATA_WARNING=`$CMD_EXPR \( $VOLUME_TOTAL \* $WARNING \) / 100`
          PERFDATA_CRITICAL=`$CMD_EXPR \( $VOLUME_TOTAL \* $CRITICAL \) / 100`

          if [ $VOLUME_USED_POURCENT -gt $CRITICAL ] && [ $CRITICAL != 0 ]; then
            STATE=$STATE_CRITICAL
          elif [ $VOLUME_USED_POURCENT -gt $WARNING ] && [ $WARNING != 0 ]; then
            STATE=$STATE_WARNING
          else
            STATE=$STATE_OK
          fi
        else
          STATE=$STATE_OK
        fi
        
        VALUE=$VOLUME_TOTAL
        size_convert
        VOLUME_TOTAL_FORMAT=$VALUE

        VALUE=$VOLUME_USED
        size_convert
        VOLUME_USED_FORMAT=$VALUE

        DESCRIPTION="$DESCRIPTION $VOLUME_USED_FORMAT used on $VOLUME_TOTAL_FORMAT (${VOLUME_USED_POURCENT}%) | volume_used=${VOLUME_USED}B;$PERFDATA_WARNING;$PERFDATA_CRITICAL;0"
      fi   
    fi    
  fi  
fi

echo $DESCRIPTION
exit $STATE
