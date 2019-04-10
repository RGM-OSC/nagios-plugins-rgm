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
	echo "This plugin checks the total and freememory on HP-UX servers."
	echo "Tests if free memory is less then <warning> and <critical>"
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
		FREEMEM=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Oq -Ov .1.3.6.1.4.1.11.2.3.1.1.7.0`
		TOTALMEM=`snmpwalk -v 2c -c "$COMMUNITY" "$HOSTNAME" -Oq -Ov .1.3.6.1.4.1.11.2.3.1.1.8.0`

		## Conversion KB -> MB

		FREEMB=$(echo "scale=0 ; $FREEMEM/1024"| bc)
		TOTALMB=$(echo "scale=0 ; $TOTALMEM/1024"| bc)


		## Percentage calculation

		CALDEPTH=$(($FREEMEM*100))
		PERCENT=$(echo "scale=$DEPTH ; $CALDEPTH/$TOTALMEM"| bc)
		INTPERCENT=$(echo "scale=0 ; $CALDEPTH/$TOTALMEM"| bc)


		if [ $CRITICAL -ge $INTPERCENT ]; then
			echo "CRITICAL: Mem: $TOTALMB MB (100%) / $FREEMB MB ($PERCENT%)"
			exit 2
		elif [ $WARNING -ge $INTPERCENT ]; then
			echo "WARNING: Mem: $TOTALMB MB (100%) / $FREEMB MB ($PERCENT%)"
			exit 1
		else
			echo "OK: Mem: $TOTALMB MB (100%) / $FREEMB MB ($PERCENT%)"
			exit 0
		fi
		;;
esac
