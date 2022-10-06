#!/bin/sh

echo "****up****"
IPTABLES=/usr/sbin/iptables
IPSET=/usr/sbin/ipset
LDAP_NAME=${PLUTO_XAUTH_ID}
LOG=/var/log/iptables.log
case ${PLUTO_VERB} in
up-client)

#       echo ${IPSET} create ${LDAP_NAME} nethash >> ${LOG}
	${IPSET} create ${LDAP_NAME} nethash
#       echo ${IPSET} flush ${LDAP_NAME} >> ${LOG}
	${IPSET} flush ${LDAP_NAME}

	# remove all rules with this REMOTE IP
	/usr/sbin/iptables-save | grep -E "${PLUTO_PEER_CLIENT}[[:space:]]" | perl -p -e 's/^-A(.+)/iptables -D$1/' | sh

	STR=$(/usr/bin/grep ^${LDAP_NAME}: /etc/openvpn/allow) 
	if [ "${STR}" != "" ]; then
		echo ${STR} | /usr/bin/awk -F: '{ print $2 }' | /usr/bin/tr ',' '\n' | grep -E '^[1-9]' | while read IP
		do
#			echo ${IPSET} add ${LDAP_NAME} ${IP} >> ${LOG}
			${IPSET} add ${LDAP_NAME} ${IP}
		done
#		echo ${IPTABLES} -I FORWARD -s ${PLUTO_PEER_CLIENT} -m set --match-set ${LDAP_NAME} dst -j ACCEPT >> ${LOG}
		${IPTABLES} -I FORWARD -s ${PLUTO_PEER_CLIENT} -m set --match-set ${LDAP_NAME} dst -j ACCEPT
		${IPTABLES} -I FORWARD -s ${PLUTO_PEER_CLIENT} -j LOG --log-prefix "IKEV2:${LDAP_NAME}:" --log-level 6
	fi
	;;
down-client)
	${IPTABLES} -D FORWARD -s ${PLUTO_PEER_CLIENT} -j LOG --log-prefix "IKEV2:${LDAP_NAME}:" --log-level 6
	${IPTABLES} -D FORWARD -s ${PLUTO_PEER_CLIENT} -m set --match-set ${LDAP_NAME} dst -j ACCEPT
	${IPSET} flush ${LDAP_NAME}
	${IPSET} destroy ${LDAP_NAME}
	;;
esac
