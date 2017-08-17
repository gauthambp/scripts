#! /bin/bash
restorepath="/qadbkup/qadee2010/qtcprod/gbprefreshdata/"
envi="qtcprep"
ver=102B . /usr/local/dlc/bin/dlcverset
echo "Enter the date to be restored in example format 20170813"
read defdate

for dbname in admprod qxevents hlprod;do
echo Y|prorest /db/qadee2010/$envi/$dbname  $restorepath$dbname.$defdate.bu;
done

for dbname in mfgprod ;do
echo Y|prorest /db/qadee2010/$envi/$dbname  $restorepath$dbname.$defdate.bu;
  if [ $? -ne 0 ];do
  proutil $dbname -C EnableLargeFiles
  echo Y|prorest /db/qadee2010/$envi/$dbname  $restorepath$dbname.$defdate.bu;
  done
done

for dbname in cpdprod;do
echo Y|prorest /db/qadee2010/configurator52/$envi/$dbname  $restorepath$dbname.$defdate.bu;
done

for dbname in qxodb;do
echo Y|prorest /db/qadee2010/qxtend/qxodb/$dbname  $restorepath$dbname.$defdate.bu;
done

for dbname in mfgcustom;do
echo Y|prorest /db/qadee2010/custom/$dbname  $restorepath$dbname.$defdate.bu;
done
