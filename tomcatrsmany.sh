#! /bin/sh

#Name of this program
PROG=`basename $0`

#---------------------------#
# Validate package names #
#---------------------------#
#LIST="$*"
#if [ "$LIST" = "" ]; then
#   echo "*** ERROR: Please specify packages Ex:CST79,RPT99"
#   exit 255
#fi

ENVI=$HOSTNAME
var1="$@"
WEBAPPSHOME="/usr/local/tomcat/current/webapps"
TCHOME="/usr/local/tomcat/current"
ADMINS="gpujari@progress.com sponduri@progress.com skarre@progress.com"
LOGMY=/tmp/tmptc.log
TCLOGLOC=/usr/local/tomcat/current/logs/catalina.out
MYHOME="/tmp"
export MYHOME
datetoday=`date +"%m-%d-%Y-%H-%M"`
export datetoday
TOUCHME='/tmp/tcrsentry.log'
FILELINES=`cat $TOUCHME`

copy_warfiles () {

  cd $WEBAPPSHOME;cp $package.war $TCHOME/obsolete/$package.war.$datetoday;cp $package.war /usr/local/tomcat/current/obsolete/$package.war.$datetoday

  cd $WEBAPPSHOME;rm -r "$package";rm -r "$TCHOME/work/Catalina/localhost/$package/"
  cp $MYHOME/$package.war $WEBAPPSHOME;chown tomcat:tomcat $package.war

}

if [ $(id -u) != 59903 ]; then
     echo "Please run as tomcat user"
        exit
     # elevate script privileges
fi

if [ -s "$TOUCHME" ]
then
        echo "$TOUCHME has some data."
        # do something as file has data
else
        echo "$TOUCHME is empty."
        exit 0
        # do something as file is empty
fi

#Stop tomcat globally
/usr/local/tomcat/current/bin/catalina.sh stop -force

#loop to copy packages
for package in $FILELINES
do
echo "The filelist contains $package"

if [ $package == "css|esd|profile|ddtoem" ]
then
#         echo "$TOUCHME has some data."
        #$package = "Css"
        copy_warfiles

        # cd $WEBAPPSHOME;cp $package.war $TCHOME/obsolete/$package.war.$datetoday;cp $package.war /usr/local/tomcat/current/obsolete/$package.war.$datetoday
        #
        # cd $WEBAPPSHOME;rm -r "$package";rm -r "$TCHOME/work/Catalina/localhost/$package/"
        # cp $MYHOME/MPPlusSecSvc.war $WEBAPPSHOME;chown tomcat:tomcat $package.war
# else if [[ $package == "ddtoem" ]]; then
#   #statements
#       #$package = "ddtoem"
#       copy_warfiles
# else if [[ $package == "esd" ]]; then
#   #statements
#       copy_warfiles
else
        echo "$TOUCHME is empty.No restart would be done"
        exit 0
        # do something as file is empty
fi

done

#Stop tomcat globally
/usr/local/tomcat/current/bin/catalina.sh start

sleep 90
tail -200 $TCLOGLOC > $LOGMY
#echo "The files below were changed or created in Last 20 minutes" >> $LOGMY
#cat $LOGMY
mailx -s "Log - Restart tomcat on host $ENVI" $ADMINS < $LOGMY
rm -f $LOGMY
# do something as file has data
rm $TOUCHME
touch $TOUCHME
chmod 777 $TOUCHME

exit 0
