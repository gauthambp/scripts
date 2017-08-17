#!/bin/bash

filenotfound=1
filefound=1

rm /tmp/filenotfoundoa.txt
rm /tmp/filefoundoa.txt

touch /tmp/filenotfoundoa.txt
touch /tmp/filefoundoa.txt


cat /tmp/myfiles.csv | while read file
do
       # echo $line | cut -d'"' -f4     # get the first name
 #echo $line | cut -d'"' -f18    # get the telephone number
#echo $line
cd /qtc/qadee2010/reports/test
if [ ! -f "$file" ]
then
    #echo "File ${file} not found." >> /tmp/filenotfoundoa.txt
    echo "${file}" >> /tmp/filenotfoundoa.txt
    ((filenotfound++))
elif [ -f "$file" ]
then
    #echo "File '${file}' found." >> /tmp/filefoundoa.txt
    echo "${file}" >> /tmp/filefoundoa.txt
    ((filefound++))
    echo "$file" >> /tmp/filefoundoalist.txt
fi
done

echo "The number of files found from the list are $filefound"
echo "The number of files Not found from the list are $filenotfound"
