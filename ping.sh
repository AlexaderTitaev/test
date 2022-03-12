#!/bin/sh
for IP in `echo $@ | tr -d ','`
do
	ping -W1 -c2 ${IP}
done
