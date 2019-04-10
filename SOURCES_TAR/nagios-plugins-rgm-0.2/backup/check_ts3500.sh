#!/bin/ksh
#set -x
#
# $Id: check_ts3500.sh 312 2013-04-14 22:11:55Z u09422fra $
#
# IBM TS3500 (3584) tape library health monitoring plugin for Nagios 
#
# Paths 
BC='/usr/bin/bc'
CUT='/usr/bin/cut'
SNMPGET='/usr/bin/snmpget'
SNMPWALK='/usr/bin/snmpbulkwalk'
SED='/bin/sed'
TR='/usr/bin/tr'

# Nagios return codes and strings
R_OK=0
R_WARNING=1
R_CRITICAL=2
R_UNKNOWN=3
R_ALL=0
S_State[0]="OK"
S_State[1]="WARNING"
S_State[2]="CRITICAL"
S_State[3]="UNKNOWN"
S_ALL=""
S_PERF=""
S_PREFIX="TS3500"

# Using SNIA OIDs instead of IBM SML OIDs, because they provide
# more detailed information
#
# Security 
chassisLockPresent='.1.3.6.1.4.1.14851.3.1.4.4.0'           # unknown (0), true (1), false (2)
chassisSecurityBreach='.1.3.6.1.4.1.14851.3.1.4.5.0'        # unknown (1), other (2), noBreach (3), breachAttempted (4), breachSuccessful (5)
chassisIsLocked='.1.3.6.1.4.1.14851.3.1.4.6.0'              # unknown (0), true (1), false (2)
subChassisLockPresent='.1.3.6.1.4.1.14851.3.1.4.10.1.5'     # unknown (0), true (1), false (2)
subChassisSecurityBreach='.1.3.6.1.4.1.14851.3.1.4.10.1.6'  # unknown (1), other (2), noBreach (3), breachAttempted (4), breachSuccessful (5)
subChassisIsLocked='.1.3.6.1.4.1.14851.3.1.4.10.1.7'        # unknown (0), true (1), false (2)
# Sub chassis
numberOfsubChassis='.1.3.6.1.4.1.14851.3.1.4.9.0'
subChassis='.1.3.6.1.4.1.14851.3.1.4.10'
subChassisManufacturer='.1.3.6.1.4.1.14851.3.1.4.10.1.2'
subChassisModel='.1.3.6.1.4.1.14851.3.1.4.10.1.3'
subChassisSerialNumber='.1.3.6.1.4.1.14851.3.1.4.10.1.4'
subChassisOperationalStatus='.1.3.6.1.4.1.14851.3.1.4.10.1.10'  # unknown (0), other (1), ok (2), degraded (3), stressed (4),
                                                                # predictiveFailure (5), error (6), non-RecoverableError (7),
                                                                # starting (8), stopping (9), stopped  (10), inService (11),
                                                                # noContact (12), lostCommunication (13), aborted (14), dormant (15),
                                                                # supportingEntityInError (16), completed (17), powerMode (18),
                                                                # dMTFReserved (19), vendorReserved (32768)
subChassisPackageType='.1.3.6.1.4.1.14851.3.1.4.10.1.11'        # unknown (0), mainSystemChassis(17), expansionChassis(18),
                                                                # subChassis(19), serviceBay(32769)
# Devices
numberOfMediaAccessDevices='.1.3.6.1.4.1.14851.3.1.6.1.0'
mediaAccessDevice='.1.3.6.1.4.1.14851.3.1.6.2'
mediaAccessDeviceObjectType='.1.3.6.1.4.1.14851.3.1.6.2.1.2'    # unknown (0), wormDrive (1), magnetoOpticalDrive (2),
                                                                # tapeDrive (3), dvdDrive (4), cdromDrive (5)
mediaAccessDeviceName='.1.3.6.1.4.1.14851.3.1.6.2.1.3'
mediaAccessDeviceAvailability='.1.3.6.1.4.1.14851.3.1.6.2.1.5'  # other (1), unknown (2), runningFullPower (3), warning (4),
                                                                # inTest (5), notApplicable (6), powerOff (7), offLine (8),
                                                                # offDuty (9), degraded (10), notInstalled (11), installError (12),
                                                                # powerSaveUnknown (13), powerSaveLowPowerMode (14), powerSaveStandby (15),
                                                                # powerCycle (16), powerSaveWarning (17), paused (18), notReady (19),
                                                                # notConfigured (20), quiesced (21)
mediaAccessDeviceNeedsCleaning='.1.3.6.1.4.1.14851.3.1.6.2.1.6' 
mediaAccessDeviceMountCount='.1.3.6.1.4.1.14851.3.1.6.2.1.7'
mediaAccessDevicePowerOnHours='.1.3.6.1.4.1.14851.3.1.6.2.1.9'
mediaAccessDeviceTotalPowerOnHours='.1.3.6.1.4.1.14851.3.1.6.2.1.10'
mediaAccessDeviceOperationalStatus='.1.3.6.1.4.1.14851.3.1.6.2.1.11'                # see 'subChassisOperationalStatus'
# Library / robotics
numberOfChangerDevices='.1.3.6.1.4.1.14851.3.1.11.1.0'
changerDevice='.1.3.6.1.4.1.14851.3.1.11.2'
changerDeviceElementName='.1.3.6.1.4.1.14851.3.1.11.2.1.4'
changerDeviceAvailability='.1.3.6.1.4.1.14851.3.1.11.2.1.8'                         # see 'mediaAccessDeviceAvailability'
changerDeviceOperationalStatus='.1.3.6.1.4.1.14851.3.1.11.2.1.9'                    # see 'subChassisOperationalStatus'
# SCSI endpoints
numberOfSCSIProtocolControllers='.1.3.6.1.4.1.14851.3.1.12.1.0'
scsiProtocolController='.1.3.6.1.4.1.14851.3.1.12.2'
scsiProtocolControllerElementName='.1.3.6.1.4.1.14851.3.1.12.2.1.3'
scsiProtocolControllerOperationalStatus='.1.3.6.1.4.1.14851.3.1.12.2.1.4'           # see 'subChassisOperationalStatus'
scsiProtocolControllerAvailability='.1.3.6.1.4.1.14851.3.1.12.2.1.6'                # see 'mediaAccessDeviceAvailability'
# FC endpoints
numberOffCPorts='.1.3.6.1.4.1.14851.3.1.15.1.0'
fCPort='.1.3.6.1.4.1.14851.3.1.15.2'
fCPortElementName='.1.3.6.1.4.1.14851.3.1.15.2.1.3'
fCPortControllerOperationalStatus='.1.3.6.1.4.1.14851.3.1.15.2.1.6'                 # see 'subChassisOperationalStatus'
# Media
numberOfStorageMediaLocations='.1.3.6.1.4.1.14851.3.1.13.1.0'
numberOfPhysicalMedias='.1.3.6.1.4.1.14851.3.1.13.2.0'
storageMediaLocationPhysicalMediaMediaDescription='.1.3.6.1.4.1.14851.3.1.13.3.1.16'
storageMediaLocationPhysicalMediaCleanerMedia='.1.3.6.1.4.1.14851.3.1.13.3.1.17'    # unknown (0), true (1), false (2)

# Standard strings/values:
S_Std[0]="unknown"
S_Std[1]="true"
S_Std[2]="false"

# Possible security values:
S_Sec[1]="unknown"
S_Sec[2]="other"
S_Sec[3]="noBreach"
S_Sec[4]="breachAttempted"
S_Sec[5]="breachSuccessful"

# Possible availability values:
S_Avail[1]="other"
S_Avail[2]="unknown"
S_Avail[3]="running"   # Original value: "runningFullPower"
S_Avail[4]="warning"
S_Avail[5]="inTest"
S_Avail[6]="notApplicable"
S_Avail[7]="powerOff"
S_Avail[8]="offLine"
S_Avail[9]="offDuty"
S_Avail[10]="degraded"
S_Avail[11]="notInstalled"
S_Avail[12]="installError"
S_Avail[13]="powerSaveUnknown"
S_Avail[14]="powerSaveLowPowerMode"
S_Avail[15]="powerSaveStandby"
S_Avail[16]="powerCycle"
S_Avail[17]="powerSaveWarning"
S_Avail[18]="paused"
S_Avail[19]="notReady"
S_Avail[20]="notConfigured"
S_Avail[21]="quiesced"

# Possible media type values:
S_Media[0]="unknown"
S_Media[1]="wormDrive"
S_Media[2]="magnetoOpticalDrive"
S_Media[3]="tapeDrive"
S_Media[4]="dvdDrive"
S_Media[5]="cdromDrive"

# Possible status values:
typeset -A S_Package
S_Package[0]="unknown"
S_Package[17]="mainSystemChassis"
S_Package[18]="expansionChassis"
S_Package[19]="subChassis"
S_Package[32769]="serviceBay"

# Possible status values:
typeset -A S_Status
S_Status[0]="unknown"
S_Status[1]="other"
S_Status[2]="ok"
S_Status[3]="degraded"
S_Status[4]="stressed"
S_Status[5]="predictiveFailure"
S_Status[6]="error"
S_Status[7]="non-RecoverableError"
S_Status[8]="starting"
S_Status[9]="stopping"
S_Status[10]="stopped"
S_Status[11]="inService"
S_Status[12]="noContact"
S_Status[13]="lostCommunication"
S_Status[14]="aborted"
S_Status[15]="dormant"
S_Status[16]="supportingEntityInError"
S_Status[17]="completed"
S_Status[18]="powerMode"
S_Status[19]="dMTFReserved"
S_Status[32768]="vendorReserved"

# Variables
PROGNAME=$(basename $0)
QUIET="false"
SNMP_ARGS="-On -t 5 -r 1"
SNMP_VER="2c"
SNMP_COM="public"

if [[ ! -x ${SNMPGET} ]]; then
    echo "${S_PREFIX} UNKNOWN: ${SNMPGET} not found or not executable."
    exit ${R_UNKNOWN}
fi
if [[ ! -x ${SNMPWALK} ]]; then
    echo "${S_PREFIX} UNKNOWN: ${SNMPWALK} not found or not executable."
    exit ${R_UNKNOWN}
fi

# Functions
#
# Display usage message
usage() {
    echo "Usage: ${PROGNAME} [-h] -H hostname -C check [-p community] [-v (1|2c)] [-q]"
    echo "    -h  display help"
    echo "    -p  SNMP community string. Default: \"public\""
    echo "    -q  quiet mode. Only display elements with a non-OK status in the plugin output string"
    echo "    -v  SNMP version \"1\" or \"2c\". Default: \"2c\""
    echo "    -C  run one of the following checks:"
    echo "          chassis, changer, devices, fc, media, scsi, security"
    echo "    -H  run check on this hostname"
    exit ${R_UNKNOWN}
}

# Check return code
check_rc() {
    if [[ $1 -ne 0 ]]; then
        if [[ -z "$2" ]]; then
            echo "${S_PREFIX} ${S_UNKNOWN} - Unknown error occured."
            exit ${R_UNKNOWN}
        else
            echo "${S_PREFIX} ${S_UNKNOWN} - Error running: $2"
            exit ${R_UNKNOWN}
        fi
    fi
}

# Convert HEX value to decimal
hex2dec() {
    HEX=0
    if [[ ! -z $1 ]]; then
        HEX="$(echo $1 | ${TR} -d ' ')"
        DEC=$(echo "ibase=16; $HEX" | ${BC})
    fi
    echo "${DEC}"
}

# Main
#
# Get command line options
[[ $# -eq 0 ]] && usage
while getopts "hp:qv:C:H:" OPTION; do
    case ${OPTION} in
        h) usage ;;
        p) if [[ ! -z ${OPTARG} ]]; then
               SNMP_COM="${OPTARG}"
           else
               usage
           fi
        ;;
        q) QUIET=true ;;
        v) if [[ ! -z ${OPTARG} && ( "${OPTARG}" == "1" || "${OPTARG}" == "2c" ) ]]; then
               SNMP_VER="${OPTARG}"
           else
               usage
           fi
        ;;
        C) if [[ ! -z ${OPTARG} ]]; then
               CHECK=${OPTARG}
           else
               usage
           fi
        ;;
        H) if [[ ! -z ${OPTARG} ]]; then
               CHECK_HOST=${OPTARG}
           else
               usage
           fi
        ;;
        *) usage ;;
    esac
done

[[ -z ${CHECK_HOST} || -z ${CHECK} ]] && usage
SNMP_ARGS="${SNMP_ARGS} -v ${SNMP_VER} -c ${SNMP_COM}"

case ${CHECK} in
    "chassis")
        # Get chassis operating status
        R_numberOfsubChassis="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfsubChassis} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfsubChassis}"
        R_numberOfsubChassis="${R_numberOfsubChassis#*: }"

        if [[ ${R_numberOfsubChassis} -gt 0 ]]; then
            R_subChassis="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${subChassis} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_subChassis}"

            echo "${R_subChassis}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                if [[ "${OID_CLASS}" == "${subChassisOperationalStatus}" ]]; then
                    OPER_STATUS[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${subChassisPackageType}" ]]; then
                    SUB_CTYPE[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${subChassisManufacturer}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_MANU[${OID_OBJ}]="${VALUE%\"}"
                elif [[ "${OID_CLASS}" == "${subChassisModel}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_MODEL[${OID_OBJ}]="${VALUE%\"}"
                elif [[ "${OID_CLASS}" == "${subChassisSerialNumber}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_SN[${OID_OBJ}]="${VALUE%\"}"
                fi
            done

            CNT=1
            while [[ ${CNT} -le ${R_numberOfsubChassis} ]]; do
                [[ -z ${CHASSIS_TAG[${CNT}]} ]] && CHASSIS_TAG[${CNT}]="${CHASSIS_MANU[${CNT}]}_${CHASSIS_MODEL[${CNT}]}_${CHASSIS_SN[${CNT}]}"
                [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]}_${S_Package[${SUB_CTYPE[${CNT}]}]} (${S_Status[${OPER_STATUS[${CNT}]}]}); "
                if [[ ${OPER_STATUS[${CNT}]} -eq 0 ]]; then
                    [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_UNKNOWN}
                elif [[ ${OPER_STATUS[${CNT}]} -ne 2 ]]; then
                    R_ALL=${R_CRITICAL}
                    [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]}_${S_Package[${SUB_CTYPE[${CNT}]}]} (${S_Status[${OPER_STATUS[${CNT}]}]}); "
                fi
                CNT=$((CNT+1))
            done
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="Chassis OK"
        else
            S_ALL="No chassis found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "changer")
        # Get library / robotics operational status
        R_numberOfChangerDevices="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfChangerDevices} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfChangerDevices}"
        R_numberOfChangerDevices="${R_numberOfChangerDevices#*: }"

        if [[ ${R_numberOfChangerDevices} -gt 0 ]]; then
            R_changerDevice="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${changerDevice} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_changerDevice}"

            echo "${R_changerDevice}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                 if [[ "${OID_CLASS}" == "${changerDeviceElementName}" ]]; then
                     VALUE="${VALUE#\"}"
                     CH_NAME[${OID_OBJ}]="${VALUE%\"}"
                 elif [[ "${OID_CLASS}" == "${changerDeviceAvailability}" ]]; then
                     CH_AVAIL[${OID_OBJ}]="${VALUE}"
                 elif [[ "${OID_CLASS}" == "${changerDeviceOperationalStatus}" ]]; then
                     CH_STATUS[${OID_OBJ}]="${VALUE}"
                 fi
            done

            CNT=1
            while [[ ${CNT} -le ${R_numberOfChangerDevices} ]]; do
                [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${CH_NAME[${CNT}]} (${S_Avail[${CH_AVAIL[${CNT}]}]}/${S_Status[${CH_STATUS[${CNT}]}]}); "
                if [[ ${CH_AVAIL[${CNT}]} -eq 2 && ${CH_STATUS[${CNT}]} -eq 0 ]]; then
                    [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_UNKNOWN}
                elif [[ ( ${CH_AVAIL[${CNT}]} -ne 2 && ${CH_AVAIL[${CNT}]} -ne 3 ) ||
                        ( ${CH_STATUS[${CNT}]} -ne 0 && ${CH_STATUS[${CNT}]} -ne 2 ) ]]; then
                    R_ALL=${R_CRITICAL}
                    [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${CH_NAME[${CNT}]} (${S_Avail[${CH_AVAIL[${CNT}]}]}/${S_Status[${CH_STATUS[${CNT}]}]}); "
                fi
                CNT=$((CNT+1))
            done
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="Changer devices OK"
        else
            S_ALL="No changer devices found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "devices")
        # Get media access device (drives) operational status
        R_numberOfMediaAccessDevices="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfMediaAccessDevices} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfMediaAccessDevices}"
        R_numberOfMediaAccessDevices="${R_numberOfMediaAccessDevices#*: }"

        if [[ ${R_numberOfMediaAccessDevices} -gt 0 ]]; then
            R_mediaAccessDevice="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${mediaAccessDevice} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_mediaAccessDevice}"

            echo "${R_mediaAccessDevice}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                if [[ "${OID_CLASS}" == "${mediaAccessDevice}.1.1" ||
                      "${OID_CLASS}" == "${mediaAccessDevice}.1.4" ||
                      "${OID_CLASS}" == "${mediaAccessDevice}.1.8" ||
                      "${OID_CLASS}" == "${mediaAccessDevice}.1.12" ||
                      "${OID_CLASS}" == "${mediaAccessDevice}.1.13" ]]; then
                    continue
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceName}" ]]; then
                    VALUE="${VALUE#\"}"
                    VALUE="${VALUE%\"}"
                    DEV_NAME[${OID_OBJ}]="`echo ${VALUE} | ${TR} -s ' ' | ${TR} ' ' '_'`"
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceObjectType}" ]]; then
                    DEV_TYPE[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceAvailability}" ]]; then
                    DEV_AVAIL[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceNeedsCleaning}" ]]; then
                    DEV_CLEAN[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceMountCount}" ]]; then
                    DEV_MOUNT[${OID_OBJ}]=$(hex2dec "${VALUE}")
                elif [[ "${OID_CLASS}" == "${mediaAccessDevicePowerOnHours}" ]]; then
                    DEV_POWERON[${OID_OBJ}]=$(hex2dec "${VALUE}")
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceTotalPowerOnHours}" ]]; then
                    DEV_TOTALPOWERON[${OID_OBJ}]=$(hex2dec "${VALUE}")
                elif [[ "${OID_CLASS}" == "${mediaAccessDeviceOperationalStatus}" ]]; then
                    DEV_STATUS[${OID_OBJ}]="${VALUE}"
                fi
            done

            CNT=1
            while [[ ${CNT} -le ${R_numberOfMediaAccessDevices} ]]; do
                STATUS_CLEAN="clean"
                if [[ ${DEV_TYPE[${CNT}]} -eq 3 ]]; then
                    if [[ ${DEV_AVAIL[${CNT}]} -eq 2 && ${DEV_STATUS[${CNT}]} -eq 0 ]]; then
                        [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_UNKNOWN}
                    elif [[ ${DEV_CLEAN[${CNT}]} -eq 1 ]]; then
                        STATUS_CLEAN="dirty"
                        [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_WARNING}
                        [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${DEV_NAME[${CNT}]} (${S_Avail[${DEV_AVAIL[${CNT}]}]}/${S_Status[${DEV_STATUS[${CNT}]}]}/${STATUS_CLEAN}); "
                    elif [[ ( ${DEV_AVAIL[${CNT}]} -ne 2 && ${DEV_AVAIL[${CNT}]} -ne 3 ) ||
                            ( ${DEV_STATUS[${CNT}]} -ne 0 && ${DEV_STATUS[${CNT}]} -ne 2 ) ]]; then
                        R_ALL=${R_CRITICAL}
                        [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${DEV_NAME[${CNT}]} (${S_Avail[${DEV_AVAIL[${CNT}]}]}/${S_Status[${DEV_STATUS[${CNT}]}]}/${STATUS_CLEAN}); "
                    fi
                    DEV_SN="${DEV_NAME[${CNT}]##*_}"
                    S_PERF="${S_PERF} MNT_${DEV_SN}=${DEV_MOUNT[${CNT}]}c;;;; PWR_${DEV_SN}=${DEV_POWERON[${CNT}]}c;;;; TPWR_${DEV_SN}=${DEV_TOTALPOWERON[${CNT}]}c;;;;"
                    [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${DEV_NAME[${CNT}]} (${S_Avail[${DEV_AVAIL[${CNT}]}]}/${S_Status[${DEV_STATUS[${CNT}]}]}/${STATUS_CLEAN}); "
                fi
                CNT=$((CNT+1))
            done
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="Media access devices OK "
            S_ALL="${S_ALL}|${S_PERF}"
        else
            S_ALL="No media access devices (drives) found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "scsi")
        # Get SCSI controller operational status
        R_numberOfSCSIProtocolControllers="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfSCSIProtocolControllers} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfSCSIProtocolControllers}"
        R_numberOfSCSIProtocolControllers="${R_numberOfSCSIProtocolControllers#*: }"

        if [[ ${R_numberOfSCSIProtocolControllers} -gt 0 ]]; then
            R_scsiProtocolController="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${scsiProtocolController} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_scsiProtocolController}"

            echo "${R_scsiProtocolController}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                if [[ "${OID_CLASS}" == "${scsiProtocolControllerElementName}" ]]; then
                    VALUE="${VALUE#\"}"
                    VALUE="${VALUE%\"}"
                    SCSI_NAME[${OID_OBJ}]="`echo ${VALUE} | ${TR} -s ' ' | ${TR} ' ' '_'`"
                elif [[ "${OID_CLASS}" == "${scsiProtocolControllerAvailability}" ]]; then
                    SCSI_AVAIL[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${scsiProtocolControllerOperationalStatus}" ]]; then
                    SCSI_STATUS[${OID_OBJ}]="${VALUE}"
                fi
            done

            CNT=1
            while [[ ${CNT} -le ${R_numberOfSCSIProtocolControllers} ]]; do
                [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${SCSI_NAME[${CNT}]} (${S_Avail[${SCSI_AVAIL[${CNT}]}]}/${S_Status[${SCSI_STATUS[${CNT}]}]}); "
                if [[ ${SCSI_AVAIL[${CNT}]} -eq 2 && ${SCSI_STATUS[${CNT}]} -eq 0 ]]; then
                    [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_UNKNOWN}
                elif [[ ( ${SCSI_AVAIL[${CNT}]} -ne 2 && ${SCSI_AVAIL[${CNT}]} -ne 3 ) ||
                        ( ${SCSI_STATUS[${CNT}]} -ne 0 && ${SCSI_STATUS[${CNT}]} -ne 2 ) ]]; then
                    R_ALL=${R_CRITICAL}
                    [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${SCSI_NAME[${CNT}]} (${S_Avail[${SCSI_AVAIL[${CNT}]}]}/${S_Status[${SCSI_STATUS[${CNT}]}]}); "
                fi
                CNT=$((CNT+1))
            done
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="SCSI devices OK"
        else
            S_ALL="No SCSI devices found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "fc")
        # Get FC port operational status
        R_numberOffCPorts="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOffCPorts} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOffCPorts}"
        R_numberOffCPorts="${R_numberOffCPorts#*: }"

        if [[ ${R_numberOffCPorts} -gt 0 ]]; then
            R_fCPort="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${fCPort} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_fCPort}"

            echo "${R_fCPort}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                if [[ "${OID_CLASS}" == "${fCPortElementName}" ]]; then
                    VALUE="${VALUE#\"}"
                    VALUE="${VALUE%\"}"
                    FC_NAME[${OID_OBJ}]="`echo ${VALUE} | ${TR} -s ' ' | ${TR} ' ' '_'`"
                elif [[ "${OID_CLASS}" == "${fCPortControllerOperationalStatus}" ]]; then
                    FC_STATUS[${OID_OBJ}]="${VALUE}"
                fi
            done

            CNT=1
            while [[ ${CNT} -le ${R_numberOffCPorts} ]]; do
                [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${FC_NAME[${CNT}]} (${S_Status[${FC_STATUS[${CNT}]}]}); "
                if [[ ${FC_STATUS[${CNT}]} -ne 0 && ${FC_STATUS[${CNT}]} -ne 2 ]]; then
                    R_ALL=${R_CRITICAL}
                    [[ "${QUIET}" == "true" ]] && S_ALL="${S_ALL}${FC_NAME[${CNT}]} (${S_Status[${FC_STATUS[${CNT}]}]}); "
                fi
                CNT=$((CNT+1))
            done
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="FC devices OK"
        else
            S_ALL="No FC ports found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "media")
        # Check the number of cleaning media present
        NUM_CLEAN=0
        NUM_MEDIA=0
        NUM_LOCATION=0

        R_numberOfPhysicalMedias="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfPhysicalMedias} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfPhysicalMedias}"
        R_numberOfPhysicalMedias="${R_numberOfPhysicalMedias#*: }"
        [[ ${R_numberOfPhysicalMedias} -gt 0 ]] && NUM_MEDIA=${R_numberOfPhysicalMedias}

        R_numberOfStorageMediaLocations="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfStorageMediaLocations} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfStorageMediaLocations}"
        R_numberOfStorageMediaLocations="${R_numberOfStorageMediaLocations#*: }"
        [[ ${R_numberOfStorageMediaLocations} -gt 0 ]] && NUM_LOCATION=${R_numberOfStorageMediaLocations}

        if [[ ${R_numberOfPhysicalMedias} -gt 0 ]]; then
            R_storageMediaLocationPhysicalMediaCleanerMedia="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${storageMediaLocationPhysicalMediaCleanerMedia} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_storageMediaLocationPhysicalMediaCleanerMedia}"

            echo "${R_storageMediaLocationPhysicalMediaCleanerMedia}" | while read OID DUMMY TYPE VALUE; do
                if [[ ${VALUE} -eq 1 ]]; then
                    NUM_CLEAN=$((NUM_CLEAN+1))
                fi
            done

            NUM_MEDIA=$((NUM_MEDIA-NUM_CLEAN))
            if [[ ${NUM_CLEAN} -eq 0 ]]; then
                [[ "${QUIET}" == "true" ]] && S_ALL="No cleaning media present."
                R_ALL=${R_WARNING}
            fi
            S_PERF="cleaning=${NUM_CLEAN};;;; media=${NUM_MEDIA};;;; locations=${NUM_LOCATION};;;;"
            [[ "${QUIET}" == "false" ]] && S_ALL="Cleaning: ${NUM_CLEAN}; Media: ${NUM_MEDIA}; Locations: ${NUM_LOCATION}"
            [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="Cleaning media OK"
            S_ALL="${S_ALL} | ${S_PERF}"
        else
            S_ALL="No physical media found."
            R_ALL=${R_UNKNOWN}
        fi
    ;;
    "security")
        # Get global library security status
        R_chassisLockPresent="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${chassisLockPresent} ${chassisIsLocked} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_chassisLockPresent}"
        CHASSIS_TAG[0]="Global chassis"
        echo "${R_chassisLockPresent}" | while read OID DUMMY TYPE VALUE; do
            if [[ "${OID}" == "${chassisLockPresent}" ]]; then
                LOCK_PRESENT[0]="${VALUE}"
            elif [[ "${OID}" == "${chassisIsLocked}" ]]; then
                LOCK_LOCKED[0]="${VALUE}"
            fi
        done

        # Get sub chassis security status
        R_numberOfsubChassis="`${SNMPGET} ${SNMP_ARGS} ${CHECK_HOST} ${numberOfsubChassis} 2>&1`"
        RC=$?
        check_rc ${RC} "${SNMPGET} - ${R_numberOfsubChassis}"
        R_numberOfsubChassis="${R_numberOfsubChassis#*: }"

        if [[ ${R_numberOfsubChassis} -gt 0 ]]; then
            R_subChassis="`${SNMPWALK} ${SNMP_ARGS} ${CHECK_HOST} ${subChassis} 2>&1`"
            RC=$?
            check_rc ${RC} "${SNMPWALK} - ${R_subChassis}"

            echo "${R_subChassis}" | while read OID DUMMY TYPE VALUE; do
                OID_CLASS="${OID%.*}"
                OID_OBJ="${OID##*.}"
                if [[ "${OID_CLASS}" == "${subChassisLockPresent}" ]]; then
                    LOCK_PRESENT[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${subChassisIsLocked}" ]]; then
                    LOCK_LOCKED[${OID_OBJ}]="${VALUE}"
                elif [[ "${OID_CLASS}" == "${subChassisManufacturer}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_MANU[${OID_OBJ}]="${VALUE%\"}"
                elif [[ "${OID_CLASS}" == "${subChassisModel}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_MODEL[${OID_OBJ}]="${VALUE%\"}"
                elif [[ "${OID_CLASS}" == "${subChassisSerialNumber}" ]]; then
                    VALUE="${VALUE#\"}"
                    CHASSIS_SN[${OID_OBJ}]="${VALUE%\"}"
                fi
            done
        fi

        CNT=0
        while [[ ${CNT} -le ${R_numberOfsubChassis} ]]; do
            [[ -z ${CHASSIS_TAG[${CNT}]} ]] && CHASSIS_TAG[${CNT}]="${CHASSIS_MANU[${CNT}]}_${CHASSIS_MODEL[${CNT}]}_${CHASSIS_SN[${CNT}]}"
            if [[ ${LOCK_PRESENT[${CNT}]} -eq 1 ]]; then
                if [[ ${LOCK_LOCKED[${CNT}]} -eq 1 ]]; then
                    [[ "${QUIET}" == "false" ]] && S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]} (locked); "
                elif [[ ${LOCK_LOCKED[${CNT}]} -eq 2 ]]; then
                    S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]} (opened); "
                    R_ALL=${R_CRITICAL}
                elif [[ ${LOCK_LOCKED[${CNT}]} -eq 0 ]]; then
                    S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]} (unknown); "
                    [[ ${R_ALL} -ne ${R_CRITICAL} ]] && R_ALL=${R_UNKNOWN}
                fi
            else
                S_ALL="${S_ALL}${CHASSIS_TAG[${CNT}]} (No lock present); "
            fi
            CNT=$((CNT+1))
        done
        [[ "${QUIET}" == "true" && -z ${S_ALL} ]] && S_ALL="Security OK"
    ;;
    *) usage ;;
esac

echo "${S_PREFIX} ${S_State[${R_ALL}]} - ${S_ALL}"
exit ${R_ALL}

#
## EOF
