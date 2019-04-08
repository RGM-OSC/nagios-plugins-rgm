######################################
##Hycu script to check  backup status of a particular vm using Hycu restapi
## release 0.1 still under improvement
##christophe.Absalon@hycu.com
##this script can be use with any motitoring in direct or using proxy
## Script develop with Python 3.7 on Hycu 3.5
####################################

import requests
import json
import urllib3
import optparse
## remove warning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


####arguments as parameter
parser = optparse.OptionParser('usage%prog'+' -username <username>'+' -password <pass> '+' -host <hycu host>' + ' -vm <vm> ')
parser.add_option('-u', dest='username', help='The Username for authentication.')
parser.add_option('-p', dest='password', help='The password for authentication.')
parser.add_option('-l', dest='host', help='hycu host.')
parser.add_option('-v', dest='vm', help='A vm to check')
(options,args) = parser.parse_args()
myuser = options.username
mypass = options.password
myhost = options.host
myvm = options.vm

#print (myuser,mypass,myhost,myvm)




#path to api
apiurl = 'https://'+myhost+':8443/rest/v1.0/vms'

r = requests.get(apiurl, auth=(myuser,mypass), cert="",timeout=100,verify=False)
j = r.json()

#discover how many vms and store value
counter = (j['metadata']['grandTotalEntityCount'])

#initiate counter
count = 0
#create dictionnary 
dicovm = {}

#loop to fullfil dictionnary
while ( count < counter ) :
 

 vmname = (j['entities'][count]['vmName'])
 vmuuid = (j['entities'][count]['uuid'])
 vmcount = count
 dicovm [vmname] = (vmuuid)
 count = count + 1

 continue
#store  UUID of the vm specify as variable
uuid_target = (dicovm.get(myvm))
#print (uuid_target)

##################### 
##now we will parse the uid and check the last one
####################

###inject uuid in api url
apiurlbackup = 'https://'+myhost+':8443/rest/v1.0/vms/'+uuid_target+'/backups?pageNumber=1'

##create request
r2 = requests.get(apiurlbackup, auth=(myuser,mypass), cert="",timeout=100,verify=False)
j2 = r2.json()

#we look what is the total of backup
counter2 = (j2['metadata']['grandTotalEntityCount'])
if (counter2 == 0):
	backupresult = 0
	print (myvm, 'have no Backup |Backup_status=',backupresult,';;;')
	exit(2)
	
#we go on last backup  
count = counter2 - 1
#we print backup status

Backup_vm = (j2['entities'][count]['vmName'])
Backup_uuid = (j2['entities'][count]['uuid'])
Backup_status = (j2['entities'][count]['status'])
Backup_compliancy = (j2['entities'][count]['compliancy'])
Backup_type = (j2['entities'][count]['type'])

if (Backup_status == 'WARNING'):
	backupresult = 1
	EXITCODE=1

elif (Backup_status == 'OK'):
	backupresult = 2
	EXITCODE=0

elif (Backup_status == 'FATAL'):
	backupresult = 0
	EXITCODE=2


print (Backup_vm, 'is' ,Backup_status,'for last', Backup_type,'|Backup_status=', backupresult,';;;')
exit(EXITCODE)
#print (Backup_vm,';',Backup_uuid,';',Backup_status,';',Backup_compliancy,';',Backup_type)


