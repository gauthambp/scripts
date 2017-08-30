#! /bin/sh
#
# Based on bits of Jordi's deploy.sh script
#
# This script copies war files from a build area to a temporary location on the Tomcat servers.
#
# USAGE: deploy-webapps.sh webapp [webapp2] [webapp3] ...
#       where webapp = am css ddtoem esd paymentGateway profile utilsvc
#
# DEPENDENCIES:
#
# This script depends on the ant build scripts to produce war files of "app-environment.war"
# Also, this script needs the Git repo name to match the war file name excluding the environment suffix. (Made one exception for CustService.)
#
# DONE  Add -p to preserve timestamp and use some other directory instead of /tmp
# DONE  Added visual cues. The script now displays the source path and destination first
# DONE  The script now requires confirmation in order to proceed with the file copies.
#
# TODO  Add a check to ensure that environment references in the build path
#       match part of the hostname in the destination or target server.
#       Example:  /builds/TEST-webapps/com/deploy/... matches part of the hostname, uxjappTEST(1-2)
#

WEBAPPS="MPPlusSecSvc MPPlusOpnSvc"
BUILD_SERVER="lxappdev"
HOSTNAME=`uname -n`; export HOSTNAME
# Use format below on Solaris: USER="`/usr/xpg4/bin/id -un`"
# Use this format on Linux hosts: USER="`/usr/bin/id -un`"
USER="`/usr/bin/id -un`"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/usr/local/tomcat/current"
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
RELEASE_PATH="/usr/local/tomcat/releases"
RELEASE_DIR="${RELEASE_PATH}/webapps_${TIMESTAMP}"


echo ""
#------------------#
# Validate webapps #
#------------------#
if [ "${WEBAPPS}" = "" ]; then
   echo "***ERROR: Please specify which webapps to deploy"
   exit 1
fi

for APP in ${WEBAPPS}; do
   case "${APP}" in
        am | ddtoem | esd | paymentGateway | profile | utilsvc )
        echo "INFO: ${APP} will be deployed"
        ;;

        css )
        CSS="CustService"
        echo "INFO: ${APP} will be deployed"
        ;;

        * )
        echo "***ERROR: Invalid webapp ${APP} entered. Re-enter webapp (am, css, ddtoem, esd, paymentGateway, profile or utilsvc)"
        exit 1
        ;;
   esac
done

#------------------------------------#
# Validate user running this script  #
#------------------------------------#
if [ "${USER}" = "tomcat" ]; then
   echo "Running script as: ${USER} [OK]"
else
   echo "***ERROR: This script should be run as Tomcat"
   exit 1
fi

#---------------------------------------#
# Get a username for renaming war files #
#---------------------------------------#
echo -n "Enter your username: "
read USERNAME
case "${USERNAME}" in
        gpujari | jwhistle | kreid | jah )
        echo "You entered: ${USERNAME} [OK]"
        ;;

        * )
        echo "***ERROR: This script should be run by Production Control"
        echo "***ERROR: Valid users are: jwhistle, kreid, gpujari or jah"
        exit 1
        ;;
esac


#--------------------------------#
# Validate the deployment server #
#--------------------------------#
case "$HOSTNAME" in
        lxbeddwebapp01 )
        echo "INFO: $HOSTNAME is a valid deployment server";
        ENVIRONMENT="dev"
        echo "INFO: Deployment ENVIRONMENT is: ${ENVIRONMENT}";
        ;;

        lxbedtwebapp0[1-2] )
        echo "INFO: $HOSTNAME is a valid deployment server";
        ENVIRONMENT="test"
        echo "INFO: Deployment ENVIRONMENT is: ${ENVIRONMENT}";
        ;;

        lxbedpwebapp0[1-4] )
        echo "INFO: $HOSTNAME is a valid deployment server";
        ENVIRONMENT="prod"
        echo "INFO: Deployment ENVIRONMENT is: ${ENVIRONMENT}";
        ;;

        lxmorpwebapp01 )
        echo "INFO: $HOSTNAME is a valid deployment server";
        ENVIRONMENT="dr"
        echo "INFO: Deployment ENVIRONMENT is: ${ENVIRONMENT}";
        ;;

        * )
        echo "***ERROR: $HOSTNAME is not one of the Java Webapp deployment servers"
        echo "***ERROR: Please deploy from lxbeddwebapp01, lxbedtwebapp01-02, lxbedpwebapp01-04 or lxmorpwebapp01"
        exit 1
        ;;
esac


#------------------------#
# Verify war files exist #
#------------------------#


for APP in ${WEBAPPS}; do
    ## Note: css has a different module name "CustService" than the webapp "css"
    if [ "${APP}" = "css" ]; then
        if ssh -q "${USERNAME}@${BUILD_SERVER}" [ -f ${BUILD_PATH}/${CSS}/deploy/webapp/${APP}-${ENVIRONMENT}.war ] ; then
           echo "Verified ${BUILD_SERVER}:${BUILD_PATH}/${CSS}/deploy/webapp/${APP}-${ENVIRONMENT}.war exists"
        else
           echo "ERROR: ${APP}-${ENVIRONMENT}.war does not exist on ${BUILD_SERVER}:${BUILD_PATH} - EXITING"
           exit 1
        fi
    else
        if ssh -q "${USERNAME}@${BUILD_SERVER}" [ -f ${BUILD_PATH}/${APP}/deploy/webapp/${APP}-${ENVIRONMENT}.war ] ; then
           echo "Verified ${BUILD_SERVER}:${BUILD_PATH}/${APP}/deploy/webapp/${APP}-${ENVIRONMENT}.war exists"
        else
            echo "ERROR: ${APP}-${ENVIRONMENT}.war does not exist on ${BUILD_SERVER}:${BUILD_PATH} - EXITING"
            exit 1
        fi
    fi
done


#------------------#
# Stop Tomcat      #
#------------------#

echo "INFO: Shutting down tomcat..."
/usr/local/tomcat/current/bin/catalina.sh stop

sleep 10

#-----------------------------#
# Make sure tomcat is stopped #
#-----------------------------#

if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
   echo "***WARNING: Tomcat catalina.pid found"
   sleep 20

   if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
      echo "***WARNING: Tomcat catalina.pid still exists"
      echo "INFO: Stopping tomcat with -force option"
      /usr/local/tomcat/current/bin/catalina.sh stop -force

      sleep 10
   fi
fi

if [ -f "${TOMCAT_HOME}/logs/catalina.pid" ]; then
   echo "***ERROR: Tomcat failed to stop. Please stop the process manually"
   exit 1
fi

#---------------------------#
# Rename existing war files #
#---------------------------#

for APP in ${WEBAPPS}; do
   case "${APP}" in
        am | css | ddtoem | esd | paymentGateway | profile | utilsvc )
        #----------------------------#
        # Verify the war file exists #
        #----------------------------#
        echo "INFO: Looking for ${APP}.war in ${TOMCAT_HOME}/webapps..."
        if [ -f "${TOMCAT_HOME}/webapps/${APP}.war" ]; then
           echo "INFO: Found ${TOMCAT_HOME}/webapps/${APP}.war"
           echo "INFO: Renaming the existing ${APP}.war file to ${APP}.war.`date "+%Y%m%d_%H%M"`-${USERNAME}"
           mv ${TOMCAT_HOME}/webapps/${APP}.war ${TOMCAT_HOME}/webapps/${APP}.war.`date "+%Y%m%d_%H%M"`-${USERNAME}
        else
           echo "***WARNING: ${TOMCAT_HOME}/webapps/${APP}.war was not found";
           ##exit 1
        fi
        ;;

        * )
        echo "***ERROR: Invalid webapps. Specify am, css, ddtoem, esd, paymentGateway, profile or utilsvc."
        exit 1
        ;;
   esac
done

#------------------------------------------------------#
# Move all renamed war files to the obsolete directory #
#------------------------------------------------------#
if [ -d "${TOMCAT_HOME}/obsolete" ]; then
   echo "INFO: Moving existing war files to the obsolete directory"
   mv ${TOMCAT_HOME}/webapps/*-${USERNAME} ${TOMCAT_HOME}/obsolete/
else
   echo "***WARNING: ${TOMCAT_HOME}/obsolete was not found";
   echo "***WARNING: Unable to move renamed war files to the backup directory";
   exit 1
fi


#----------------------------------#
# Remove all webapp subdirectories #
#----------------------------------#
echo "INFO: Removing existing webapp and work directories..."
for APP in ${WEBAPPS}; do
   rm -rf ${TOMCAT_HOME}/webapps/${APP}
   echo "INFO: Removed ${TOMCAT_HOME}/webapps/${APP}"
   rm -rf ${TOMCAT_HOME}/work/Catalina/localhost/${APP}
   echo "INFO: Removed ${TOMCAT_HOME}/work/Catalina/localhost/${APP}"
done


#----------------------------#
# Run the archive log script #
#----------------------------#
/usr/local/tomcat/archivelog.sh
echo "INFO: Ran the archive log script"



#--------------------------------------------#
# Make directories for files to be released  #
#--------------------------------------------#

echo "INFO: Checking for releases directory on server..."
if [ ! -d "${RELEASE_PATH}" ]; then
    echo "***ERROR: ${RELEASE_PATH} does not exist - EXITING";
    exit 1
else
    mkdir ${RELEASE_DIR}
    echo "INFO: Created ${RELEASE_DIR}"
fi


#-------------------#
# Review deployment #
#-------------------#

echo "***"
echo "***IMPORTANT: REVIEW THE LIST OF FILES FOR DEPLOYMENT BELOW***"
echo "***"

for APP in ${WEBAPPS}; do
    ## Note: css has a different module name "CustService" than the webapp.
    if [ "${APP}" = "css" ]; then
        echo "Deploy ${USERNAME}@${BUILD_SERVER}:${BUILD_PATH}/${CSS}/deploy/webapp/${APP}-${ENVIRONMENT}.war"
    else
        echo "Deploy ${USERNAME}@${BUILD_SERVER}:${BUILD_PATH}/${APP}/deploy/webapp/${APP}-${ENVIRONMENT}.war"
    fi
done


#------------------------#
# Confirm and Copy files #
#------------------------#
echo -n "Enter YES (case-sensitive) to proceed: "
read RESPONSE
echo "You entered: ${RESPONSE}"

if [ "${RESPONSE}" = "YES" ]; then

   for APP in ${WEBAPPS}; do

       if [ "${APP}" = "css" ]; then
          scp -p ${USERNAME}@${BUILD_SERVER}:${BUILD_PATH}/${CSS}/deploy/webapp/${APP}-${ENVIRONMENT}.war ${RELEASE_DIR}/
       else
          scp -p ${USERNAME}@${BUILD_SERVER}:${BUILD_PATH}/${APP}/deploy/webapp/${APP}-${ENVIRONMENT}.war ${RELEASE_DIR}/
       fi
   done

   ## Copy war files to tomcat webapps directory
   cp -p ${RELEASE_DIR}/*.war ${TOMCAT_HOME}/webapps/
   echo "INFO: Copied ${RELEASE_DIR} files to tomcat webapps directory";

   ## Rename the webapps, removing the environment suffix from the filename.
   cd ${TOMCAT_HOME}/webapps/
   for APP in ${WEBAPPS}; do
       mv ${APP}-${ENVIRONMENT}.war ${APP}.war
       echo "Renamed ${APP}-${ENVIRONMENT}.war to ${APP}.war"
   done


else
   echo "***ERROR: Deployment not confirmed - EXITING"
   exit 0;
fi


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
      echo "Found java process owned by tomcat user (pid `pgrep -U tomcat -x java`)"
      echo "INFO: Please wait while the webapps are deployed (this takes several minutes)"
      sleep 65

      # grep -c returns the count or number of times the search string is found
      until [ "$SERVER_STARTUP" = "1" ]
         do
            SERVER_STARTUP=`grep -c "Server startup" /logs/tomcat/catalina.out`
##            echo "Server startup result before done: $SERVER_STARTUP"
            echo "Webapps are still being deployed..."
            sleep 20
         done
##            echo "Server startup result after done: $SERVER_STARTUP"
            echo "INFO: SUCCESS...Tomcat started and deployment is complete!"
            echo "${WEBAPPS} deployed to ${HOSTNAME}"

   else
      echo "***ERROR: Tomcat isn't running or might be hung. Please check the Tomcat logs and process."
   fi

else
   echo "***ERROR: TOMCAT NOT RUNNING"
fi

exit 0
