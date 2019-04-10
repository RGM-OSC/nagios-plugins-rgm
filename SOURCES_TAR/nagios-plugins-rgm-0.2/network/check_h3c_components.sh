#!/bin/bash
# bash script to check various components in an HP/H3C S51xx switch
# Can check IRF-connected stacks too.
# lajo@kb.dk / 20120724

#set -x
HOST=$1
COMMUNITY=$2
OID=.1.3.6.1.4.1.25506.2.6.1.1.1.1.19
statustext[1]="Not Supported"
statustext[3]="POST Failure"
statustext[11]="PoE Error"
statustext[22]="Stack Port Blocked"
statustext[23]="Stack Port Failed"
statustext[31]="SFP Recieve Error"
statustext[32]="SFP Send Error"
statustext[33]="SFP Send and Receive Error"
statustext[41]="Fan Error"
statustext[51]="Power Supply Error"
statustext[61]="RPS Error"
statustext[71]="Module Faulty"
statustext[81]="Sensor Error"
statustext[91]="Hardware Faulty"

# Make the array separate on newlines only.
IFS='
'
component=( $( snmpwalk -v2c -OEqv -c $COMMUNITY $HOST .1.3.6.1.2.1.47.1.1.1.1.2 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi
status=( $( snmpwalk -v2c -OEqv -c $COMMUNITY $HOST .1.3.6.1.4.1.25506.2.6.1.1.1.1.19 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi

errors=0
for (( i = 0 ; i < ${#component[@]} ; i++ )) do
  # Don't check for "OK" and "SFP Receive Error". The latter triggers an inserted
  # SFP without link which may be a typical situation for many.
  if [ ${status[$i]} -ne 2 -a ${status[$i]} -ne 31 ]; then
    # Strip out quotes from the component description
    s=${component[$i]}
    echo CRITICAL: ${s//\"}: ${statustext[${status[$i]}]}
    errors=1
  fi
done

if [ $errors -gt 0 ]; then
  exit 2
else
  echo "All components OK"
fi
