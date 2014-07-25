#!/bin/sh

# Southbridge PostgreSQL backup script by Igor Olemskoi <igor@southbridge.ru> (based on AutoMySQLBackup)

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
DATE=`date +%Y-%m-%d_%Hh%Mm`				# Datestamp e.g 2002-09-21
DOW=`date +%A`						# Day of the week e.g. Monday
DNOW=`date +%u`						# Day number of the week 1 to 7 where 1 represents Monday
DOM=`date +%d`						# Date of the Month e.g. 27
M=`date +%B`						# Month e.g January
W=`date +%V`						# Week Number e.g 37
VER=0.1							# Version Number
LOGFILE=$BACKUPDIR/$DBHOST-`date +%s`.log		# Logfile Name
LOGERR=$BACKUPDIR/ERRORS_$DBHOST-`date +%s`.log		# Logfile Name
BACKUPFILES=""
OPT="--encoding=utf-8 --clean --no-owner"		# OPT string for use with pg_dump ( see man pg_dump )
PORT="5432"						# Port

LOCATION="$(cd -P -- "$(dirname -- "$0")" && pwd -P)/.."

if [ -f "$LOCATION/etc/postgresql-backup.conf.dist" ]; then
    . "$LOCATION/etc/postgresql-backup.conf.dist"
    if [ -f "$LOCATION/etc/postgresql-backup.conf" ]; then
	. "$LOCATION/etc/postgresql-backup.conf"
    fi
    if [ -f "$LOCATION/etc/postgresql-backup.local.conf" ]; then
	. "$LOCATION/etc/postgresql-backup.local.conf"
    fi
else
    echo "postgresql-backup.conf not found"
    exit 0
fi

DBEXCLUDE+=" template0 template1"

if [ ! "$BACKUP_DAYS" ];
    then
        BACKUP_DAYS=7
fi
if [ ! "$DO_SQL_DUMP" ];
    then
        DO_SQL_DUMP="yes"
fi
                                
if [ ! "$DO_HOT_BACKUP" ];
    then
        DO_HOT_BACKUP="no"
fi
                                                                                                
# Create required directories
if [ ! -e "/var/lib/pgsql.backup" ]             # Check Backup Directory exists.
        then
        mkdir -p "/var/lib/pgsql.backup"
fi
                    
if [ ! -e "$BACKUPDIR" ]		# Check Backup Directory exists.
	then
	mkdir -p "$BACKUPDIR"
fi

if [ ! -e "$BACKUPDIR/daily" ]		# Check Daily Directory exists.
	then
	mkdir -p "$BACKUPDIR/daily"
fi

if [ ! -e "$BACKUPDIR/weekly" ]		# Check Weekly Directory exists.
	then
	mkdir -p "$BACKUPDIR/weekly"
fi

if [ ! -e "$BACKUPDIR/monthly" ]	# Check Monthly Directory exists.
	then
	mkdir -p "$BACKUPDIR/monthly"
fi

if [ "$LATEST" = "yes" ]
then
	if [ ! -e "$BACKUPDIR/latest" ]	# Check Latest Directory exists.
	then
		mkdir -p "$BACKUPDIR/latest"
	fi
eval rm -fv "$BACKUPDIR/latest/*"
fi

# IO redirection for logging.
touch $LOGFILE
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > $LOGFILE     # stdout replaced with file $LOGFILE.
touch $LOGERR
exec 7>&2           # Link file descriptor #7 with stderr.
                    # Saves stderr.
exec 2> $LOGERR     # stderr replaced with file $LOGERR.


# Functions

# Database dump function
dbdump () {
     DBTEMP=$1
     OUTTEMP=$2
     TBLEX=""
     if [ -n "$TABLEEXCLUDE" ]; then
        for table in $TABLEEXCLUDE ; do
	    arrIN=(${table//./ })
    	    if [ x${arrIN[0]} == x$DBTEMP ]; then
                TBLEX="${TBLEX} -T ${arrIN[1]}"
    	    fi
        done
     fi
                                
    pg_dump --username=$POSTGRESQL_USERNAME --port=$PORT $OPT $TBLEX $DBTEMP > $OUTTEMP
    return 0
}

dbdump_h () {
    rsync -aH --delete --numeric-ids /var/lib/pgsql/ /var/lib/pgsql.backup
    psql -U $POSTGRESQL_USERNAME --port $PORT -c "SELECT pg_start_backup('base_backup');"
    rsync -aH --delete --numeric-ids /var/lib/pgsql/ /var/lib/pgsql.backup
    psql -U $POSTGRESQL_USERNAME --port $PORT -c "SELECT pg_stop_backup();"
    return 0
}
                    
# Compression function plus latest copy
SUFFIX=""
compression () {
if [ "$COMP" = "gzip" ]; then
	gzip -f "$1"
	echo
	echo Backup Information for "$1"
	gzip -l "$1.gz"
	SUFFIX=".gz"
elif [ "$COMP" = "bzip2" ]; then
	echo Compression information for "$1.bz2"
	bzip2 -f -v $1 2>&1
	SUFFIX=".bz2"
else
	echo "No compression option set, check advanced settings"
fi
if [ "$LATEST" = "yes" ]; then
	cp $1$SUFFIX "$BACKUPDIR/latest/"
fi	
return 0
}

compression_h () {
if [ "$COMP" = "gzip" ]; then
        TPWD=`pwd`
        cd /var/lib/pgsql.backup
        tar -czvf "$1.tgz" . 2>&1
        cd $TPWD
        SUFFIX=".tgz"
elif [ "$COMP" = "bzip2" ]; then
        TPWD=`pwd`
        cd /var/lib/pgsql.backup
        tar -cjvf "$1.tbz2" . 2>&1
        cd $TPWD
        SUFFIX=".tbz2"
else
        echo "No compression option set, check advanced settings"
fi
if [ "$LATEST" = "yes" ]; then
    cp $1$SUFFIX "$BACKUPDIR/latest/"
fi
return 0
}                                                                                                

## rotates monthly backups, set 'keep' to the last n backups to keep
rotateMonthly () {

mdbdir="$1"

## set to the number of monthly backups to keep
keep=3

(cd ${mdbdir}

    totalFilesCount=`/bin/ls -1 | wc -l`

    if [ ${totalFilesCount} -gt ${keep} ]; then
	purgeFilesCount=`expr ${totalFilesCount} - ${keep}`
	purgeFilesList=`/bin/ls -1tr | head -${purgeFilesCount}`

	echo ""
	echo "Rotating monthly: Purging in ${mdbdir}"
	rm -fv ${purgeFilesList} | sed -e 's/^//g'
    fi
)
}

# If backing up all DBs on the server
if [ "$DBNAMES" = "all" ]; then
	DBNAMES="`psql --username=$POSTGRESQL_USERNAME --tuples-only --list --port=$PORT | awk {'print $1'} | grep -v ":" | grep -v "|"`"

	# If DBs are excluded
	for exclude in $DBEXCLUDE
	do
		DBNAMES=`echo $DBNAMES | sed "s/\b$exclude\b//g"`
	done

        MDBNAMES=$DBNAMES
fi
	
echo ======================================================================
echo AutoPostgreSQLBackup VER $VER
echo 
echo Backup of Database Server - $HOST
echo ======================================================================

if [ "$DO_SQL_DUMP" = "yes" ]; then
echo Backup Start Time `date`
echo ======================================================================
	# Monthly Full Backup of all Databases
	if [ $DOM = "01" ]; then
		for MDB in $MDBNAMES
		do
 
			 # Prepare $DB for using
		        MDB="`echo $MDB | sed 's/%/ /g'`"

			if [ ! -e "$BACKUPDIR/monthly/$MDB" ]		# Check Monthly DB Directory exists.
			then
				mkdir -p "$BACKUPDIR/monthly/$MDB"
			fi
			echo Monthly Backup of $MDB...
				dbdump "$MDB" "$BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql"
				compression "$BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql"
				BACKUPFILES="$BACKUPFILES $BACKUPDIR/monthly/$MDB/${MDB}_$DATE.$M.$MDB.sql$SUFFIX"
			echo ----------------------------------------------------------------------
		done
	fi


	for DB in $DBNAMES
	do
	# Prepare $DB for using
	DB="`echo $DB | sed 's/%/ /g'`"
	
	# Create Seperate directory for each DB
	if [ ! -e "$BACKUPDIR/daily/$DB" ]		# Check Daily DB Directory exists.
		then
		mkdir -p "$BACKUPDIR/daily/$DB"
	fi
	if [ $BACKUP_DAYS -le 7 ]; then
    	    if [ ! -e "$BACKUPDIR/weekly/$DB" ]		# Check Weekly DB Directory exists.
		then
		mkdir -p "$BACKUPDIR/weekly/$DB"
	    fi	
	fi
	
	# Weekly Backup
	if [ $DNOW = $DOWEEKLY -a $BACKUP_DAYS -le 7 ]; then
		echo Weekly Backup of Database \( $DB \)
		echo Rotating 5 weeks Backups...
			if [ "$W" -le 05 ];then
				REMW=`expr 48 + $W`
			elif [ "$W" -lt 15 ];then
				REMW=0`expr $W - 5`
			else
				REMW=`expr $W - 5`
			fi
		eval rm -fv "$BACKUPDIR/weekly/$DB/${DB}_week.$REMW.*" 
		echo
			dbdump "$DB" "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql"
			compression "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/$DB/${DB}_week.$W.$DATE.sql$SUFFIX"
		echo ----------------------------------------------------------------------
	
	# Daily Backup
	else
		echo Daily Backup of Database \( $DB \)
		echo Rotating last weeks Backup...
		find "$BACKUPDIR/daily/$DB" -name "*.sql.*" -mtime +$BACKUP_DAYS -delete
		echo
		echo
			dbdump "$DB" "$BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql"
			compression "$BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql"
			BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DB/${DB}_$DATE.$DOW.sql$SUFFIX"
		echo ----------------------------------------------------------------------
	fi
	done
echo Backup End `date`
fi

###########################3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3
###########################3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3
###########################3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3##############3
if [ "$DO_HOT_BACKUP" = "yes" ]; then

echo Backup Start Time `date`
echo ======================================================================
# Monthly Full Backup of all Databases
    if [ $DOM = "01" ]; then
        if [ ! -e "$BACKUPDIR/monthly" ]                # Check Monthly DB Directory exists.
        then
            mkdir -p "$BACKUPDIR/monthly"
	fi
        echo Monthly Backup of $MDB...
                dbdump_h "ALL" "$BACKUPDIR/monthly/HOT_$DATE.$M"
###                compression_h "$BACKUPDIR/monthly/HOT_$DATE.$M"
                BACKUPFILES="$BACKUPFILES $BACKUPDIR/monthly/HOT_$DATE.$M$SUFFIX"
        echo ----------------------------------------------------------------------
    fi

    # Create Seperate directory for each DB
    if [ ! -e "$BACKUPDIR/daily" ]          # Check Daily DB Directory exists.
        then
        mkdir -p "$BACKUPDIR/daily"
    fi
    if [ $BACKUP_DAYS -le 7 ]; then
        if [ ! -e "$BACKUPDIR/weekly" ]             # Check Weekly DB Directory exists.
            then
                mkdir -p "$BACKUPDIR/weekly"
        fi
    fi
    # Weekly Backup
    if [ $DNOW = $DOWEEKLY -a $BACKUP_DAYS -le 7 ]; then
        echo Weekly Backup of Database
        echo Rotating 5 weeks Backups...
            if [ "$W" -le 05 ];then
                    REMW=`expr 48 + $W`
            elif [ "$W" -lt 15 ];then
	            REMW=0`expr $W - 5`
            else
                    REMW=`expr $W - 5`
            fi
        eval rm -fv "$BACKUPDIR/weekly/HOT_week.$REMW.*"
        echo
            dbdump_h "$DB" "$BACKUPDIR/weekly/HOT_week.$W.$DATE"
###            compression_h "$BACKUPDIR/weekly/HOT_week.$W.$DATE"
            BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/HOT_week.$W.$DATE$SUFFIX"
            echo ----------------------------------------------------------------------

    # Daily Backup  
        else
            echo Daily Backup of Database
            echo Rotating last weeks Backup...
            find "$BACKUPDIR/daily" -name "*HOT_*" -mtime +$BACKUP_DAYS -delete
            echo
            echo
	        dbdump_h "$DB" "$BACKUPDIR/daily/HOT_$DATE.$DOW"
###                compression_h "$BACKUPDIR/daily/HOT_$DATE.$DOW"
                BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/HOT_$DATE.$DOW$SUFFIX"
	    echo ----------------------------------------------------------------------
    fi    
fi
echo Backup End `date`    
echo ======================================================================
echo Total disk space used for backup storage..
echo Size - Location
echo `du -hs "$BACKUPDIR"`
echo
echo ======================================================================

#Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 1>&7 7>&-      # Restore stdout and close file descriptor #7.

if [ "$MAILCONTENT" = "files" ]
then
	if [ -s "$LOGERR" ]
	then
		# Include error log if is larger than zero.
		BACKUPFILES="$BACKUPFILES $LOGERR"
		ERRORNOTE="WARNING: Error Reported - "
	fi
	#Get backup size
	ATTSIZE=`du -c $BACKUPFILES | grep "[[:digit:][:space:]]total$" |sed s/\s*total//`
	if [ $MAXATTSIZE -ge $ATTSIZE ]
	then
		BACKUPFILES=`echo "$BACKUPFILES" | sed -e "s# # -a #g"`	#enable multiple attachments
		mutt -s "$ERRORNOTE PostgreSQL Backup Log and SQL Files for $HOST - $DATE" $BACKUPFILES $MAILADDR < $LOGFILE		#send via mutt
	else
		cat "$LOGFILE" | mail -s "WARNING! - PostgreSQL Backup exceeds set maximum attachment size on $HOST - $DATE" $MAILADDR
	fi
elif [ "$MAILCONTENT" = "log" ]
then
	cat "$LOGFILE" | mail -s "PostgreSQL Backup Log for $HOST - $DATE" $MAILADDR
	if [ -s "$LOGERR" ]
		then
			cat "$LOGERR" | mail -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $DATE" $MAILADDR
	fi	
elif [ "$MAILCONTENT" = "quiet" ]
then
	if [ -s "$LOGERR" ]
		then
			cat "$LOGERR" | mail -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $DATE" $MAILADDR
			cat "$LOGFILE" | mail -s "PostgreSQL Backup Log for $HOST - $DATE" $MAILADDR
	fi
else
	if [ -s "$LOGERR" ]
		then
			cat "$LOGFILE"
			echo
			echo "###### WARNING ######"
			echo "Errors reported during AutoPostgreSQLBackup execution.. Backup failed"
			echo "Error log below.."
			cat "$LOGERR"
	else
		cat "$LOGFILE"
	fi	
fi

if [ -s "$LOGERR" ]
	then
		STATUS=1
	else
		STATUS=0
fi

# Clean up Logfile
eval rm -f "$LOGFILE"
eval rm -f "$LOGERR"

exit $STATUS
