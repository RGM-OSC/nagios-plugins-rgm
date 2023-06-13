#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

export LANG="fr_FR.UTF-8"

usage() {
echo "Usage :check_ucopia.sh
        -t Could be Temp, HA, Users, Web, SQL, URLSnif, Portal, WebProxy, DHCPServer, DNS, StaticIP, LDAP
	-C Community
	-H Host target
        -w Warning Free space available
        -c Critical Free space available"
exit 2
}

OIDTemp=.1.3.6.1.4.1.31218.3.3.0
OIDConnectedUsers=1.3.6.1.4.1.31218.3.1.0
OIDHA=.1.3.6.1.4.1.31218.4.11.0
OIDWeb=.1.3.6.1.4.1.31218.4.1.0
OIDSQL=.1.3.6.1.4.1.31218.4.2.0
OIDurlSnif=.1.3.6.1.4.1.31218.4.3.0
OIDportal=.1.3.6.1.4.1.31218.4.4.0
OIDwebProxy=.1.3.6.1.4.1.31218.4.5.0
OIDdhcpServer=.1.3.6.1.4.1.31218.4.8.0
OIDdns=.1.3.6.1.4.1.31218.4.9.0
OIDstaticip=.1.3.6.1.4.1.31218.4.10.0
OIDldapDirectory=.1.3.6.1.4.1.31218.4.12.0

if [ "${6}" = "" ]; then usage; fi

WARNING=0
CRITICAL=0

ARGS="$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')"

for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-t")" ]; then TYPE="$(echo ${i} | sed -e 's: ::g' | cut -c 3- | tr '[a-z]' '[A-Z]')"; if [ ! -n ${TYPE} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-C")" ]; then COMMUNITY="$(echo ${i} | cut -c 3-)"; if [ ! -n ${COMMUNITY} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-H")" ]; then HOSTTARGET="$(echo ${i} | cut -c 3-)"; if [ ! -n ${HOSTTARGET} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-w")" ]; then WARNING="$(echo ${i} | cut -c 3-)"; if [ ! -n ${WARNING} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-c")" ]; then CRITICAL="$(echo ${i} | cut -c 3-)"; if [ ! -n ${CRITICAL} ]; then usage;fi;fi
done


COUNTWARNING=0
COUNTCRITICAL=0


OUTPUT=" "

if [ "$TYPE" == "TEMP" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDTemp | cut -d' ' -f4-)"
	if [ $TEST -gt $CRITICAL ] ; then
		OUTPUT="Critical: Temp $TEST C"
		COUNTCRITICAL=1
	else
		if [ $TEST -gt $WARNING ]; then
			OUTPUT="Warning: Temp $TEST C"
			COUNTWARNING=1
		fi
	fi
	if [ $TEST -le $WARNING ]; then
		OUTPUT="Ok: Temp $TEST C"
	fi
fi

if [ "$TYPE" == "HA" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDHA | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: HA Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: HA Activated"
	fi
fi

if [ "$TYPE" == "USERS" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDConnectedUsers | cut -d' ' -f4-)"
	if [ $TEST -gt $CRITICAL ] ; then
		OUTPUT="Critical: Connected Users $TEST"
		COUNTCRITICAL=1
	else
		if [ $TEST -gt $WARNING ]; then
			OUTPUT="Warning: Connected Users $TEST"
			COUNTWARNING=1
		fi
	fi
	if [ $TEST -le $WARNING ]; then
		OUTPUT="Ok: Connected Users $TEST"
	fi
fi

if [ "$TYPE" == "WEB" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDWeb | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: Web Server Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: Web Server Activated"
	fi
fi

if [ "$TYPE" == "SQL" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDSQL | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: SQL Server Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: SQL Server Activated"
	fi
fi

if [ "$TYPE" == "URLSNIF" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDurlSnif | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: URL Sniffer Service Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: URL Sniffer Service Activated"
	fi
fi

if [ "$TYPE" == "PORTAL" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDportal | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: Web Portal Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: Web Portal Activated"
	fi
fi

if [ "$TYPE" == "WEBPROXY" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDwebProxy | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: Web Proxy Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: Web Proxy Activated"
	fi
fi

if [ "$TYPE" == "DHCPSERVER" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDdhcpServer | cut -d' ' -f4-)"
	TESTHA="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDHA | cut -d' ' -f4-)"
	if [ "$TESTHA" != "1" ]; then
		if [ "$TEST" != "1" ]; then
			OUTPUT="Critical: DHCP Server Failed"
			COUNTCRITICAL=1
		fi
	else
		if [ "$TEST" != "1" ];then
			OUTPUT="This is slave server. DHCP server is disable."
		else
			OUTPUT="Ok: DHCP Server Activated"
		fi
	fi
fi

if [ "$TYPE" == "DNS" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDdns | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: DNS Server Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: DNS Server Activated"
	fi
fi

if [ "$TYPE" == "STATICIP" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDstaticip | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: Static IP Management Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: Static IP Management Activated"
	fi
fi

if [ "$TYPE" == "LDAP" ]; then
	TEST="$(snmpwalk -c $COMMUNITY -v 2c $HOSTTARGET -On $OIDldapDirectory | cut -d' ' -f4-)"
	if [ "$TEST" != "1" ]; then
		OUTPUT="Critical: LDAP Directory Failed"
		COUNTCRITICAL=1
	else
		OUTPUT="Ok: LDAP Directory Activated"
	fi
fi

if [ $(echo $OUTPUT | tr ',' '\n' | wc -l) -gt 2 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
fi

echo -n "$OUTPUT" | tr ',' ' '


if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0

