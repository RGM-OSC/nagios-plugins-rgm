#! /bin/sh
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

## 2006-10-23, Ingo Lantschner (based on the work of Fredrik Wanglund)
## This Plugin gets the uptime from any host (*nix/Windows) by SNMP

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

PROGNAME=$(basename $0)
REVISION=$(echo 'Revision: 0.2 ' )
WARN=$4
CRIT=$5

print_usage() {
	echo "Usage: $PROGNAME <host> <community> <version> <warning> <critical>"
}

print_revision() {
	echo $PROGNAME  - $REVISION
}
print_help() {
	print_revision
	echo ""
	print_usage
	echo ""
	echo "This plugin checks the Uptime through SNMP"
	echo "The treshholds (warning, critical) are in days"
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
	   	print_revision $PROGNAME $REVISION
		exit 0
		;;
	-V)
		print_revision $PROGNAME $REVISION
		exit 0
		;;
	*)

## Einige Plausibilitaetstest

if [ $# -lt 4 ]; then
   print_usage
   exit 3
   fi

if [ $WARN -lt $CRIT ]; then
   echo warning-level must be above the critical!
   exit 3
   fi


## Now we start checking ...
if [ $3 -eq 3 ]; then
	V3="$6"
else
	V3=""
fi

UPT=$(snmpget -c $2 -v $3 $V3 $1 DISMAN-EVENT-MIB::sysUpTimeInstance)
UPTCALC=$(echo $UPT |cut -d "(" -f 2 |cut -d ")" -f 1)
UPTDISPLAY=$(echo $UPT |awk -F ") " '{print $2}')
RES=$?

UPTMIN=$(expr $(echo $UPTCALC) / 6000 )

if  [ $RES = 0 ]; then
      if [ $UPTMIN -lt $CRIT ]; then
         echo CRITICAL: Systemuptime $UPTDISPLAY.
         exit 2
         fi

      if [ $UPTMIN -lt $WARN ]; then
         echo WARNING: Systemuptime $UPTDISPLAY.
         exit 1
         fi

      if [ $UPTMIN -ge $WARN ]; then
         echo OK: Systemuptime $UPTDISPLAY.
         exit 0
         fi

   fi

echo $UPT
exit 3

esac

