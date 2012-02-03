#!/bin/sh
# Sends an xAP query on 127.0.0.1:3639 to the given xAP address.
# The *.*.> wildcard address will be used if no address is given.
# Requires a UDP-capable netcat.
# (C)2012 Mike Bourgeous

if [ "$1" = "" ]; then
	addr='*.*.>'
else
	addr="$1"
fi

echo "Querying $addr"
printf "xap-header\n{\nv=12\nhop=1\nuid=FF010100\nclass=xAPBSC.query\nsource=a.b.c\ntarget=$addr\n}\nrequest\n{\n}\n" | \
	nc -q1 -u 127.0.0.1 3639
