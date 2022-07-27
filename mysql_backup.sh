#!/bin/sh
DT=`date +"%Y-%m-%d"`
WD=`date +"%u"`
MD=`date +"%d"`
BACKUPDIR=/backup
LOG=${BACKUPDIR}/backup.log
TMPDIR=${BACKUPDIR}/tmp
MYSQLBACKUP=${BACKUPDIR}/mysql

check_code()
{
        if [ $1 -ne 0 ]; then
                echo cant make $2 | mailx -s "replica mysql backup error" tit@irk.ru
        fi
}

rm -rf ${TMPDIR}
mkdir -p ${MYSQLBACKUP} ${TMPDIR}
find ${MYSQLBACKUP}/daily -type f -mtime +7 -delete
find ${MYSQLBACKUP}/weekly -type f -mtime +31 -delete
find ${MYSQLBACKUP}/monthly -type f -mtime +365 -delete

ulimit -n 102400

for SERV in test dev prod
do
        mkdir -p ${MYSQLBACKUP}/daily/${SERV}
        mkdir -p ${MYSQLBACKUP}/weekly/${SERV}
        mkdir -p ${MYSQLBACKUP}/monthly/${SERV}

        case ${SERV} in
        test)
                PARAM='--socket=/var/lib/mysql_test/mysql.sock'
                ;;
        dev)
                PARAM='--socket=/var/lib/mysql_dev/mysql.sock'
                ;;
        prod)
                PARAM="--socket=/var/lib/mysql_prod/mysql.sock --user=root --password='pass'"
                ;;
        esac

        /usr/bin/innobackupex --slave-info --parallel=1 ${PARAM} ${TMPDIR}
        check_code $? innobackupex

        /usr/bin/tar jcf ${MYSQLBACKUP}/daily/${SERV}/mysql-${DT}.tbz2 ${TMPDIR}
        check_code $? innobackupex

        rm -rf ${TMPDIR}/*

        if [ ${WD} -eq 1 ]; then
                ln ${MYSQLBACKUP}/daily/${SERV}/mysql-${DT}.tbz2 ${MYSQLBACKUP}/weekly/${SERV}/mysql-${DT}.tbz2
        fi
        if [ ${MD} -eq 1 ]; then
                ln ${MYSQLBACKUP}/daily/${SERV}/mysql-${DT}.tbz2 ${MYSQLBACKUP}/monthly/${SERV}/mysql-${DT}.tbz2
        fi
done
