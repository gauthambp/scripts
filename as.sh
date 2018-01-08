#! /bin/bash


if [ -d "/usr/local/qadee2010/qtcprep" ]
then
{
ENVI="qtcprep";
echo $ENVI
#ENVI=`uname -n`;
opt=0;
selection=0;
TODAY=${TODAY-`date +'%Y%m%d'`}
}
fi

fun_servlogin()
{
ssh gpujari@$hname
}


fun_name()
{
printf "Enter the hostname that you want to login\n"
read hname
printf "logging into host $hname\n"
ssh gpujari@$hname
}



select_fun()
{
printf "Select 1 for server log\n"
printf "Select 2 for broker log\n"
read opt
}

select_fundb()
{
printf "1-mfgprod\n"
printf "2-qxodb\n"
printf "3-qxevents\n"
printf "4-hlprod\n"
printf "5-cpdprod\n"
printf "6-admprod\n"
printf "7-mfgcustom\n"
printf "8-tms\n"
printf "9-qxtend logs\n"
read opt
}


select_funrestart()
{
printf "1-shut.all logs \n"
printf "2-start.all logs \n"
printf "3-refresh.all logs\n"
read opt
}

fun_apptest()
{
echo $HOSTNAME | grep lxqtctest
if [ $? -eq 0 ];then
./qaddeptest.sh
else
./qaddepprep.sh
fi
}

catusercount_fun()
{
tail -f /usr/local/tomcat/current/webapps/$ENVI/WEB-INF/logs/usercount.log
}

tmslog_fun()
{
tail -f /apps/qadee2010/tms/xt/log/xt_eeapi.log
}


qadfinlog_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/$ENVI/qadfin$ENVI.server.000010.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/$ENVI/qadfin$ENVI.broker.log
fi
}

qxoui_AS_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/qxtend/qxoui_AS.server.000001.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/qxtend/qxoui_AS.broker.log
fi
}

qxosi_AS_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/qxtend/qxosi_AS.server.000001.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/qxtend/qxosi_AS.broker.log
fi
}

cpd52_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/configurator52/cpd52_WS$ENVI.server.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/configurator52/cpd52_WS$ENVI.broker.log
fi
}

qadui_WS_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/$ENVI/qadui_WS$ENVI.server.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/$ENVI/qadui_WS$ENVI.broker.log
fi
}

qadsi_AS_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/qxtend/qadsi_AS$ENVI.server.000001.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/qxtend/qadsi_AS$ENVI.broker.log
fi
}

qadui_AS_fun()
{
if test $opt -eq 1
then
tail -f /logs/qadee2010/$ENVI/qadui_AS$ENVI.server.000001.log
fi
#
if test $opt -eq 2
then
tail -f /logs/qadee2010/$ENVI/qadui_AS$ENVI.broker.log
fi
}

fundblogs()
{
#read opt

case "$opt" in


1) tail -f /db/qadee2010/custom/mfgcustom.lg ;;
2) tail -f /db/qadee2010/qxtend/qxodb/qxodb.lg ;;
3) tail -f /db/qadee2010/$ENVI/qxevents.lg ;;
4) tail -f /db/qadee2010/$ENVI/hlpprod.lg ;;
5) tail -f /db/qadee2010/configurator52/$ENVI/cpdprod.lg ;;
6) tail -f /db/qadee2010/$ENVI/admprod.lg ;;
7) tail -f /db/qadee2010/custom/mfgcustom.lg ;;
8) tail -f /db/qadee2010/tms/tms.lg ;;

esac

}


funrestart()
{
case "$opt" in

1) tail -f /logs/qadee2010/$ENVI/shut.$TODAY.log ;;
2) tail -f /logs/qadee2010/$ENVI/start.$TODAY.log ;;
3) tail -f /logs/qadee2010/$ENVI/refresh.$TODAY.log ;;

esac


}


select_mpplus()
{
/users/ops/gpujari/mpplus.sh

}

select_otherdb()
{
case "$opt" in

1) tail -f /db/$dbname/$dbname.lg ;;
2) tail -f /logs/qadee2010/$ENVI/start.$TODAY.log ;;
3) tail -f /logs/qadee2010/$ENVI/refresh.$TODAY.log ;;

esac

}


select_otherdb()
{
case "$opt" in

1) tail -f /db/$dbname/$dbname.lg ;;
2) tail -f /logs/qadee2010/$ENVI/start.$TODAY.log ;;
3) tail -f /logs/qadee2010/$ENVI/refresh.$TODAY.log ;;

esac

}



while true; do
printf "Select Log Files to be displayed\n"

printf "1-logstat to view logs in QAD App\n"
printf "2-qadstat\n"
printf "3-qadcheckout -To deploy code on Test , Prep , Test2\n"
printf "4-uxappprod Integration logs\n"
printf "5-mpplus stack\n"
printf "6-Enter server name that you want to connect by ssh\n"
#printf "6-qxosi_AS\n"
#printf "7-cpd52_WS$ENVI\n"
#printf "8-qadui_WS$ENVI\n"
#printf "9-qadsi_AS$ENVI\n"
#printf "10-qadui_AS$ENVI\n"
#printf "11-DB logs\n"
#printf "12-Shut.all,Start.all,Refresh.all logs\n"
printf "13-Other Db logs\n"
printf "x -exit\n"

read selection

case "$selection" in


1) ./logstat ;;
2) fun_apptest;;
3) ./qadcheckout.sh ;;
4) ./logstatuxappprod
;;
5)select_mpplus
;;
6)fun_name
;;
7)select_fun
cpd52_fun
;;
8)select_fun
qadui_WS_fun
;;
9)select_fun
qadsi_AS_fun
;;
10)select_fun
qadui_AS_fun
;;
12)select_funrestart
funrestart
;;
11)select_fundb
fundblogs
;;
13)select_otherdb
select_otherdb
;;
x)
exit;;


esac

done
}
