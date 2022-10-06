#!/bin/sh
for IP in `echo $@ | tr -d ','`
do
	ping -W1 -c1 ${IP}
done
