#!/usr/bin/python

import os, sys

OID = '1.3.6.1.2.1.25.4.2.1.5'

if len(sys.argv) < 2:
  print 'Usage: check_ariba_tomcat.py ip_address'
  sys.exit(1)

ariba_version = "ariba9r2"

#cmd1 = os.popen('snmpwalk -v2c -c '+ sys.argv[2] + ' ' + sys.argv[1] + ' '+ OID + ' | grep ariba_tomcat11').read()
#cmd2 = os.popen('snmpwalk -v2c -c '+ sys.argv[2] + ' ' + sys.argv[1] + ' '+ OID + ' | grep ariba_tomcat12').read()
#cmd3 = os.popen('snmpwalk -v2c -c '+ sys.argv[2] + ' ' + sys.argv[1] + ' '+ OID + ' | grep ariba_tomcat13').read()
#cmd4 = os.popen('snmpwalk -v2c -c '+ sys.argv[2] + ' ' + sys.argv[1] + ' '+ OID + ' | grep ariba_tomcat14').read()
cmd1 = os.popen('/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H ' + sys.argv[1] + ' -C "ps -ef | grep "' + ariba_version + '"_tomcat11 | grep -v grep"').read()
cmd2 = os.popen('/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H ' + sys.argv[1] + ' -C "ps -ef | grep "' + ariba_version + '"_tomcat12 | grep -v grep"').read()
cmd3 = os.popen('/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H ' + sys.argv[1] + ' -C "ps -ef | grep "' + ariba_version + '"_tomcat13 | grep -v grep"').read()
cmd4 = os.popen('/srv/eyesofnetwork/nagios/plugins/check_by_ssh -H ' + sys.argv[1] + ' -C "ps -ef | grep "' + ariba_version + '"_tomcat14 | grep -v grep"').read()

final_chain = ""

if cmd1[:-1] == "" or "WARNING" in cmd1[:-1]:
  final_chain += 'Please launch /etc/init.d/' + ariba_version + '_tomcat11 start, '

if cmd2[:-1] == "" or "WARNING" in cmd2[:-1]:
  final_chain += 'Please launch /etc/init.d/' + ariba_version + '_tomcat12 start, '

if cmd3[:-1] == "" or "WARNING" in cmd3[:-1]:
  final_chain += 'Please launch /etc/init.d/' + ariba_version + '_tomcat13 start, '

if cmd4[:-1] == "" or "WARNING" in cmd4[:-1]:
  final_chain += 'Please launch /etc/init.d/' + ariba_version + '_tomcat14 start'

if final_chain != "":
  print 'CRITICAL', final_chain
  sys.exit(2)

else:
  print 'Les 4 noeuds tomcat sont demarres'
  sys.exit(0)
