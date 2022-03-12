#!/bin/sh
IP=$1
SSH='ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=1 -o ConnectionAttempts=1 '
CMD='yum list installed | grep samba || dpkg -l | grep samba'

echo ${IP} >> rep.txt
${SSH} ${IP} ${CMD} >> rep.txt
if [ $? -eq 0 ]; then
	echo --------------------------------- >> rep.txt
	exit
fi
${SSH} titaev.ab@${IP} "sudo yum list installed | grep samba || sudo dpkg -l | grep samba" >> rep.txt
if [ $? -eq 0 ]; then
	echo --------------------------------- >> rep.txt
	exit
fi
for KEY in tst pp nts prod dev
do
	${SSH} -i ./${KEY}  ${IP} ${CMD} >> rep.txt
	if [ $? -eq 0 ]; then
		echo --------------------------------- >> rep.txt
		exit
	fi
	${SSH} -i ./${KEY}  devops@${IP} "sudo yum list installed | grep samba || sudo dpkg -l | grep samba" >> rep.txt
	if [ $? -eq 0 ]; then
		echo --------------------------------- >> rep.txt
		exit
	fi
done
echo ========= Can not pull over SSH ======= >> rep.txt
