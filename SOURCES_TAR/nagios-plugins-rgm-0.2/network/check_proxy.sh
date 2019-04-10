#!/bin/bash

PROXY_HOST="$3"
PROXY_PORT="$4"
PROXY_USER="$1"
PROXY_PASS="$2"

URL="$5"
EXPR_FAULT1="$6"
EXPR_FAULT2="$7"
COMMAND="/usr/bin/wget"


export http_proxy="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}"

RETURN=$(${COMMAND} ${URL} -O - | grep -e ${EXPR_FAULT1} | grep -e ${EXPR_FAULT2} 2>/dev/null)

if [ ! -z "${RETURN}" ];
then
	echo "Ok : Page bloquée"
	exit 0
else 
	echo "Critical : Page non bloquée. Filtrage non fonctionnel."
	exit 2
fi
