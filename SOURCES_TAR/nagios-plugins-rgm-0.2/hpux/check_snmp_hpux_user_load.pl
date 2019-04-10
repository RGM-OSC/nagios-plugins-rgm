#!/bin/sh


############################## check_snmp_hpux ##############
# Version : 0.1
# Date :  November 27 2008
# Author  : Alain van der Heiden & Remco Hage
# With help from: Albert-Jan Stevens
# Help : http://www.realopenit.nl
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# help : ./check_snmp_hpux_mem

PROGNAME=$0
DEPTH=2     # Achter komma bij percentage berekening
HOSTNAME="$1"
COMMUNITY="$2"
WARNING=$3
CRITICAL=$4


print_help() {
	echo $PROGNAME
	echo ""
	echo "Usage: $PROGNAME <hostname> <community> <warning> <critical>"
	echo ""
	echo "This plugin checks the user load"
	echo "Tests if load is less then <warning> and <critical>"
	echo ""
	exit 0
}


case "$1" in
	--help)
		print_help
		exit 0
		;;
	-h)
		print_help
		exit 0
		;;
	--version)
   		echo $PROGNAME v0.1
		exit 0
		;;
	-V)
		echo $PROGNAME v0.1
		exit 0
		;;
	*)
		LOAD1=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Oq -Ov .1.3.6.1.4.1.11.2.3.1.1.13.0`
		TOTALLOAD1=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Ov .1.3.6.1.4.1.11.2.3.1.1.1.0 | cut -d '(' -f2 | cut -d ')' -f1`
		sleep 3
		LOAD2=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Oq -Ov .1.3.6.1.4.1.11.2.3.1.1.13.0`
		TOTALLOAD2=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Ov .1.3.6.1.4.1.11.2.3.1.1.1.0 | cut -d '(' -f2 | cut -d ')' -f1`

		LOAD="`expr $LOAD2 - $LOAD1`"
		TOTALLOAD="`expr $TOTALLOAD2 - $TOTALLOAD1`"

		## Percentage calculation

		CALDEPTH=$(($LOAD*100))
		PERCENT=$(echo "scale=$DEPTH ; $CALDEPTH/$TOTALLOAD"| bc)
		INTPERCENT=$(echo "scale=0 ; $CALDEPTH/$TOTALLOAD"| bc)




		if [ $CRITICAL -le $INTPERCENT ]; then
			echo "CRITICAL: CPU user=$PERCENT"
			exit 2
		elif [ $WARNING -le $INTPERCENT ]; then
			echo "WARNING: CPU user=$PERCENT"
			exit 1
		else
			echo "OK: CPU user=$PERCENT"
			exit 0
		fi
		;;
esac
