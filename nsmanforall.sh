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
#
# TODO

#HOSTNAME=`uname -n`; export HOSTNAME
# Use format below on Solaris: USER="`/usr/xpg4/bin/id -un`"
# Use this format on Linux hosts: USER="`/usr/bin/id -un`"
USER="`/usr/bin/id -un`"
TIMESTAMP=`date "+%Y%m%d_%H%M%S"`
PORT_NUMBER="20944"



for vers in 111 116 102B 115
do
if ps -eaf | grep "/usr/local/dlc/$vers/" | grep "root" > /dev/null 2>&1;then
  if ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1" | grep "root" > /dev/null 2>&1 ;then
  res=`ps -eaf | grep "rmi://$HOSTNAME:$PORT_NUMBER/NS1"| grep "root"`
  ver=$vers . /usr/local/dlc/bin/dlcverset

    if [[ $OSTYPE == "solaris2.10"  ]]; then
      /usr/ucb/ps wwaux | grep "$PORT_NUMBER" | grep "root" > /dev/null 2>&1
      nsman -i NS1 -port $PORT_NUMBER -q |  /usr/xpg4/bin/grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt
    else
      nsman -i NS1 -port 20944 -q | grep -e  AS -e WS | awk '{print $2}' > echogpAS.txt
    fi

    for word in `cat echogpAS.txt`;do
    word=${word:3}
    nsman -i $word -port 20944 -q
    done
    rm echogpAS.txt
  fi
fi
done
