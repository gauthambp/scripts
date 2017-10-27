#! /bin/bash
ver=111 . /usr/local/dlc/bin/dlcverset

while true; do
printf "Select the options\n"

printf "1-To check and rebuild indexes online\n"
printf "2-To rebuild indexes offline\n"
#printf "3-qadcheckout -To deploy code on Test , Prep , Test2\n"
#printf "4-uxappprod Integration logs\n"
#printf "5-mpplus stack\n"
#printf "6-Enter server name that you want to connect by ssh\n"
#printf "6-qxosi_AS\n"
#printf "7-cpd52_WS$ENVI\n"
#printf "8-qadui_WS$ENVI\n"
#printf "9-qadsi_AS$ENVI\n"
#printf "10-qadui_AS$ENVI\n"
#printf "11-DB logs\n"
#printf "12-Shut.all,Start.all,Refresh.all logs\n"
#printf "13-Other Db logs\n"
printf "x -exit\n"

read selection

case "$selection" in


1)proutil /db/adhoc/adhoc -C idxcheck;;
2)proutil /db/adhoc/adhoc -C idxbuild;;
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
fundblogs
;;
x)
exit;;


esac

done
}
