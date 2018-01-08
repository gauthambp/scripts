#!/usr/bin/python

#This program will check the appserver status on the server, then will present the appservers as choice to be either restarted, stopped or queried.
import os
list=os.popen("ver=102B . /usr/local/dlc/bin/dlcverset;nsman -i NS1 -port 20943 -q|awk '{print $2}'|grep -e AS -e WS").read()
listvar=[]
listvar=list.splitlines()
newlistvar=[x.split('.')[-1] for x in listvar]
#Added on 27Oct to list the appservers
print "The following appservers are seen on the server"
#k used to create a dictionary holder
k={}
for i,j in enumerate(newlistvar):
    print i,j
    k[i]=j

#print "Select the appserver to be used"
#The appserver needs to be stopped started or queired"
i = input("Select the appserver to be used\n")
myname=k[i]
print "You have selected the following Appserver"
print myname

print "Select the options to be used"
print "q-Query the AppServer"
print "2-Stop the AppServer"
print "3-Start the AppServer"
print "4-Kill the AppServer"
k = input("Select the options to be used\n")


myoutput=os.popen("ver=102B . /usr/local/dlc/bin/dlcverset;nsman -i %s -port 20943 -q" %myname).read()
print myoutput
