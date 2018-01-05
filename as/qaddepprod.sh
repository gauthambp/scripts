#! /bin/sh

#Name of this program
PROG=`basename $0`

ENVI="qtcprod"


if [ $(id -u) != 0 ]; then
     echo "Please run as root"
        exit
     # elevate script privileges
fi

echo -e "Install on Prod: 1"

read opt

if test $opt -eq 1
then
echo "Enter the package Name:Ex:CST79,RPT99"
read pkg
        if cp -R /qtc/qadee2010/migrate/CSTxx/install_org/ /qtc/qadee2010/migrate/$pkg/install
	then
        cd /qtc/qadee2010/migrate/$pkg/install;chmod 775 *
        echo -e "Installation will start from  `pwd` \n Enter 1  to confirm \n"
	read confirm
		if test $confirm -eq 1  
		then
                ./installxx_all.sh qtcprod $pkg>install.log 2>install.err
	        more *.log
		#cd /apps/qadee2010/qtcprod/psc-cust/us/xx/;chmod 775 *;chgrp is *
                cd /apps/qadee2010/$ENVI/psc-cust/us/;find . -type f -mmin -20 -exec chmod 775 {} \;
                cd /apps/qadee2010/$ENVI/psc-cust/us/;find . -type f -mmin -20 -exec chgrp is {} \;
                echo "The files below were changed or created in Last 20 minutes"
                cd /apps/qadee2010/$ENVI/psc-cust/us/;find . -type f -mmin -20 -exec ls -ltr {} \;                
		else
		echo "Install folder has been copied:Exiting Program"
		fi
	else
        echo "Please copy folder $pkg"
	exit
fi
else
if test $opt -eq 2
then
echo "Enter the package Name:Ex:CST79,RPT99"
read pkg2
cd /qtc/qadee2010/migrate/$pkg2/;mv install install_prep
cp -R /qtc/qadee2010/migrate/CSTxx/install_org/ /qtc/qadee2010/migrate/$pkg2/install
fi
fi
