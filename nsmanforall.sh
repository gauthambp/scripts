#! /bin/sh
#
# This script checks the Appservers on a Machine and reports the List.
#
# USAGE: nsmanforall.sh
#
#
# DEPENDENCIES:
#
#
# DONE
#changed sh to bash to support linux and solaris
#31-Aug added  port number for loop- added the loop for running the nsman inside the for loop for version
# TODO
# Check and loop through port numbers


# Use format below on Solaris: USER="`/usr/xpg4/bin/id -un`"
# Use this format on Linux hosts: USER="`/usr/bin/id -un`"
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
#PORT_NUMBER="20944"

#Checks OS type first to run the adminserver check
for PORT_NUMBER in 20942 20943 20944;do

if [[ $OSTYPE == "solaris2.10"  ]]; then
  /usr/ucb/ps wwaux | grep "$PORT_NUMBER" | grep "root" > /dev/null 2>&1
  #loops through the most common version of openedge installed in progress network
  for vers in 111 116 102B 115;do
    /usr/ucb/ps wwaux |grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1" | grep "root" | grep "/usr/local/dlc/$vers/dlc" > /dev/null 2>&1
    if [ $? == 0 ];then
    ver=$vers . /usr/local/dlc/bin/dlcverset
    nsman -i NS1 -port $PORT_NUMBER -q |  /usr/xpg4/bin/grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt
    for word in `cat echogpAS.txt`;do
      word=${word:3}
      nsman -i $word -port $PORT_NUMBER -q
    done
    fi
  done
else
  for vers in 111 116 102B 115;do
    if ps -eaf | grep "/usr/local/dlc/$vers/" | grep "root" > /dev/null 2>&1;then
      ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1" | grep "root" | grep "/usr/local/dlc/$vers/dlc" > /dev/null 2>&1
      if [ $? == 0 ];then
      res=`ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1"| grep "root"`
      ver=$vers . /usr/local/dlc/bin/dlcverset
      nsman -i NS1 -port $PORT_NUMBER -q | grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt
        for word in `cat echogpAS.txt`;do
          word=${word:3}
          nsman -i $word -port $PORT_NUMBER -q
        done
        rm echogpAS.txt
      fi
    fi
  done
fi

done

#Final loop that loops the information file to give the status of appservers
