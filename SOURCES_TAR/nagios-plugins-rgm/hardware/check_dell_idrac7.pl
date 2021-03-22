#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_dell_idrac7.pl
# Version : 0.5
# Date    : August 25 2013
# Modified Author : Thanga prakash S - thanga_somasundaram@dell.com
#
# Summary : This is a nagios plugin that checks the status of objects
#           monitored by Dell iDRAC7 on Dell PowerEdge 12G servers via SNMP
# 
# The script is based on the check_dell_openmanage.pl version 1.3.7
# Original Author  : Jason Ellison - infotek@gmail.com
# Additional Author: Troy Lea - plugins@box293.com
#
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This plugin checks the status of objects monitored by Dell OOB Server(iDRAC7) via SNMP
# and returns OK, WARNING, CRITICAL or UNKNOWN.  If a failure occurs it will
# describe the subsystem that failed and the failure code.
#
# This program is modified and maintained by:
#   Thanga prakash S - thanga_somasundaram@dell.com
#
# This program was maintained by:
#   Troy Lea - plugins@box293.com
#
# This program was written and maintained by:
#   Jason Ellison - infotek(at)gmail.com
#
# It is based on check_snmp_temperature.pl plugin by:
#   William Leibzon - william(at)leibzon.org
#
# System Models
# Here are the server models that this plugin has been designed for:
#
# PowerEdge 12G OOB servers (iDRAC7) 
#
# ============================= SETUP NOTES ====================================
#
# Copy this file to your Nagios installation folder in "libexec/". Rename
# to "check_dell_idrac7.pl".
#
# You must have Dell OpenManage installed on the server that you want to
# monitor. You must have enabled SNMP on the server and allow SNMP queries. 
# On the server that will be running the plugin you must have the perl
# "Net::SNMP" module installed.
#
# perl -MCPAN -e shell
# cpan> install Net::SNMP
#
# For SNMPv3 support make sure you have the following modules installed:
#   Crypt::DES, Digest::MD5, Digest::SHA1, and Digest::HMAC
#
# Check Dell OpenManage on the local host for alert thresholds like min/max
# fan speeds and temperatures...
#
# To test using SNMPv1 use the following syntax:
#
# ./check_dell_idrac7.pl -v -H <host> -C <snmp_community> -T <type>
#
# Where <type> is  "pe_r720", "model_servicetag", "os"
#
# ========================= SETUP EXAMPLES ==================================
#
# define command{
#       command_name    check_dell_open_manage
#       command_line    $USER1$/check_dell_openmanage.pl -H $HOSTADDRESS$ -C $ARG1$ -T $ARG2$
#       }
#
# define service{
#       use                     generic-service
#       host_name               DELL-SERVER-00
#       service_description     Dell OpenManage Status
#       check_command           check_dell_open_manage!public!dellom
#       normal_check_interval   3
#       retry_check_interval    1
#       }
#
# define service{
#       use                     generic-service
#       host_name               DELL-SERVER-01
#       service_description     Dell OpenManage Status plus Storage
#       check_command           check_dell_open_manage!public!dellom_storage
#       normal_check_interval   3
#       retry_check_interval    1
#       }
#
# ================================ REVISION ==================================
#
#ver 1.3.7
# Modified version by Troy Lea. 
# Added pe_r210_ii and pe_r720 checks.
#
#ver 1.3.6
# Modified version by Troy Lea. 
# Added pe_r210, pe_r510, pe_t710 checks.
#
#ver 1.3.5
# Modified version by Troy Lea. 
# Added pe_r610 checks.
# 
#ver 1.3.4
# Modified version by Troy Lea. 
# Added pe_800, pe_840, pe_1800, pe_1900, pe_2600, pe_m600, pe_m710, pe_r710, pe_t300, pe_t310, pe_t410, pe_t610 checks.
# 
#ver 1.3.3
# Modified version by Troy Lea. 
# Added pe_2800 check.
# 
#ver 1.3.2
# Modified version by Troy Lea. 
# Added pe_2850, pe_r200 checks.
#
# ver 1.3.1
# Modified version by Troy Lea. 
# Added blade_1855, blade_1955, pe_2900, pe_6800, pe_r300, model_servicetag and os checks.
#
# ver 1.3
#
# If non-numeric codes are returned just add the text to the statusinfo 
# This was done to allow adding machine information Dell Model Number and Service Tag to output.
#
# ver 1.2
#
# Major rewrite.  Simplified the way new systems are defined.  Added system
# type "test" which can be used to easly generate new system definitions.
#
# ver 1.1
# formating of text output
# add blade system type... blades apparently do not support 
# systemStatePowerSupplyStatusCombined, systemStateCoolingDeviceStatusCombined
# or systemStateChassisIntrusionStatusCombined
#
#
# ver 1.0
#
# while in verbose mode report which OID failed in a more readable manner.
# add "global", "chassis", and "custom" type.
#
# ver 0.9
# change added type dellom_storage as this is more accurate. This plugin works
# with all PowerEdge servers it has been tested with. left pe2950 in for compat
# remove min max int options from help text as they are no longer relevant
#
# ver 0.8
#
# removed ucdavis definition.  Added note about SNMPv3 dependencies
# check that perl environment has "Net::SNMP" if not found complain.
# missing "Net::SNMP" is the most common issue users report.
#
# ver 0.7
#
# removed ucdavis definition.  Added note about SNMPv3 dependencies
#
# ver 0.6
#
# + Added StorageManagement GlobalSystemStatus
# StorageManagement-MIB::agentGlobalSystemStatus
# .1.3.6.1.4.1.674.10893.1.20.110.13.0
#
# ver 0.5
#
# + Cleaned up verbose output for debugging
#
# ver 0.4
#
# + Fixed major flaw in logic that cause errors to not be reported.
#
# + Added to the system_types error warning and unkown variables like seen on
# http://www.mail-archive.com/intermapper-talk@list.dartware.com/msg02687.html
# below section: "This section performs value to text conversions"
#
# ========================== START OF PROGRAM CODE ============================

use strict;

use Getopt::Long;
my %system_types = (
	"dellom" => [
		'systemStateChassisStatus',
		'systemStatePowerSupplyStatusCombined',
		'systemStateVoltageStatusCombined',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateEventLogStatus',
	],
	"dellom_storage" => [
		'systemStateChassisStatus',
		'systemStatePowerSupplyStatusCombined',
		'systemStateVoltageStatusCombined',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateEventLogStatus',
		'StorageManagementGlobalSystemStatus'
	],
	"blade" => [
		'systemStateChassisStatus',
		'systemStateVoltageStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateEventLogStatus',
		'StorageManagementGlobalSystemStatus'
	],
	"blade_1855" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisStatus',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"blade_1955" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisStatus',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_800" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_840" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_1800" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_1900" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_2600" => [
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_2800" => [
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_2850" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_2900" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_6800" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_m600" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisStatus',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_m710" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisStatus',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r200" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r210" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r210_ii" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r300" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r510" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r610" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r710" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_r720" => [
		'GlobalHealthStatus',
		'racURL'
		],
	"pe_t300" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_t310" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_t410" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_t610" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"pe_t710" => [
		'StorageManagementGlobalSystemStatus',
		'systemStateAmperageStatusCombined',
		'systemStateBatteryStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateChassisStatus',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateCoolingUnitStatusCombined',
		'systemStateEventLogStatus',
		'systemStateGlobalSystemStatus',
		'systemStateMemoryDeviceStatusCombined',
		'systemStatePowerSupplyStatusCombined',
		'systemStatePowerUnitStatusCombined',
		'systemStateProcessorDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateVoltageStatusCombined'
	],
	"global" => [
		'systemStateGlobalSystemStatus'
	],
	"chassis" => [
		'systemStateChassisStatus'
	],
	"custom" => [
		'systemStateChassisStatus',
		'systemStatePowerSupplyStatusCombined',
		'systemStateCoolingDeviceStatusCombined',
		'systemStateTemperatureStatusCombined',
		'systemStateChassisIntrusionStatusCombined',
		'systemStateEventLogStatus',
		'chassisModelName',
		'chassisServiceTagName'
	],
	"model_servicetag" => [
		'chassisModelName',
		'chassisServiceTagName'
	],
	"os" => [
		'chassisSystemName',
		'operatingSystemOperatingSystemName',
		'operatingSystemOperatingSystemVersionName',
		'racshortname',
		'racversion',
		'racURL'
		]
);

my %dell_oids = (
  'GlobalHealthStatus'=>'.1.3.6.1.4.1.674.10892.5.2.1.0',
  'systemStateGlobalSystemStatus'=>'.1.3.6.1.4.1.674.10892.5.2.1.0',
  'systemStateChassisStatus'=>'.1.3.6.1.4.1.674.10892.5.2.4.0',
  'systemStatePowerSupplyStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.9.1',
  'systemStateVoltageStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.12.1',
  'systemStateAmperageStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.15.1',
  'systemStateCoolingDeviceStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.21.1',
  'systemStateTemperatureStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.24.1',
  'systemStateMemoryDeviceStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.27.1',
  'systemStateChassisIntrusionStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.30.1',
  'systemStateACPowerCordStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.36.1',
  'systemStateEventLogStatus'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.41.1',
  'systemStatePowerUnitStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.42.1',
  'systemStateCoolingUnitStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.44.1',
  'systemStateACPowerSwitchStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.46.1',
  'systemStateProcessorDeviceStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.50.1',
  'systemStateBatteryStatusCombined'=>'.1.3.6.1.4.1.674.10892.5.4.200.10.1.52.1',
  'StorageManagementGlobalSystemStatus'=>'.1.3.6.1.4.1.674.10892.5.2.3.0',
  'chassisManufacturerName'=>'.1.3.6.1.4.1.674.10892.5.4.300.10.1.8.1',
  'chassisModelName'=>'.1.3.6.1.4.1.674.10892.5.1.3.12.0',
  'chassisServiceTagName'=>'.1.3.6.1.4.1.674.10892.5.1.3.2.0',
  'chassisSystemName'=>'.1.3.6.1.4.1.674.10892.5.1.3.1.0',
  'operatingSystemOperatingSystemName'=>'.1.3.6.1.4.1.674.10892.5.1.3.6.0',
  'operatingSystemOperatingSystemVersionName'=>'.1.3.6.1.4.1.674.10892.5.1.3.14.0',
  'racversion'=>'.1.3.6.1.4.1.674.10892.5.1.1.5.0',
  'racshortname'=>'.1.3.6.1.4.1.674.10892.5.1.1.2.0',
  'racURL'=>'.1.3.6.1.4.1.674.10892.5.1.1.6.0'	  
);

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @DELLSTATUS=('DellStatus', 'other', 'unknown', 'ok', 'nonCritical', 'critical', 'nonRecoverable');
my $Version='0.5';
my $o_host=     undef;          # hostname
my $o_community= undef;         # community
my $o_port=     161;            # SNMP port
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option
my $o_warn=     undef;          # warning level option
my @o_warnL=    ();             # array for above list
my $o_crit=     undef;          # Critical level option
my @o_critL=    ();             # array for above list
my $o_timeout=  5;              # Default 5s Timeout
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3
my $o_attr=     undef;          # What attribute(s) to check (specify more then one separated by '.')
my @o_attrL=    ();             # array for above list
my $o_unkdef=   2;              # Default value to report for unknown attributes
my $o_type=     undef;          # Type of system to check 

sub print_version { print "$0: $Version\n" };

sub print_usage {
        print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd)  [-P <port>] -T test|dellom|dellom_storage|blade|global|chassis|blade_1855|blade_1955|pe_800|pe_840|pe_1800|pe_1900|pe_2600|pe_2800|pe_2850|pe_2900|pe_6800|pe_m600|pe_m710|pe_r200|pe_r210|pe_r210_ii|pe_r300|pe_r510|pe_r610|pe_r710|pe_r720|pe_t300|pe_t310|pe_t410|pe_t610|pe_t710|model_servicetag|os|custom [-t <timeout>] [-V] [-u <unknown_default>]\n";
}

# Return true if arg is a number
sub isnum {
        my $num = shift;
        if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
        return 0;
}

sub help {
        print "\nSNMP Dell OpenManage Monitor for Nagios version ",$Version,"\n";
        print " by Jason Ellison - infotek(at)gmail.com\n\n";
        print_usage();
        print <<EOD;
-v, --verbose
        print extra debugging information
-h, --help
        print this help message
-H, --hostname=HOST
        name or IP address of host to check
-C, --community=COMMUNITY NAME
        community name for the host's SNMP agent (implies v 1 protocol)
-2, --v2c
        use SNMP v2 (instead of SNMP v1)
-P, --port=PORT
        SNMPd port (Default 161)
-t, --timeout=INTEGER
        timeout for SNMP in seconds (Default: 5)
-V, --version
        prints version number
-u, --unknown_default=INT
        If attribute is not found then report the output as this number (i.e. -u 0)
-T, --type=test|dellom|dellom_storage|blade|global|chassis|blade_1855|blade_1955|pe_800|pe_840|pe_1800|pe_1900|pe_2600|pe_2800|pe_2850|pe_2900|pe_6800|pe_m600|pe_m710|pe_r200|pe_r300|pe_r610|pe_r710|pe_t300|pe_t310|pe_t410|pe_t610|model_servicetag|os|custom
        This allows to use pre-defined system type
        Currently support systems types are:
              test (tries all OID's in verbose mode can be used to generate new system type)
              dellom (Dell OpenManage general detailed)
              dellom_storage (Dell OpenManage plus Storage Management detailed)
              blade (some features are on the chassis not the blade)
              global (only check the global health status)
              chassis (only check the system chassis health status)
			  blade_1855 (detailed PowerEdge 1855 blade status)
			  blade_1955 (detailed PowerEdge 1955 blade status)
			  pe_800 (detailed PowerEdge 800 status)
			  pe_840 (detailed PowerEdge 840 status)
			  pe_1800 (detailed PowerEdge 1800 status)
			  pe_1900 (detailed PowerEdge 1900 status)
			  pe_2600 (detailed PowerEdge 2600 status)
			  pe_2800 (detailed PowerEdge 2800 status)
			  pe_2850 (detailed PowerEdge 2850 status)
			  pe_2900 (detailed PowerEdge 2900 status)
			  pe_6800 (detailed PowerEdge 6800 status)
			  pe_m600 (detailed PowerEdge M600 status)
			  pe_m710 (detailed PowerEdge M710 status)
			  pe_r200 (detailed PowerEdge R200 status)
			  pe_r210 (detailed PowerEdge R210 status)
			  pe_r210_ii (detailed PowerEdge R210 II status)
			  pe_r300 (detailed PowerEdge R300 status)
			  pe_r510 (detailed PowerEdge R510 status)
			  pe_r610 (detailed PowerEdge R610 status)
			  pe_r710 (detailed PowerEdge R710 status)
			  pe_r720 (detailed PowerEdge R720 status)
			  pe_t300 (detailed PowerEdge T300 status)
			  pe_t310 (detailed PowerEdge T310 status)
			  pe_t410 (detailed PowerEdge T410 status)
			  pe_t610 (detailed PowerEdge T610 status)
			  pe_t710 (detailed PowerEdge T710 status)
			  model_servicetag (returns Model Name and Service Tag Name)
			  os (returns SystemName, Operating System Name and Version)
              custom (intended for customization)
EOD
}

# For verbose output - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }
# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print ("ERROR: Alarm signal (Nagios time-out)\n");
     exit $ERRORS{"UNKNOWN"};
};
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'P:i'   => \$o_port,            'port:i'        => \$o_port,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        '2'     => \$o_version2,        'v2c'           => \$o_version2,
        'u:i'   => \$o_unkdef,          'unknown_default:i' => \$o_unkdef,
        'T:s'   => \$o_type,            'type:s'        => \$o_type
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}; }
    if (! defined($o_host) ) # check host and filter
        { print "No host defined!\n";print_usage(); exit $ERRORS{"UNKNOWN"}; }
    # check snmp information
    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
        { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (!defined($o_type)) { print "Must define system type!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; }
    if (defined ($o_type)) {
        if ($o_type eq "test"){
          print "TEST MODE:\n"; 
        } elsif (!defined($system_types{$o_type}))  {
          print "Unknown system type $o_type !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}; 
        }
    }
}
########## MAIN #######
check_options();
# Check global timeout if something goes wrong
if (defined($o_timeout)) {
  verb("Alarm at $o_timeout");
  alarm($o_timeout);
} else {
  verb("no timeout defined : using 5s");
  alarm (5);
}

eval "use Net::SNMP";
if ($@) {
  verb("ERROR: You do NOT have the Net:".":SNMP library \n"
  . "  Install it by running: \n"
  . "  perl -MCPAN -e shell \n"
  . "  cpan[1]> install Net::SNMP \n");
  exit 1;
} else {
  verb("The Net:".":SNMP library is available on your server \n");
}

# SNMP Connection to the host
my ($session,$error);
if (defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
  ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => 'md5',
      -privpassword     => $o_passwd,
      -timeout          => $o_timeout
   );
} else {
   if (defined ($o_version2)) {
     # SNMPv2 Login
         ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
            -version   => 2,
        -community => $o_community,
        -port      => $o_port,
        -timeout   => $o_timeout
     );
   } else {
    # SNMPV1 login
    ($session, $error) = Net::SNMP->session(
       -hostname  => $o_host,
       -community => $o_community,
       -port      => $o_port,
       -timeout   => $o_timeout
    );
  }
}
# next part of the code builds list of attributes to be retrieved
my $i;
my $oid;
my $line;
my $resp;
my $attr;
my $key;
my %varlist = ();
my $result;

if ( $o_type eq "test" ) {
  print "Trying all preconfigured Dell OID's against target...\n";
  for $attr (sort keys %dell_oids) {
    print "$attr\t\($dell_oids{$attr}\)\n";
    $result = $session->get_request(
      -varbindlist => [$dell_oids{$attr}]
    );
    print "RESULT: ";
    if (!defined($result)) {
      print "NO RESPONSE\n";
    } else {
      if ( $result->{$dell_oids{$attr}} =~ /^[123456]$/ ) {
        push @{ $varlist{$attr} }, "$attr", "$dell_oids{$attr}", "$result->{$dell_oids{$attr}}";
        print "$result->{$dell_oids{$attr}}\($DELLSTATUS[$result->{$dell_oids{$attr}}]\)\n";
      } else {
        print "$result->{$dell_oids{$attr}}\n";
      }
    }
  }
  $session->close();
  print "\nPlease email the results to Jason Ellison - infotek\@gmail.com\n";
  print "\nTo add this system to check_dell_openmanage, use something like the following:\n\n";
  print "        \"pexxxx\" => [\n";
  $i = 1;
  my $count = keys %varlist;
  for $attr (sort keys %varlist){
    print "                \'$varlist{$attr}[0]\'";
    if ( $i lt $count ) {
      print ",\n";
    } else {
      print "\n";
    }
    $i++;
  }
  print "        ],\n";
  exit 0 ;
} 

my $statusinfo = "";

verb("SNMP responses...");
for $attr ( @{ $system_types{$o_type} } ) {
  $result = $session->get_request( 
    -varbindlist => [$dell_oids{$attr}]
  );
  if (!defined($result)) {
    verb("RESULT: $attr \n$dell_oids{$attr} = undef");
    push @{ $varlist{$attr} }, "$attr", "$dell_oids{$attr}", "$o_unkdef"; 
  }
  else {
    if ( $result->{$dell_oids{$attr}} =~ /^[123456]$/ ) {
        verb("RESULT: $attr \n$dell_oids{$attr} = $result->{$dell_oids{$attr}}\($DELLSTATUS[$result->{$dell_oids{$attr}}]\)");
        push @{ $varlist{$attr} }, "$attr", "$dell_oids{$attr}", "$result->{$dell_oids{$attr}}"; 
      } else {
        verb("RESULT: $attr \n$dell_oids{$attr} = $result->{$dell_oids{$attr}}");
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$result->{$dell_oids{$attr}}";
      }
    }
}

$session->close();

# loop to check if warning & critical attributes are ok
verb("\nDell Status to Nagios Status mapping...");

my $statuscode = "OK";

my $statuscritical = "0";
my $statuswarning = "0";
my $statusunknown = "0";

foreach $attr (keys %varlist) {
    if ($varlist{$attr}[2] eq "6") {
        $statuscritical = "1";
        $statuscode="CRITICAL";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=Non-Recoverable";
    }
    elsif ($varlist{$attr}[2] eq "5") {
        $statuscritical="1";
        $statuscode="CRITICAL";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=Critical";
    }
    elsif ($varlist{$attr}[2] eq "4") {
        $statuswarning = "1";
        $statuscode="WARNING";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=Non-Critical";
    }
    elsif ($varlist{$attr}[2] eq "2") {
        $statusunknown = "1";
        $statuscode="UNKNOWN";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=UKNOWN";
    }
    elsif ($varlist{$attr}[2] eq "1") {
        $statusunknown = "1";
        $statuscode="UNKNOWN";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=Other";
    }
    elsif ($varlist{$attr}[2] eq "3") {
        $statuscode="OK";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=OK";
    }
    else {
        $statusunknown = "1";
        $statuscode="UNKNOWN";
        $statusinfo .= ", " if ($statusinfo);
        $statusinfo .= "$attr=UKNOWN";
    }
    verb("$attr: statuscode = $statuscode");
}

$statuscode="OK";

if ($statuscritical eq '1'){
  $statuscode="CRITICAL";
}
elsif ($statuswarning eq '1'){
  $statuscode="WARNING";
}
elsif ($statusunknown eq '1'){
  $statuscode="UNKNOWN";
}

printf("$statuscode: $statusinfo\n");

verb("\nEXIT CODE: $ERRORS{$statuscode} STATUS CODE: $statuscode\n");

exit $ERRORS{$statuscode};

