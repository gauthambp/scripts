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
ADMINS="gpujari@progress.com sponduri@progress.com skarre@progress.com"
LOGMY=/tmp/tmptc.log
TCLOGLOC=/usr/local/tomcat/current/logs/catalina.out


touchme='/tmp/tcrsentry.log'
filelines=`cat $touchme`

if [ $(id -u) != 59903 ]; then
     echo "Please run as tomcat user"
        exit
     # elevate script privileges
fi

if [ -s "$touchme" ]
then
        echo "$touchme has some data."
        # do something as file has data
else
        echo "$touchme is empty."
        exit 0
        # do something as file is empty
fi


for entry in $filelines
do
echo "The filelist contains $entry"

if [ $entry == "restart" ]
then
        echo "$touchme has some data."
        /usr/local/tomcat/current/bin/catalina.sh stop -force
        sleep 60
        /usr/local/tomcat/current/bin/catalina.sh start
        sleep 90
        tail -200 $TCLOGLOC > $LOGMY
        #echo "The files below were changed or created in Last 20 minutes" >> $LOGMY
        #cat $LOGMY
        mailx -s "Log - Restart tomcat on host $ENVI" $ADMINS < $LOGMY
        rm -f $LOGMY
        # do something as file has data
else
        echo "$touchme is empty.No restart would be done"
        exit 0
        # do something as file is empty
fi

done

rm $touchme
touch $touchme
chmod 777 $touchme

exit 0
