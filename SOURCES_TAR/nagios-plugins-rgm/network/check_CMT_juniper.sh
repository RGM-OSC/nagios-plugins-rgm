#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

################### check_CMT.sh ############################
# Version 1.1.1
# Date : Nov 06 2014
# Author  : Sandeep Chowdhury ( sandeep1.chowdhury@gmail.com )
# Contributors : Carlos Oliva ( telematico@gmail.com )
# Help : sandeep1.chowdhury@gmail.com
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Report bugs to: sandeep1.chowdhury@gmail.com
# ########################################################################


### Enable/Change the below "AWK" PATH according to your Operating System ###

# For Redhat Derivatives
AWK="/bin/awk"

# For Debian Derivatives
#AWK="/usr/bin/awk"



args=("$@")
ELEMENTS=${#args[@]}

LENGTH=$#


if [ $LENGTH -eq 0 ] || [ $LENGTH -ne 10 ]
then
	args[0]="-h"
	ELEMENTS=1
fi

for ((i=0; i<$ELEMENTS; i++ ))
do

	PARAMETER=${args[${i}]}

	case $PARAMETER in

	-H)
		i=$(( i + 1 ))
		HOSTNAME="${args[${i}]}"
		;;

	-C)
		i=$(( i + 1 ))
		COMMUNITY="${args[${i}]}"
		;;

	-T)

		i=$(( i + 1 ))
		TYPE="${args[${i}]}"
		;;

	-w)
		i=$(( i + 1 ))
		WARNING="${args[${i}]}"
		;;


	-c)
		i=$(( i + 1 ))
		CRITICAL="${args[${i}]}"
		;;

	-h|--help|*)
			echo "Usage:

./check_CMT.sh -H <HOSTNAME> [-C <COMMUNITY>] -T <TYPE> -w <WARNING> -c <CRITICAL>

			TYPE:

			1. CPU
			2. MEM (Memory)
			3. TEMP (Temperature)
			4. SES (Sessions Flow)

-h |  --help --> For help"

			exit
			;;
	esac
done



if [ "$TYPE" = "CPU" ]
then
	CPUUSAGE=$(/usr/bin/snmpwalk -v 2c -c $COMMUNITY $HOSTNAME 1.3.6.1.4.1.2636.3.1.13.1.8.9.1.0.0 | /usr/bin/rev | $AWK '{print $1}' | /usr/bin/rev)

	if [ $CPUUSAGE -le $WARNING ]
	then
		echo "OK - Current CPU Usage is $CPUUSAGE% |c[CPU]=$CPUUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 0

	elif [ $CPUUSAGE -gt $WARNING ] && [ $CRITICAL -le 80 ]
	then
		echo "WARNING - Current CPU Usage is $CPUUSAGE% |c[CPU]=$CPUUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 1

	elif [ $CPUUSAGE -gt $CRITICAL ]
	then

		echo "CRITICAL - Current CPU Usage is $CPUUSAGE% |c[CPU]=$CPUUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 2
        else
                echo "UNKNOWN -  Unable to find the CPU usage"
                exit 3

	fi

elif [ "$TYPE" = "MEM" ]
then
	MEMUSAGE=$(/usr/bin/snmpwalk -v 2c -c $COMMUNITY $HOSTNAME 1.3.6.1.4.1.2636.3.1.13.1.11.9.1.0.0 | /usr/bin/rev | $AWK '{print $1}' | /usr/bin/rev)

	if [ $MEMUSAGE -le $WARNING ]
	then
		echo "OK - Current Memory Usage is $MEMUSAGE% |c[MEM]=$MEMUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 0

	elif [ $MEMUSAGE -gt $WARNING ] && [ $MEMUSAGE -le $CRITICAL ]
	then
		echo "WARNING - Current Memory Usage is $MEMUSAGE% |c[MEM]=$MEMUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 1

	elif [ $MEMUSAGE -gt $CRITICAL ]
	then

		echo "CRITICAL - Current Memory Usage is $MEMUSAGE% |c[MEM]=$MEMUSAGE%;$WARNING;$CRITICAL;0;100"
		exit 2
        else
                echo "UNKNOWN -  Unable to find the MEM usage"
                exit 3
	fi

elif [ "$TYPE" = "TEMP" ]
then
	TEMPERATURE=$(/usr/bin/snmpwalk -v 2c -c $COMMUNITY $HOSTNAME 1.3.6.1.4.1.2636.3.1.13.1.7.9.1.0.0 | /usr/bin/rev | $AWK '{print $1}' | /usr/bin/rev)

	if [ $TEMPERATURE -le $WARNING ]
	then
		echo -e "OK - Current Temperature is $TEMPERATURE \xc2\xb0C | Temperature=$TEMPERATURE;$WARNING;$CRITICAL;0"
		exit 0

	elif [ $TEMPERATURE -gt $WARNING ] && [ $TEMPERATURE -le $CRITICAL ]
	then
		echo -e "WARNING - Current Temperature is $TEMPERATURE \xc2\xb0C | Temperature=$TEMPERATURE;$WARNING;$CRITICAL;0"
		exit 1

	elif [ $TEMPERATURE -gt $CRITICAL ]
	then

		echo -e "CRITICAL - Current Temperature is $TEMPERATURE \xc2\xb0C | Temperature=$TEMPERATURE;$WARNING;$CRITICAL;0"
		exit 2
        else
                echo "UNKNOWN -  Unable to find the TEMP"
                exit 3
	fi

elif [ "$TYPE" = "SES" ]
then
	SESSIONS=$(/usr/bin/snmpwalk -v 2c -c $COMMUNITY $HOSTNAME 1.3.6.1.4.1.2636.3.39.1.12.1.1.1.6.0 | /usr/bin/rev | $AWK '{print $1}' | /usr/bin/rev)

	if [ $SESSIONS -le $WARNING ]
	then
		echo -e "OK - Current Sessions Flow usage is $SESSIONS  | Sessions=$SESSIONS;$WARNING;$CRITICAL;0"
		exit 0

	elif [ $SESSIONS -gt $WARNING ] && [ $SESSIONS -le $CRITICAL ]
	then
		echo -e "WARNING - Current Sessions Flow usage is $SESSIONS | Sessions=$SESSIONS;$WARNING;$CRITICAL;0"
		exit 1

	elif [ $SESSIONS -gt $CRITICAL ]
	then

		echo -e "CRITICAL - Current Sessions Flow usage is $SESSIONS | Sessions=$SESSIONS;$WARNING;$CRITICAL;0"
		exit 2
        else
                echo "UNKNOWN -  Unable to find the Sessions Flow value"
                exit 3
	fi

fi

#END
