#!/bin/sh
# Copyleft by Alexander Titaev tit@irk.ru

HOSTNAME=$1
PASSWD=$2
DISK=$3
TPL=$4

if [ -z ${TPL} ]; then
cat << EOF
 use:
 	'./hetzner.sh hostname password [mir|jour|single] tpl'
 	where 
 	hostname - hostname for this server
 	password - root password
	'[mir|jour|any]'
	mir - build gmirror
	jour - build gmirror+gjournal
	single - use only first hdd
	tpl - DS template like
		FreeBSD-8.2-amd64
		FreeBSD-8.2-amd64-ispmgr
		FreeBSD-9.0-amd64
		FreeBSD-9.0-amd64-ispmgr
		FreeBSD-8.2-i386
		FreeBSD-8.2-i386-ispmgr
EOF
	exit
fi

/bin/mkdir /mfs
/sbin/mdmfs -s 600M md /mfs

if [ $? = 1 ]; then
	echo cant create memory disk
	exit
fi
cd /mfs

DISKS=`/sbin/sysctl -n kern.disks`

HD=`echo $DISKS | xargs -n1 echo | grep ad | sort -td -k2 -n | head -1`
if [ -z ${HD} ]; then
	HD=`echo $DISKS | xargs -n1 echo | grep da | sort -ta -k2 -n | head -1`
	if [ -z ${HD} ]; then
		echo cant find any ad or da disks
		exit
	fi
fi

#check drive size
fdisk -I /dev/${HD}
HD_SIZE=`gpart list ${HD} | grep -A1 ${HD}$ | grep Mediasize | awk '{ print $2 }'`
echo HD_SIZE "${HD_SIZE}"

echo $DISKS | tr ' ' '\n' | while read DSK
do
	gmirror clear -v ${DSK}
	gpart destroy -F ${DSK}
	dd if=/dev/zero of=/dev/${DSK} count=1 bs=1024
done

if [ ${HD_SIZE} -gt 2000398934016 ]; then
	GPART=1

	if [ ${DISK} = "mir" ] || [ ${DISK} = "jour" ]; then
		/sbin/gmirror load
		if [ $? = 1 ]; then
			echo cant load module geom_mirror
			exit
		fi
		/sbin/gmirror label -v -b load gm0 ${DISKS}
		/sbin/gpart create -s gpt mirror/gm0
		HDD="/dev/mirror/gm0"
	else
		HDD="/dev/${HD}"
	fi

	ROOT_FS="${HDD}p3"
	SWAP_FS="${HDD}p2"

	/sbin/gpart create -s gpt ${HDD}
	/sbin/gpart add -t freebsd-boot -s 128k ${HDD}
	/sbin/gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ${HDD}
	/sbin/gpart add -t freebsd-swap -s 8G ${HDD}

	if [ ${DISK} = "jour" ]; then
		JOUR_SIZE=`/sbin/sysctl -n hw.physmem | awk '{ print int($1*3.5/1024/1024/1024)}'`
		/sbin/gpart add -t freebsd-swap -s ${JOUR_SIZE}G ${HDD}
		/sbin/gpart add -t freebsd-ufs ${HDD}

		ARCH=`/usr/bin/uname -m`
		if [ ${ARCH} = "amd64" ]; then
			/sbin/kldload /nfs/8_64/boot/kernel/geom_journal.ko
		else
			/sbin/kldload /nfs/8_32/boot/kernel/geom_journal.ko
		fi
		if [ $? = 1 ]; then
			echo cant load module geom_journal
			exit
		fi

		/sbin/gjournal label /dev/mirror/gm0p4 /dev/mirror/gm0p3
		ROOT_FS="${HDD}p4.journal"
		/bin/sleep 5
	        /sbin/newfs -J ${ROOT_FS}
	        /sbin/mount -o async ${ROOT_FS} /mnt
	else
		/sbin/gpart add -t freebsd-ufs ${HDD}
		/sbin/newfs ${ROOT_FS}
		/sbin/mount ${ROOT_FS} /mnt
	fi
else
	if [ ${DISK} = "mir" ] || [ ${DISK} = "jour" ]; then
		/sbin/gmirror load
		if [ $? = 1 ]; then
			echo cant load module geom_mirror
			exit
		fi
		/sbin/gmirror label -v -b load gm0 ${DISKS}
		HDD="/dev/mirror/gm0"
	else
		HDD="/dev/${HD}"
	fi
	/sbin/fdisk -I ${HDD}
	

	if [ ${DISK} = "jour" ]; then
		JOUR_SIZE=`/sbin/sysctl -n hw.physmem | awk '{ print int($1*3.5/1024/1024/1024)}'`
		/bin/cat > /mfs/labels << EOF
a:      *       *       4.2BSD
b:      8G      *       swap
c:      *       *       unused
d:	${JOUR_SIZE}G	*	swap
EOF
	else
		/bin/cat > /mfs/labels << EOF
a:      *       *       4.2BSD
b:      8G      *       swap
c:      *       *       unused
EOF
	fi
	
	ROOT_FS="${HDD}s1a"
	SWAP_FS="${HDD}s1b"

	echo "/sbin/newfs create"
	/sbin/bsdlabel -R -B ${HDD}s1 /mfs/labels
	/bin/sleep 5

	if [ ${DISK} = "jour" ]; then
		/sbin/gjournal clear -v /dev/mirror/gm0s1a /dev/mirror/gm0s1d
	
		ARCH=`/usr/bin/uname -m`
		if [ ${ARCH} = "amd64" ]; then
			/sbin/kldload /nfs/8_64/boot/kernel/geom_journal.ko
		else
			/sbin/kldload /nfs/8_32/boot/kernel/geom_journal.ko
		fi
		if [ $? = 1 ]; then
			echo cant load module geom_journal
			exit
		fi
	
		/sbin/gjournal label /dev/mirror/gm0s1a /dev/mirror/gm0s1d
		ROOT_FS="${HDD}s1a.journal"
		/bin/sleep 5
	        /sbin/newfs -J ${ROOT_FS}
	        /sbin/mount -o async ${ROOT_FS} /mnt
	else
		/sbin/newfs ${ROOT_FS}
		/sbin/mount ${ROOT_FS} /mnt
	fi
	
fi

if [ $? = 1 ]; then
	echo cant mount !
	exit
fi

echo download template
/usr/bin/ftp http://ru.download.ispsystem.com/DStemplate/${TPL}/disk.tar.bz2
if [ $? != 0 ]; then
	echo cant download template ${TPL}
	exit
fi

echo extract data from template
/usr/bin/tar -jpxf disk.tar.bz2 -C /mnt

GW=`route -n get default | grep gateway | awk '{ print $2 }'`
INT=`route -n get default | grep interface | awk '{ print $2 }'`
IP=`netstat -rn | grep -w UHS | grep -v '::'  | awk '{ print $1 }'`
MASK=`netstat -rn | grep -w U | grep -v '::' | awk '{ print $1 }' | awk -F\/ '{ print $2 }'`
MEDIA='media 100baseTX mediaopt full-duplex,flag0'

echo change system settings
/bin/cat >> /mnt/etc/rc.conf << EOF
defaultrouter="${GW}"
hostname="${HOSTNAME}"
ifconfig_${INT}="inet ${IP}/${MASK}" # ${MEDIA}"
sshd_enable="YES"
EOF


if [ ${DISK} = "jour" ]; then
	echo 'fsck_y_enable="YES"' >> /mnt/etc/rc.conf
	/bin/cat > /mnt/boot/loader.conf << EOF
geom_mirror_load="YES"
geom_journal_load="YES"
ahci_load="YES"
EOF
	/bin/cat > /mnt/etc/fstab << EOF
# Device                Mountpoint      FStype  Options         Dump    Pass#
${SWAP_FS}             none            swap    sw              0       0
${ROOT_FS}		/               ufs    async,rw,groupquota,userquota              1       1
EOF
elif [ ${DISK} = "mir" ]; then
	/bin/cat > /mnt/boot/loader.conf << EOF
geom_mirror_load="YES"
ahci_load="YES"
EOF
	/bin/cat > /mnt/etc/fstab << EOF
# Device                Mountpoint      FStype  Options         Dump    Pass#
${SWAP_FS}             none            swap    sw              0       0
${ROOT_FS}		/               ufs    rw,groupquota,userquota              1       1
EOF
else
	/bin/cat > /mnt/etc/fstab << EOF
# Device                Mountpoint      FStype  Options         Dump    Pass#
${SWAP_FS}             none            swap    sw              0       0
${ROOT_FS}		/               ufs    rw,groupquota,userquota              1       1
EOF
fi


echo change root password
echo ${PASSWD} | /usr/sbin/pw -V /mnt/etc/ usermod root -h 0

/bin/cat > /mnt/etc/resolv.conf << EOF
nameserver 127.0.0.1
nameserver 213.133.98.98
nameserver 213.133.99.99
nameserver 213.133.100.100
EOF

cp /mnt/sbin/tunefs .
cp /mnt/lib/libufs.so.6 /lib

/sbin/umount /mnt
if [ ${TPL} = 'FreeBSD-9.0-amd64' ] || [ ${TPL} = 'FreeBSD-9.0-amd64-ispmgr' ]; then
        if [ ${DISK} = 'mir' ] || [ ${DISK} = 'single' ]; then
		echo set SUJ
                ./tunefs -j enable ${ROOT_FS}
        fi
fi

echo Complete, reboot system.
