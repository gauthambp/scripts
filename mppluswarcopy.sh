#! /bin/bash

# 2017-02-09 Modified location of obsolete directory out of webapps (jwhistle)
#last updated on 3rd may2016-added
#move backed up file to obsolete folder
#clear contents in localhost folder

#05 Aug 2016-fixed issue with copy of files from /tmp to webapps folder.This is the master copy


myhome="/tmp"
webapphome="/usr/local/tomcat/current/webapps"

export myhome
datetoday=`date +"%m-%d-%Y-%H-%M"`
export datetoday
cd /usr/local/tomcat/current/webapps/;cp MPPlusSecSvc.war /usr/local/tomcat/current/obsolete/MPPlusSecSvc.war.$datetoday;cp MPPlusOpnSvc.war /usr/local/tomcat/current/obsolete/MPPlusOpnSvc.war.$datetoday

/usr/local/tomcat/current/bin/catalina.sh stop -force

cd /usr/local/tomcat/current/webapps/;rm -r "MPPlusSecSvc";rm -r "/usr/local/tomcat/current/work/Catalina/localhost/MPPlusSecSvc/"
cp $myhome/MPPlusSecSvc.war /usr/local/tomcat/current/webapps/;chown tomcat:tomcat MPPlusSecSvc.war


cd /usr/local/tomcat/current/webapps/;rm -r "MPPlusOpnSvc";rm -r "/usr/local/tomcat/current/work/Catalina/localhost/MPPlusOpnSvc/"
cp $myhome/MPPlusOpnSvc.war /usr/local/tomcat/current/webapps/;chown tomcat:tomcat MPPlusOpnSvc.war

sleep 20


/usr/local/tomcat/current/bin/catalina.sh start

echo "Will wait for 2 mins before stopping again"
sleep 120

echo "Stopping tomcat now to change runtime.props"

/usr/local/tomcat/current/bin/catalina.sh stop -force


/home/updateMPPlusruntimeprops.sh


echo "starting tomcat now finally"

/usr/local/tomcat/current/bin/catalina.sh start

tail -f /usr/local/tomcat/current/logs/catalina.out
