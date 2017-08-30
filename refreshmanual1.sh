#! /bin/bash
#script to refresh OA test and dev
restorepath="/db/"
environ="LIVE60"
ver=101C . /usr/local/dlc/bin/dlcverset
echo "Enter the date to be restored in example format 20170813"
read defdate

for dbname in open_x openacc openarch openstrt;do
echo Y|prorest /db/opendb/oatest60/oa_data/$dbname  $restorepath$dbname$environ.$defdate.bu;
done
