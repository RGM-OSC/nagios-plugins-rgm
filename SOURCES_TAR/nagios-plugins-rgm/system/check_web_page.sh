#!/bin/bash
unset PATH
export PATH='/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin'

GetSHA=0
export LANG=en_US

usage() {
echo "Usage :check_web_page.sh
	-r sha1 of returned page expected
	-p page to check"
exit 2
}

if [ "${3}" = "" ]; then usage; fi

ARGS="$(echo $@ |sed -e 's:-[a-Z] :\n&:g' | sed -e 's: ::g')"
for i in $ARGS; do
        if [ -n "$(echo ${i} | grep "^\-p")" ]; then PAGE="$(echo ${i} | cut -c 3-)"; if [ ! -n ${PAGE} ]; then usage;fi;fi
        if [ -n "$(echo ${i} | grep "^\-r")" ]; then RETURNSHA="$(echo ${i} | cut -c 3-)"; if [ ! -n ${RETURNSHA} ]; then usage;fi;fi
done

if [ ! -n "$RETURNSHA" ]; then
	GetSHA=1
fi

if [ ! -d /tmp/tmp-internal ]; then mkdir -p /tmp/tmp-internal; fi
TMPDIR="$(mktemp -d /tmp/tmp-internal/web-internal.XXXXXXXX)"

if [ ! "$(echo $PAGE | cut -c -4  | tr [:upper:] [:lower:])" = "http" ]; then
	echo "Url must start with http://"
	usage
fi

wget -q -O $TMPDIR/page.out.html $PAGE

cat $TMPDIR/page.out.html | cut -c -15 > $TMPDIR/page.out.html.filtered
cp $TMPDIR/page.out.html.filtered $TMPDIR/page.out.html

if [ $GetSHA -gt 0 ]; then
	sha1sum $TMPDIR/page.out.html
	rm -rf ${TMPDIR}
       exit 2
fi

SHA="$(sha1sum $TMPDIR/page.out.html | awk '{print $1}')"

if [ ! "$SHA" = "$RETURNSHA" ]; then
	echo "CRITICAL: The required page doesnt match expected checksum. $SHA"
	rm -rf ${TMPDIR}
	exit 2
fi

echo "OK: The page $PAGE match the expected checksum"
rm -rf ${TMPDIR}
exit 0
