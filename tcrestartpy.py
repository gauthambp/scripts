#!/usr/bin/python
import os
import subprocess
proc=raw_input("Enter the mode :")
os.environ["JAVA_HOME"] = '/usr/local/java/jdk1.7.0_25';
os.environ["JRE_HOME"]='/usr/lib/jvm/java-7-openjdk-amd64/jre';
os.environ["CATALINA_HOME"] = '/export/apps/tomcat7';
os.environ["PATH"] = '$JAVA_HOME/bin:$PATH';
if proc == "start":
  subprocess.call(['/export/apps/tomcat7/bin/catalina.sh', 'start'])
elif proc == "stop":
  subprocess.call(['/export/apps/tomcat7/bin/catalina.sh', 'stop'])
  print "Tomcat stopped successfully"
elif proc == "restart":
  subprocess.call(['/export/apps/tomcat7/bin/catalina.sh', 'stop'])
  subprocess.call(['/export/apps/tomcat7/bin/catalina.sh', 'start'])
  print "tomcat restarted successfully"
else:
  print "error: give any mode"
print "Thank you"
