#! /bin/sh
#
# Based on bits of Jordi's deploy.sh script
#
# This script restarts tomcat if a entry restart is found in /tmp/tcrsentry.log. Ideally needs to be added to cron
# so that it runs every 10 minutes.
#
# USAGE: tomcatrestart.sh
#       Runs and checks the entry in /tmp/tcrsentry.log. If a entry restart is found tomcat would be restarted.
#
# DEPENDENCIES:
#      Needs a entry in /tmp/tcrsentry.log
#
# DONE
#
# TODO


HOSTNAME=`uname -n`; export HOSTNAME
# Use format below on Solaris: USER="`/usr/xpg4/bin/id -un`"
# Use this format on Linux hosts: USER="`/usr/bin/id -un`"
USER="`/usr/bin/id -un`"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/usr/local/tomcat/current"
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
RELEASE_PATH="/usr/local/tomcat/releases"
RELEASE_DIR="${RELEASE_PATH}/webapps_${TIMESTAMP}"
LOGMY="/tmp/tmptc.log"
TCLOGLOC="${TOMCAT_HOME}/logs/catalina.out"
ENVI=$HOSTNAME
VAR1="$@"
ADMINS="gpujari@progress.com"
# sponduri@progress.com skarre@progress.com"
TOUCHME="/tmp/tcrsentry.log"
FILELINES="`cat $TOUCHME`"

#------------------------------------#
# Validate user running this script  #
#------------------------------------#
if [ "${USER}" = "tomcat" ]; then
   echo "Running script as: ${USER} [OK]"
else
   echo "***ERROR: This script should be run as Tomcat"
   exit 1
fi

#---------------------------------------------------------------#
# Check if the file for confirmation exists and contains data  #
#--------------------------------------------------------------#
if [ -s "$TOUCHME" ]
then
        echo "$TOUCHME has some data."
        # do something as file has data
else
        echo "$TOUCHME is empty."
        exit 0
        # do something as file is empty
fi

#---------------------------------------#
# Check entry file and Stop Tomcat      #
#---------------------------------------#

for entry in $filelines
do
echo "The filelist contains $entry" >> $LOGMY

  if [ $entry == "restart" ]
     echo "INFO: Shutting down tomcat..." >> $LOGMY
     /usr/local/tomcat/current/bin/catalina.sh stop
     sleep 10
     else
     echo "$TOUCHME is empty.No restart would be done" >> $LOGMY
     exit 0
     # do something as file is empty
 fi

 done

#-----------------------------#
# Make sure tomcat is stopped #
#-----------------------------#

if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
   echo "***WARNING: Tomcat catalina.pid found" >> $LOGMY
   sleep 20

   if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
      echo "***WARNING: Tomcat catalina.pid still exists" >> $LOGMY
      echo "INFO: Stopping tomcat with -force option" >> $LOGMY
      /usr/local/tomcat/current/bin/catalina.sh stop -force

      sleep 10
   fi
fi

if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
   echo "***ERROR: Tomcat failed to stop. Please stop the process manually" >> $LOGMY
   exit 1
fi

#----------------------------#
# Run the archive log script #
#----------------------------#
/usr/local/tomcat/archivelog.sh
echo "INFO: Ran the archive log script"



#------------------#
# Start Tomcat     #
#------------------#

echo "INFO: Starting Tomcat..."
/usr/local/tomcat/current/bin/catalina.sh start &

sleep 20

#-----------------------------#
# Make sure tomcat is running #
#-----------------------------#

SERVER_STARTUP="0"

if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
   echo "Found catalina.pid"
## echo "Server startup is: $SERVER_STARTUP"

   if [ "pgrep -U tomcat -x java >/dev/null" ]; then
      echo "Found java process owned by tomcat user (pid `pgrep -U tomcat -x java`)" >> $LOGMY
      echo "INFO: Please wait while tomcat restarts (this takes several minutes)" >> $LOGMY
      sleep 65

      # grep -c returns the count or number of times the search string is found
      until [ "$SERVER_STARTUP" = "1" ]
         do
            SERVER_STARTUP=`grep -c "Server startup" /logs/tomcat/catalina.out`
##            echo "Server startup result before done: $SERVER_STARTUP"
            echo "Tomcat is starting Hold on..." >> $LOGMY
            sleep 20
         done
##            echo "Server startup result after done: $SERVER_STARTUP"
            echo "INFO: SUCCESS...Tomcat has started" >> $LOGMY

   else
      echo "***ERROR: Tomcat isn't running or might be hung. Please check the Tomcat logs and process." >> $LOGMY
   fi

else
   echo "***ERROR: TOMCAT NOT RUNNING" >> $LOGMY
fi

#---------------------------------------#
# Mail to be sent to user after Restart #
#---------------------------------------#

tail -100 $TCLOGLOC >> $LOGMY
mailx -s "Log - Restarted tomcat on host $ENVI" $ADMINS < $LOGMY
rm -f $LOGMY

#------------------------------------#
# Recreate the file of data entry    #
#------------------------------------#

rm $TOUCHME
touch $TOUCHME
chmod 777 $TOUCHME


exit 0
