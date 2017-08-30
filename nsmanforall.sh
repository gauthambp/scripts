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
#HOSTNAME=`uname -n`; export HOSTNAME
# Use format below on Solaris: USER="`/usr/xpg4/bin/id -un`"
# Use this format on Linux hosts: USER="`/usr/bin/id -un`"
USER="`/usr/bin/id -un`"
TOMCAT_USER="tomcat"
TOMCAT_HOME="/usr/local/tomcat/current"
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
RELEASE_PATH="/usr/local/tomcat/releases"
TC_RELEASE_DIR="${RELEASE_PATH}/webapps_${TIMESTAMP}"
PORT_NUMBER="20944"
VERSION="111"

if ps -eaf | grep "/usr/local/dlc/111/" | grep "root" > /dev/null 2>&1;then
  if ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1" | grep "root" > /dev/null 2>&1 ;then
  res=`ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1"| grep "root"`
  ver=111 . /usr/local/dlc/bin/dlcverset

  nsman -i NS1 -port 20944 -q | grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt

  for word in $(cat echogpAS.txt);do echo $word;word=${word:3};nsman -i $word -port 20944 -q ;done

  rm echogpAS.txt
  fi
fi


if ps -eaf | grep "/usr/local/dlc/116/" | grep "root" > /dev/null 2>&1;then
  if ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1" | grep "root" > /dev/null 2>&1 ;then
  res=`ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1"| grep "root"`
  ver=116 . /usr/local/dlc/bin/dlcverset

  nsman -i NS1 -port 20944 -q | grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt

  for word in $(cat echogpAS.txt);do echo $word;word=${word:3};nsman -i $word -port 20944 -q ;done
  rm echogpAS.txt
  fi
fi
done
