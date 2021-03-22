#!/bin/bash

# check_snmp_syno plugin for nagios version 1.1
# 18.06.2015 Bruno Flueckiger, inform.me@gmx.net
# -------------------------------------------------
# This plugin checks the health parameters of
# Synology systems (system, disks, raids) according
# to the MIB guide published by Synology:
# https://global.download.synology.com/download/Document/MIBGuide/
# -------------------------------------------------
# The official Nagios Plugin Development Guidelines
# have been followed as much as possible:
# http://nagios-plugins.org/doc/guidelines.html
# -------------------------------------------------

usage()
{
	echo "Usage: ./check_snmp_syno.sh -H hostname -C community -w temperature warning -c temperature critical [-v]"
	exit 3
}

if [ $# -eq 0 ]; then
	usage
fi

verbose=0

while getopts ":C:H:w:c:v" opt ; do
	case $opt in
		C)
			community=$OPTARG
			;;
		H)
			host=$OPTARG
			;;
		w)
			tempWarn=$OPTARG
			;;
		c)
			tempErr=$OPTARG
			;;
		v)
			verbose=1
			;;
		*)
			usage
			;;
	esac
done

SNMPGET=`which snmpget`
SNMPWALK=`which snmpwalk`

synoSystem=1.3.6.1.4.1.6574.1
synoDisks=1.3.6.1.4.1.6574.2
synoRAIDs=1.3.6.1.4.1.6574.3

result=`$SNMPGET -v2c -c $community -OQnv $host $synoSystem.1.0`
if [ $result -eq 2 ]; then
	echo "ERROR: $host has failed"
	exit 2
fi

result=`$SNMPGET -v2c -c $community -OQnv $host $synoSystem.2.0`
if [ $result -gt $tempWarn -a $result -lt $tempErr ]; then
	echo "WARNING: $host has $result °C"
	exit 1
fi
if [ $result -ge $tempErr ]; then
	echo "ERROR: $host has $result °C"
	exit 2
fi
if [ $verbose -eq 1 ]; then
	echo "OK: $host temparature is $result °C"
fi

result=`$SNMPGET -v2c -c $community -OQnv $host $synoSystem.3.0`
if [ $result -ne 1 ]; then
	echo "ERROR: $host power has failed"
	exit 2
fi

result=`$SNMPGET -v2c -c $community -OQnv $host $synoSystem.4.1.0`
if [ $result -ne 1 ]; then
	echo "ERROR: $host system fan failed"
	exit 2
fi

result=`$SNMPGET -v2c -c $community -OQnv $host $synoSystem.4.2.0`
if [ $result -ne 1 ]; then
	echo "ERROR: $host cpu fan failed"
	exit 2
fi

diskCount=`$SNMPWALK -v2c -c $community -OQnv $host $synoDisks.1.1.5 | wc -l`
i=0
while [ $i -lt $diskCount ]; do
	result=`$SNMPGET -v2c -c $community -OQnv $host $synoDisks.1.1.5.$i`
	case $result in
		1)
			if [ $verbose -eq 1 ]; then
				echo "OK: Disk $i"
			fi
			;;
		2)
			echo "WARNING: Disk $i is empty"
			exit 1
			;;
		3)
			echo "WARNING: Disk $i is not initialized"
			exit 1
			;;
		4)
			echo "CRITICAL: Disk $i is damaged"
			exit 2
			;;
		5)
			echo "CRITICAL: Disk $i is crashed"
			exit 2
			;;
	esac
	result=`$SNMPGET -v2c -c $community -OQnv $host $synoDisks.1.1.6.$i`
	if [ $result -gt $tempWarn -a $result -lt $tempErr ]; then
		echo "WARNING: Disk $i temperature is $result °C"
		exit 1
	fi
	if [ $result -ge $tempErr ]; then
		echo "ERROR: Disk $i temperature is $result °C"
		exit 2
	fi
	if [ $verbose -eq 1 ]; then
		echo "OK: Disk $i temperature is $result °C"
	fi
	i=$((i+1))
done

raidCount=`$SNMPWALK -v2c -c $community -OQnv $host $synoRAIDs.1.1.2 | wc -l`
i=0
while [ $i -lt $raidCount ]; do
	name=`$SNMPGET -v2c -c $community -OQnv $host $synoRAIDs.1.1.2.$i`
	result=`$SNMPGET -v2c -c $community -OQnv $host $synoRAIDs.1.1.3.$i`
	case $result in
		1)
			if [ $verbose -eq 1 ]; then
				echo "OK: RAID $name"
			fi
			;;
		2)
			echo "WARNING: RAID $name is reparing"
			exit 1
			;;
		3)
			echo "WARNING: RAID $name is migrating"
			exit 1
			;;
		4)
			echo "WARNING: RAID $name is expanding"
			exit 1
			;;
		5)
			echo "WARNING: RAID $name is deleting"
			exit 1
			;;
		6)
			echo "WARNING: RAID $name is creating"
			exit 1
			;;
		7)
			echo "WARNING: RAID $name is syncing"
			exit 1
			;;
		8)
			echo "WARNING: RAID $name is parity checking"
			exit 1
			;;
		9)
			echo "WARNING: RAID $name is assembling"
			exit 1
			;;
		10)
			echo "WARNING: RAID $name is canceling"
			exit 1
			;;
		11)
			echo "WARNING: RAID $name is degraded"
			exit 1
			;;
		12)
			echo "ERROR: RAID $name is crashed"
			exit 2
			;;
	esac
	i=$((i+1))
done

echo "OK: $host"
exit 0

