#!/bin/bash

USAGE="Usage: `basename $0` [-a|-- application_name (rlb-live-prod,d2c-live-prod,csc-stage-prod]"

while [ "$1" != "" ]; do
    case "$1" in
      "-a" | "--application_name")
	 shift
	 FULL_APP_NAME=$1
      ;;
      *)
         echo $USAGE
         exit 1
    esac
    shift
done

if [ $FULL_APP_NAME = "rlb-live-prod" ]; then
    source /usr/local/devops/rlb-live-prod-config.sh
    echo "source file:rlb-live-prod-config.sh"
fi

if [ $FULL_APP_NAME = "rlb-stage-prod" ]; then
    source /usr/local/devops/rlb-stage-prod-config.sh
    echo "source file:rlb-stage-prod-config.sh"
fi

if [ $FULL_APP_NAME = "d2c-live-prod" ]; then
    source /usr/local/devops/d2c-live-prod-config.sh
    echo "source file:d2c-live-prod-config.sh"
fi

if [ $FULL_APP_NAME = "d2c-stage-prod" ]; then
    source /usr/local/devops/d2c-stage-prod-config.sh
    echo "source file:d2c-stage-prod-config.sh"
fi

if [ $FULL_APP_NAME = "csc-live-prod" ]; then
    source /usr/local/devops/csc-live-prod-config.sh
    echo "source file:csc-live-prod-config.sh"
fi

if [ $FULL_APP_NAME = "csc-stage-prod" ]; then
    source /usr/local/devops/csc-stage-prod-config.sh
    echo "source file:csc-stage-prod-config.sh"
fi

if [ $FULL_APP_NAME = "d2p-live-prod" ]; then
    source /usr/local/devops/d2p-live-prod-config.sh
    echo "source file:d2p-live-prod-config.sh"
fi

if [ $FULL_APP_NAME = "d2p-stage-prod" ]; then
    source /usr/local/devops/d2p-stage-prod-config.sh
    echo "source file:d2p-stage-prod-config.sh"
fi

SSL_CERT=/usr/local/devops/rds-combined-ca-bundle.pem
export AWS_ACCESS_KEY_ID=$AWS_KEY
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET
export REGION=$AWS_REGION
AWS_OUTPUT=text
TIME=`date "+%Y-%m-%d-%H%M"`
YEAR=`date "+%Y"`
LOG_FILE=/var/log/$PRODUCT-$APPLICATION_NAME-$PHASE
touch $LOG_FILE
#S3 keys
S3_KEY=$TEMP_S3_KEY
S3_SECRET=$TEMP_S3_SECRET
ATTEMPTS=120

echo "################################################################################"  >> $LOG_FILE
echo "RDS Backup job started [`date`]"    >> $LOG_FILE
echo "################################################################################"  >> $LOG_FILE

# Check that all the vars in the config file are present
if [[ "$APPLICATION_NAME" != "" && "$PHASE" != "" && "$PRODUCT" != "" && "$S3BUCKET" != "" && "$DB_ADMIN" != "" && "$DB_PASSWORD" != "" && "$ALERT_EMAIL" != "" ]]; then
    echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST0 $TIME all variables are set in rds_config.sh" >> $LOG_FILE
else
    echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST0 $TIME not all variables are set in rds_config.sh" >> $LOG_FILE
    exit 1
fi

# Get the RDS instance infomation needed to preform the backups
BASENAME=($(aws rds describe-db-instances --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier]'  | grep $APPLICATION_NAME-$PHASE | grep -v "999"))

# This sets the date for which all rds manual snapshots are delete if they are older than this date
DATE_REMOVE=$(date -d "-4 day" +%F | awk -F"-" '{print $1 $2 $3}')

# This creates the list of all the RDS snapshots that exist for the applicaition and phase
SNAP_ARRAY=$(aws rds describe-db-snapshots --output table --query 'DBSnapshots[*].[DBSnapshotIdentifier, SnapshotCreateTime]' | awk -F"|" '{print $2}' | grep bk-rds-$APPLICATION_NAME-$PHASE)
##### VARS #######

# functions
getInstDetails () {
    key=$1
    pos=$2
    var=""
 for i in "${WORK_INST[@]}"
     do
     if [[ $i == *$key* ]]; then
	var=$(echo $i | cut -d, -f $pos)
     fi
     done
}

# Create all the details needed to preform all the steps needed
for i in "${BASENAME[@]}"
do
    DB_NAME=$i
     DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $i --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, Endpoint.Address]' | awk -F" " '{print $2}')
    DB_SNAP=bk-$(echo $i | cut -d'-' -f 2-)-$TIME
    DB_TEMP=$PRODUCT\999-$(echo $i | cut -d'-' -f 2-)-$TIME
    DB_SG=$(aws rds describe-db-instances  --db-instance-identifier $i --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, VpcSecurityGroups[0].VpcSecurityGroupId]' |  awk -F" " '{print $2}' )
    DB_NG=$(aws rds describe-db-instances  --db-instance-identifier $i --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, DBSubnetGroup.DBSubnetGroupName]' |  awk -F" " '{print $2}')
    DB_PG=$(aws rds describe-db-instances  --db-instance-identifier $i --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, DBParameterGroups[0].DBParameterGroupName]' | awk -F" " '{print $2}')
    DB_AZ=$(aws rds describe-db-instances  --db-instance-identifier $i --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, AvailabilityZone]' | awk -F" " '{print $2}')
    WORK_INST+=($DB_NAME,$DB_ENDPOINT,$DB_TEMP,$DB_SNAP,$DB_SG,$DB_NG,$DB_PG,$DB_AZ)
done

PRE_CHECK_RDS=($(aws rds describe-db-instances --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier]'  | grep $APPLICATION_NAME-$PHASE | grep "999"))
if [[ -z "$PRE_CHECK_RDS" ]] ; then
    echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST1 $TIME There are no existing temporary RDS instances running" >> $LOG_FILE

else
    echo "$PRODUCT-RDS-BACKUP: [`date`]: ALERT: ST1 $TIME There are existing temporary RDS instances running, $PRE_CHECK_RDS" >> $LOG_FILE
    echo "$PRODUCT-RDS-BACKUP: [`date`]: ALERT: ST1 $TIME there are existing temporary RDS instance running, $PRE_CHECK_RDS" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ALERT" $ALERT_EMAIL
    for q in "${PRE_CHECK_RDS[@]}"
       do
         aws rds delete-db-instance --db-instance-identifier $q --skip-final-snapshot
       done
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST1 $TIME Delete old temp RDS instances left over from a previous backup  "  >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST1 $TIME Unable to delete temporary RDS instances"  >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST1 $TIME Unable to delete temporary RDS instances" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
    fi
fi

# Now wait for the temp DB instances to become available
for t in "${BASENAME[@]}"
do
    getInstDetails $t 1
    TIMES=1
    STATUS=$(aws rds describe-db-instances --db-instance-identifier $var --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceStatus]')
    while [ $ATTEMPTS -gt $TIMES ] && [ "$STATUS" != "available" ]
       do
           sleep 60
           TIMES=$(( $TIMES + 1 ))
           STATUS=$(aws rds describe-db-instances --db-instance-identifier $var --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceStatus]')
       done
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST1A $TIME $var instance is status $STATUS after $TIMES " >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST1A $TIME $var instance is in status $STATUS after $TIMES times" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST1A $TIME $var instance is in status $STATUS after $TIMES times" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
done

# Create the snaps first all at the same time
for t in "${BASENAME[@]}"
do
    getInstDetails $t 4
    aws rds create-db-snapshot --db-instance-identifier $t --db-snapshot-identifier $var
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST2 $TIME created snapshot of RDS $t"  >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST2 $TIME to create snapshot of RDS $t"  >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST2 $TIME to create snapshot of RDS $t" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
done

# Now check the RDS snapshots
for t in "${BASENAME[@]}"
do
    getInstDetails $t 4
    TIMES=1
    STATUS=$(aws rds describe-db-snapshots --db-snapshot-identifier $var --query 'DBSnapshots[*].[Status]')
    while [ $ATTEMPTS -gt $TIMES ] && [ "$STATUS" != "available" ]
       do
           sleep 10
           TIMES=$(( $TIMES + 1 ))
           STATUS=$(aws rds describe-db-snapshots --db-snapshot-identifier $var --query 'DBSnapshots[*].[Status]')
       done
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST3 $TIME snapshot $var is available after $TIMES times" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST3 $TIME snapshot $var failed to become available after $TIMES times" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST3 $TIME snapshot $var failed to become available after $TIMES times" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
    TIMES=1
done

# Added a timer because it seems there is an issue that ST2 gets "available" status before the snap is really ready. Adding 5 mins delay to start with
sleep 120
# Create the DB temp instances
for t in "${BASENAME[@]}"
    do
         getInstDetails $t 3
         TEMP_DB_INST=$var
         getInstDetails $t 4
         TEMP_DB_SNAP=$var
         getInstDetails $t 6
         TEMP_NW_GROUP=$var
         getInstDetails $t 8
         TEMP_AZ=$var
         # $AWS/rds-restore-db-instance-from-db-snapshot $TEMP_DB_INST --db-snapshot-identifier $TEMP_DB_SNAP db-instance-class db.m1.medium --availability-zone $TEMP_AZ --engine mysql --publicly-accessible true --db-subnet-group-name $TEMP_NW_GROUP -I $AWS_KEY -S $AWS_SECRET

         aws rds restore-db-instance-from-db-snapshot --db-instance-identifier $TEMP_DB_INST --db-snapshot-identifier $TEMP_DB_SNAP --db-instance-class db.m3.xlarge --availability-zone $TEMP_AZ --engine mysql --publicly-accessible --db-subnet-group-name $TEMP_NW_GROUP
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST4 $TIME db instance $TEMP_DB_INST has been created" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST4 $TIME failed db instance $TEMP_DB_INST creattion" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST4 $TIME failed db instance $TEMP_DB_INST creattion" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
done

# Now wait for the temp DB instances to become available
for t in "${BASENAME[@]}"
do
    getInstDetails $t 3
    TIMES=1
    STATUS=$(aws rds describe-db-instances --db-instance-identifier $var --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceStatus]')
    while [ $ATTEMPTS -gt $TIMES ] && [ "$STATUS" != "available" ]
       do
           sleep 60
           TIMES=$(( $TIMES + 1 ))
           STATUS=$(aws rds describe-db-instances --db-instance-identifier $var --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceStatus]')
       done
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST5 $TIME $TEMP_DB_INST instance has become availible after $TIMES times" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST5 $TIME $TEMP_DB_INST instance has failed to become availible after $TIMES times" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST5 $TIME $TEMP_DB_INST instance has failed to become availible after $TIMES times" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi

# Update the security group to match the production ones
    getInstDetails $t 3
    TEMP_DB_INST=$var
    getInstDetails $t 5
    TEMP_SG_GROUP=$var
    aws rds modify-db-instance --db-instance-identifier $TEMP_DB_INST --apply-immediately --master-user-password $DB_PASSWORD --vpc-security-group-ids $TEMP_SG_GROUP

    # Now wait until the changes have been made and the instance are back up
    TIMES=1
    while [ $ATTEMPTS -gt $TIMES ] && [ "$STATUS" != "available" ]
       do
           sleep 60
	   echo "$TIMES"
           TIMES=$(( $TIMES + 1 ))
           STATUS=$(aws rds describe-db-instances --db-instance-identifier $var --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceStatus]')
       done

    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST5 $TIME $TEMP_DB_INST instance has been modified to use $TEMP_SG_GROUP after $TIMES times" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST5 $TIME $TEMP_DB_INST failed to be modified to use sg $TEMP_SG_GROUP after $TIMES times" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST5 $TIME $TEMP_DB_INST failed to be modified to use sg $TEMP_SG_GROUP after $TIMES times" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
    TIMES=1
done
sleep 120

# Starting the mysql dumps
mkdir -p $TEMP_DIR/$TIME
for t in "${BASENAME[@]}"
do
    DB_ENDPOINT=""
    TOTAL_DB=""
    # Get the conenction details on each RDS temp instance so we can connect
    getInstDetails $t 3
    DB_ENDPOINT=$(aws rds describe-db-instances --region $AWS_REGION --output $AWS_OUTPUT --query 'DBInstances[*].[DBInstanceIdentifier, Endpoint.Address]' | grep $var | awk -F" " '{print $2}')
    # Now connect to each instance and get a list of all the databases.
    TOTAL_DB=($(mysql --ssl_ca $SSL_CERT -h $DB_ENDPOINT -u $DB_ADMIN -p$DB_PASSWORD -e "show databases;" | awk -F"|" '{print $1}'| grep -v -E '(Database|schema|tmp|mysql|innodb)'))
        if [[ -z "$TOTAL_DB" ]] ; then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST6 $TIME unable to access $DB_ENDPOINT via mysql, check security group access for backup server IP address" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST6 $TIME unable to access $DB_ENDPOINT via mysql, check security group access for backup server IP address" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
        else
           echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST6 $TIME able to access $DB_ENDPOINT via mysql" >> $LOG_FILE
        fi
    # Now that we have a list of databases dump them into a single file
    for q in "${TOTAL_DB[@]}"
    do
        echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST7 $TIME mysqldump --force --ssl_ca $SSL_CERT -f -h $DB_ENDPOINT $DB_ADMIN -p$DB_PASSWORD $q > $TEMP_DIR/$TIME/$t-$q.sql" >> $LOG_FILE
        mysqldump --force --ssl_ca $SSL_CERT -f -h $DB_ENDPOINT -u $DB_ADMIN -p$DB_PASSWORD $q > $TEMP_DIR/$TIME/$t-$q.sql
        if [ $? -eq 0 ]
            then
                echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST7 $TIME mysql dump of database $t-$q from $DB_ENDPOINT" >> $LOG_FILE
        fi
        if [ $? -eq 1 ]
            then
               echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST7 $TIME mysql dump of database $t-$q from $DB_ENDPOINT" >> $LOG_FILE
                echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST7 $TIME mysql dump of database $t-$q from $DB_ENDPOINT with error code $?" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
		exit 1
        fi
        if [ $? -gt 1 ]
            then
                echo "$PRODUCT-RDS-BACKUP: [`date`]: ERROR: ST7 $TIME mysql dump of database $t-$q from $DB_ENDPOINT" >> $LOG_FILE
                echo "$PRODUCT-RDS-BACKUP: [`date`]: ERROR: ST7 $TIME mysql dump of database $t-$q from $DB_ENDPOINT with error code $?" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
        fi

        gzip $TEMP_DIR/$TIME/$t-$q.sql
        if [ $? -eq 0 ]
            then
                echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST7 $TIME finsihed gzipping $TEMP_DIR/$TIME/$t-$q.sql" >> $LOG_FILE
            else
                echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST7 $TIME gzipping $TEMP_DIR/$TIME/$t-$q.sql" >> $LOG_FILE
                echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST7 $TIME gzipping $TEMP_DIR/$TIME/$t-$q.sql" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
        fi
	done
    # Now get the instances pram settings
    getInstDetails $t 7
    # $AWS/rds-describe-db-parameters $var -I $AWS_KEY -S $AWS_SECRET > $TEMP_DIR/$TIME/$t-db-pram
    aws rds describe-db-parameters --db-parameter-group-name $var > $TEMP_DIR/$TIME/$t-db-pram
        if [ $? -eq 0 ]
            then
                echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST8 $TIME Successfully downloaded the pram details for $t" >> $LOG_FILE
            else
                echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST8 $TIME Failed to downloaded the pram details for $t" >> $LOG_FILE
                echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST8 $TIME Failed to downloaded the pram details for $t" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
        fi

done

# Tar up all the files from the database dumps
TAR_FILE_SIZE=$(du -s $TEMP_DIR/$TIME/ | awk -F" " '{print $1}')
TAR_FILE_MAX=4096000
TAR_FILE_COUNT=$(perl -E "use POSIX qw(ceil); say ceil($TAR_FILE_SIZE/$TAR_FILE_MAX)")
TAR_FILE_NAMES=
TAR_FILE_NAMES=

unset TAR_FILE_NAMES
for (( i=1; i <= $TAR_FILE_COUNT; i++ )); do
     TAR_FILE_NAMES[$i]="--file=$TEMP_DIR/$PRODUCT-$APPLICATION_NAME-$PHASE-$TIME-$i.tar"
done

tar -c -M -L $TAR_FILE_MAX ${TAR_FILE_NAMES[*]} $TEMP_DIR/$TIME
echo "tar exit code:$?"
    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST9 $TIME Successfully tar'ed $TEMP_DIR/$PRODUCT-$APPLICATION_NAME-$PHASE-$TIME.tar" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST9 $TIME Failed to tar'ed $TEMP_DIR/$PRODUCT-$APPLICATION_NAME-$PHASE-$TIME.tar" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST9 $TIME Failed to tar'ed $TEMP_DIR/$PRODUCT-$APPLICATION_NAME-$PHASE-$TIME.tar" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi

# Copy the files to the S3 bucket
    export AWS_ACCESS_KEY_ID=$S3_KEY
    export AWS_SECRET_ACCESS_KEY=$S3_SECRET

for i in "${TAR_FILE_NAMES[@]}"; do
       CP_TMP=$(echo $i | awk -F"=" '{print $2}')
       aws s3 cp $CP_TMP s3://$S3BUCKET/rds/$YEAR/
done

    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST10 $TIME Successfully put $PRODUCT-$TIME.tar into S3 bucket s3://$S3BUCKET/rds/$YEAR/" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST10 $TIME Failed to put $PRODUCT-$TIME.tar into S3 bucket s3://$S3BUCKET/rds/$YEAR/" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST10 $TIME Failed $PRODUCT-$TIME.tar into S3 bucket s3://$S3BUCKET/rds/$YEAR/" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi

# Copy the files to the S3 dr bucket
export AWS_ACCESS_KEY_ID=$DR_S3_KEY
export AWS_SECRET_ACCESS_KEY=$DR_S3_SECRET

for i in "${TAR_FILE_NAMES[@]}"; do
       CP_TMP=$(echo $i | awk -F"=" '{print $2}')
       aws s3 cp $CP_TMP s3://$DR_S3_BUCKET/rds/$YEAR/
done

    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST11 $TIME Successfully put $PRODUCT-$TIME.tar into DR S3 bucket s3://$DR_S3_BUCKET/rds/$YEAR/" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST11 $TIME Failed to put $PRODUCT-$TIME.tar into DR S3 bucket s3://$DR_S3_BUCKET/rds/$YEAR/" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST11 $TIME Failed $PRODUCT-$TIME.tar into DR S3 bucket s3://$DR_S3_BUCKET/rds/$YEAR/" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi
# end DR copy
# do a simple size check on the files to make sure they are less than 20GB which would indicate an error
for i in "${TAR_FILE_NAMES[@]}"; do
       FILE_NAME=$(echo $i | awk -F"=" '{print $2}')
       FILE_SIZE=$(aws s3 ls s3://$DR_S3_BUCKET/rds/$YEAR/$FILE_NAME | awk -F" " '{print $3}')
       if [ "$FILE_SIZE" < "20000000" ]; then
          echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST12 $TIME It looks like the resulting file $FILE_NAME in S3 is smaller than 20MB which would indicate an issue with the backup" >> $LOG_FILE
          echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST12 $TIME It looks like the resulting file $FILE_NAME in S3 is smaller than 20MB which would indicate an issue with the backup" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
       else
	  echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST12 $TIME $FILE_NAME in S3 is larger 20MB which is expected" >> $LOG_FILE
       fi
done

export AWS_ACCESS_KEY_ID=$AWS_KEY
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET

# remove the local files from the system
rm -rf $TEMP_DIR/$TIME
rm -rf $TEMP_DIR/*.tar

    if [ $? -eq 0 ]
       then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST13 $TIME removed local files in $TEMP_DIR" >> $LOG_FILE
       else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST13 $TIME remove local files in $TEMP_DIR" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST13 $TIME remove local files in $TEMP_DIR" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
    fi

# Delete the temp RDS instances
for t in "${BASENAME[@]}"
do
    getInstDetails $t 3
    ENDPOINT=$(echo $var | grep "999")

    for i in "${ENDPOINT[@]}"
        do
            aws rds delete-db-instance --db-instance-identifier $ENDPOINT --skip-final-snapshot

        if [ $? -eq 0 ]
            then
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST14 $TIME Removing the temporary RDS instance $ENDPOINT" >> $LOG_FILE
        else
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST14 $TIME FAILURE in removing the temporary RDS instance $ENDPOINT" >> $LOG_FILE
            echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST14 $TIME in removing the temporary RDS instance $ENDPOINT" |  mail -r devops@progress.com -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
            exit 1
        fi
    done
done

# Remove snapshots older than 5 days
for p in ${SNAP_ARRAY[*]}; do
    DATE_TEST=$(echo $p | awk -F"-" '{print $(NF-3)$(NF-2)$(NF-1)}')
        if test $DATE_TEST -lt $DATE_REMOVE
            then
            aws rds delete-db-snapshot --db-snapshot-identifier $p
            echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST15 $TIME Deleted snapshot: $p" >> $LOG_FILE
        fi
    done

if [ $? -eq 0 ]
   then
       echo "$PRODUCT-RDS-BACKUP: [`date`]: SUCCESS: ST16 $TIME Completed removal of snapshots older than 5 days" >> $LOG_FILE
   else
       echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST16 $TIME Unable to remove snapshots older than 5 days" >> $LOG_FILE
       echo "$PRODUCT-RDS-BACKUP: [`date`]: FAILURE: ST16 $TIME Unable to remove snapshots older than 5 days" |  mail -s "$PRODUCT-RDS-BACKUP: ERROR" $ALERT_EMAIL
       exit 1
fi
echo "################################################################################"  >> $LOG_FILE
echo "RDS Backup job completed [`date`]" >> $LOG_FILE
echo "################################################################################"  >> $LOG_FILE

