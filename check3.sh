#!/bin/sh

get_err()
{
	err=$1
	case $err in
1) printf "Unsupported protocol. This build of curl has no support for this protocol."
  ;;
2) printf "Failed to initialize."
  ;;
3) printf "URL malformed. The syntax was not correct."
  ;;
4) printf "A feature or option that was needed to perform"
  ;;
5) printf "Couldn't resolve proxy. The given proxy host could not be resolved."
  ;;
6) printf "Couldn't resolve host."
  ;;
7) printf "Failed to connect to host."
  ;;
8) printf "Weird server reply. The server sent data curl couldn't parse."
  ;;
9) printf "FTP  access  denied. "
  ;;
10) printf "FTP accept failed. "
  ;;
11) printf "FTP weird PASS reply."
  ;;
12) printf "During an active FTP session while waiting for the server to connect back to curl, the timeout expired."
  ;;
13) printf "FTP weird PASV reply, Curl couldn't parse the reply sent to the PASV request."
  ;;
14) printf "FTP weird 227 format."
  ;;
15) printf "FTP can't get host."
  ;;
16) printf "HTTP/2  error."
  ;;
17) printf "FTP couldn't set binary."
  ;;
18) printf "Partial file. Only a part of the file was transferred."
  ;;
19) printf "FTP couldn't download/access the given file"
  ;;
21) printf "FTP quote error."
  ;;
22) printf "HTTP page not retrieved."
  ;;
23) printf "Write error."
  ;;
25) printf "FTP couldn't STOR file."
  ;;
26) printf "Read error."
  ;;
27) printf "Out of memory."
  ;;
28) printf "Operation timeout."
  ;;
30) printf "FTP  PORT  failed."
  ;;
31) printf "FTP couldn't use REST."
  ;;
33) printf "HTTP range error. The range 'command' didn't work."
  ;;
34) printf "HTTP post error. Internal post-request generation error."
  ;;
35) printf "SSL connect error. The SSL handshaking failed."
  ;;
36) printf "Bad download resume. Couldn't continue an earlier aborted download."
  ;;
37) printf "FILE couldn't read file. Failed to open the file. Permissions?"
  ;;
38) printf "LDAP cannot bind. LDAP bind operation failed."
  ;;
39) printf "LDAP search failed."
  ;;
41) printf "Function not found. A required LDAP function was not found."
  ;;
42) printf "Aborted by callback. An application told curl to abort the operation."
  ;;
43) printf "Internal error. A function was called with a bad parameter."
  ;;
45) printf "Interface error. A specified outgoing interface could not be used."
  ;;
47) printf "Too many redirects. When following redirects, curl hit the maximum amount."
  ;;
48) printf "Unknown option specified to libcurl."
  ;;
49) printf "Malformed telnet option."
  ;;
51) printf "The peer's SSL certificate or SSH MD5 fingerprint was not OK."
  ;;
52) printf "The server didn't reply anything"
  ;;
53) printf "SSL crypto engine not found."
  ;;
54) printf "Cannot set SSL crypto engine as default."
  ;;
55) printf "Failed sending network data."
  ;;
56) printf "Failure in receiving network data."
  ;;
58) printf "Problem with the local certificate."
  ;;
59) printf "Couldn't use specified SSL cipher."
  ;;
60) printf "Peer certificate cannot be authenticated with known CA certificates."
  ;;
61) printf "Unrecognized transfer encoding."
  ;;
62) printf "Invalid LDAP URL."
  ;;
63) printf "Maximum file size exceeded."
  ;;
64) printf "Requested FTP SSL level failed."
  ;;
65) printf "Sending the data requires a rewind that failed."
  ;;
66) printf "Failed to initialise SSL Engine."
  ;;
67) printf "The user name, password, or similar was not accepted and curl failed to log in."
  ;;
68) printf "File not found on TFTP server."
  ;;
69) printf "Permission problem on TFTP server."
  ;;
70) printf "Out of disk space on TFTP server."
  ;;
71) printf "Illegal TFTP operation."
  ;;
72) printf "Unknown TFTP transfer ID."
  ;;
73) printf "File already exists (TFTP)."
  ;;
74) printf "No such user (TFTP)."
  ;;
75) printf "Character conversion failed."
  ;;
76) printf "Character conversion functions required."
  ;;
77) printf "Problem with reading the SSL CA cert (path? access rights?)."
  ;;
78) printf "The resource referenced in the URL does not exist."
  ;;
79) printf "An unspecified error occurred during the SSH session."
  ;;
80) printf "Failed to shut down the SSL connection."
  ;;
82) printf "Could not load CRL file, missing or wrong format (added in 7.19.0)."
  ;;
83) printf "Issuer check failed (added in 7.19.0)."
  ;;
84) printf "The FTP PRET command failed"
  ;;
85) printf "RTSP: mismatch of CSeq numbers"
  ;;
86) printf "RTSP: mismatch of Session Identifiers"
  ;;
87) printf "unable to parse FTP file list"
  ;;
88) printf "FTP chunk callback reported error"
  ;;
89) printf "No connection available, the session will be queued"
  ;;
90) printf "SSL public key does not matched pinned public key"
  ;;
91) printf "Invalid SSL certificate status."
  ;;
92) printf "Stream error in HTTP/2 framing layer."
  ;;
	esac
}

get_code()
{
	retcode=$1
	errcode=$2
	proto=$3
	dom=$4
	port=$5
	if [ "${retcode}" != "000" ]; then
		printf ${retcode}
		if [ ${retcode} -eq 301 ] || [ ${retcode} -eq 302 ]; then
			LOC=`curl -Ss -I ${proto}://${dom}:${port} | grep -i ^Location | awk '{ print $2 }' | tr -d '\n' | tr -d '\r'`
			printf " ${LOC}"
		fi
		if [ ${retcode} -eq 200 ]; then
			LOC=`curl -Ss ${proto}://${dom}:${port} | grep 'Welcome to nginx' | tr -d '\n' | tr -d '\r'`
			printf " ${LOC}"
		fi
	else
		get_err ${errcode}
	fi
}

CURL='curl -s -o /dev/null -w %{http_code} --connect-timeout 2 --max-time 3 '

while read STR
do
	FIP=`echo ${STR} | awk '{ print $1}'`
	DOM=`echo ${STR} | awk '{ print $2}'`
	STEND=`echo ${STR} | awk '{ print $3}'`
	printf "${STEND};"
	IP=`dig a ${DOM} +short`
	if [ ${IP} = ${FIP} ]; then
        	printf "${DOM};${FIP};${IP};yes;"
	else
        	printf "${DOM};${FIP};${IP};no;"
	fi

	for PORT in 80 8080 8081 8082 9080
	do
	        RCODE=`${CURL} http://${DOM}:${PORT}`
		CODE=$?
		get_code ${RCODE} ${CODE} http ${DOM} ${PORT}
		printf ";"
	done
	for PORT in 443 8443 9443
	do
	        RCODE=`${CURL} https://${DOM}:${PORT}`
		CODE=$?
		get_code ${RCODE} ${CODE} https ${DOM} ${PORT}
		printf ";"
	done
	printf "\n"
done
