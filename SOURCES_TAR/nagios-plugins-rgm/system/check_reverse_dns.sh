#!/bin/bash
export LANG="en_US.UTF-8"

usage() {
	echo "Usage :check_reverse_dns.sh
		-H DNS server to check
		-s Query to submit
		-a Expected answer
	"
	exit 2
}
COUNTWARNING=0
COUNTCRITICAL=0

ARGS="$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')"
for i in $ARGS; do
	if [ -n "$(echo ${i} | grep "^\-H")" ]; then Host_Address="$(echo ${i} | sed -e 's: ::g' | cut -c 3-)"; if [ ! -n ${Host_Address} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-a")" ]; then Expected_Answer="$(echo ${i} | cut -c 3-)"; if [ ! -n ${Expected_Answer} ]; then usage;fi;fi
	if [ -n "$(echo ${i} | grep "^\-s")" ]; then Submitted_Query="$(echo ${i} | cut -c 3-)"; if [ ! -n ${Submitted_Query} ]; then usage;fi;fi
done

COMMAND=dig
Answer=$(dig +short -x ${Submitted_Query} @${Host_Address})

if [ ${Answer} == ${Expected_Answer} ]
then
	OUTPUT="PTR of ${Submitted_Query} answer ${Answer}";
else
	OUTPUT="Bad DNS answer. PTR of ${Submitted_Query} answer ${Answer}";
	COUNTCRITICAL=1
fi


if [ `echo $OUTPUT | tr ',' '\n' | wc -l` -ge 2 ] ;then
	if [ $COUNTCRITICAL -gt 0 ] && [ $COUNTWARNING -gt 0 ]; then
		echo "CRITICAL: Click for detail, "
	else
		if [ $COUNTCRITICAL -gt 0 ]; then echo "CRITICAL: Click for detail, " ; fi
		if [ $COUNTWARNING -gt 0 ]; then echo "WARNING: Click for detail, "; fi
	fi
	if [ ! $COUNTCRITICAL -gt 0 ] && [ ! $COUNTWARNING -gt 0 ]; then echo "OK: Click for detail, "; fi
	OUTPUT="$(echo $OUTPUT | tr ',' '\n')"
fi
if [ -n "$PERF" ]; then
	OUTPUT="$OUTPUT | $PERF"
fi
echo -n "$OUTPUT" | tr ',' ' '
if [ $COUNTCRITICAL -gt 0 ]; then exit 2 ; fi
if [ $COUNTWARNING -gt 0 ]; then exit 1 ; fi
exit 0
												
