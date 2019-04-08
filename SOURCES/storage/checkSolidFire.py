#!/usr/bin/env python
# author: Joe McManus joe.mcmanus@solidfire.com
# file: checkClusterApi.py 
# version: 1.7 2013/05/22
# use: Query clusters and nodes for nagios info, or stand-alone command line 
# coding: utf-8
import urllib2
import base64
import json
import sys
import io
import os.path
import math
import socket
import re
import textwrap
import time 

version="1.7 2013/05/22"

#This is a nagios thing, nagionic you might say. 
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
exitStatus=STATE_OK


checkUtilization=1 	#Generate Alerts on the utilization of cluster space
checkSessions=1    	#Generate Alerts on the number of iSCSI sessions
checkDiskUse=1     	#Generate Alerts on disk access 
checkClusterFaults=1    #Generate Alerts on cluster Faults

def printUsage(error):
	print("ERROR: " + error)
	print("USAGE: " + sys.argv[0] + " (IP|HOSTNAME) PORT USERNAME PASSWORD (mvip|node)")
	sys.exit(STATE_UNKNOWN)

#Check command line options that are passed
def commandLineOptions():
	if len(sys.argv) < 6:
		printUsage("Incorrect Number of Arguments.")
	ip=sys.argv[1]
	port=sys.argv[2]
	username=sys.argv[3]
	password=sys.argv[4]
	ipType=sys.argv[5]
	if ipType != "mvip" and ipType != "node":
		printUsage("Invalid type specified, use node or mvip")
	return ip, port, username, password, ipType

#Send requests to the target
def sendRequest(ip, port, murl, username, password, jsonData, ipType):
	url = 'https://' + ip + ":" + port + murl
	authKey=base64.b64encode(username+ ":" + password)
	request = urllib2.Request(url)
	request.add_data(jsonData)
	request.add_header("Content-Type","application/json-rpc")
	request.add_header("Authorization","Basic " + authKey)
	try: 
		response= urllib2.urlopen(request, timeout=20)
		#Debug info if needed
		#print response.info().headers
		#print response.read()
		jsonResponse=json.loads(response.read())
	except:
		printUsage("Unable to connect to host: " + ip) 
	
	#Check to see if we got a valid jsonResponse
	if 'result' not in jsonResponse:
		printUsage("Invalid response received.")
	else:
		return jsonResponse['result']

#Check for a valid IP
def ipCheck(ip):
        pattern = r"\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
        if re.match(pattern, ip):
                return True
        else:
                return False

#Resolve Hostnames
def checkName(hostname):
	try:
 		socket.gethostbyname(hostname)
	except: 
		printUsage("Unable to resolve hostname " + hostname) 

#Check if new data has been written to disk
def readwriteCheck(fileName, newUse):
	if os.path.isfile(fileName):
		try:
			f=open(fileName, 'r+')
			previousUse=f.readline()
			f.seek(0)
			f.write(newUse)
			f.truncate()
			f.close()
		except: 
			printUsage("Unable to open & write to " + fileName + " check perms or set checkDiskUse=0")
		if newUse == "00": 
			diskUse="No"
			exitStatus=STATE_CRITICAL
		elif previousUse == newUse:
			diskUse="No"
			exitStatus=STATE_WARNING
		else:
			diskUse="Yes"
			exitStatus=STATE_OK
		
	else: 
		try:
			f=open(fileName, 'w')
			f.write(newUse)
			diskUse="n/a"
			f.close()
			exitStatus=STATE_UNKNOWN
		except: 
			printUsage("Unable to open & write to " + fileName + " check perms or set checkDiskUse=0")
			
	return diskUse, exitStatus

#Compare ranges of numbers		
def rangeCheck(critical, warning, value):
	if value > critical:
		exitStatus=STATE_CRITICAL
	elif value > warning:
		exitStatus=STATE_WARNING
	else:
		exitStatus=STATE_OK
	return exitStatus

#Add a asterik to values that are in error
def addNote(testResult, exitStatus, value):
	if testResult != 0:
		value=value + "*"
		if testResult > exitStatus:
			exitStatus = testResult
	return exitStatus, value

#Print a table
def prettyPrint(description, value, width):
	#When printing values wider than the second column, split and print them
	if len(value) > (width/2):
		print("| "  + description.ljust(width/2) + " |" ),	
		i=0
		wrapped=textwrap.wrap(value, 29) 
		for loop in wrapped:
			if i == 0:
				print(loop + "|".rjust(width/2-(len(loop))))
			else: 
				print("| ".ljust(width/2+2) + " | " + loop + "|".rjust(width/2-(len(loop))))
			i=i+1
	else: 
		print( "| " + description.ljust(width/2) + " | " + value  + "|".rjust(width/2-(len(value))))

#Print Exit Status in English
def prettyStatus(exitStatus):
	if exitStatus == 0:
		printStatus="OK"
	elif exitStatus == 1:
		printStatus="*Warning"
	elif exitStatus == 2:
		printStatus="*Critical"
	elif exitStatus == 3:
		printStatus="*Unknown"
	return printStatus

murl="/json-rpc/5.0"
#Check the command line options
commandOpts=commandLineOptions()

ip=commandOpts[0]
port=commandOpts[1]
username=commandOpts[2]
password=commandOpts[3]
ipType=commandOpts[4]

#Check to see if we were provided a name, and check that we can resolve it.
if ipCheck(ip) == False:
                checkName(ip)

if ipType == 'node':
	jsonData=json.dumps({"method":"GetClusterState","params":{},"id":1})
	try:
		response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
		clusterState=response['state']
	except:
		printUsage("State not found, are you sure this is a node?")

	if clusterState != "Active": 
		exitStatus=STATE_UNKNOWN
		clusterMvip="n/a"
		clusterName="n/a"
	else: 
		clusterName=response['cluster']
		jsonData=json.dumps({"method":"TestConnectMvip","params":{},"id":1})
		response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
		details=response['details']
		if 'mvip' in details:
			clusterMvip=details['mvip'] 
			exitStatus=STATE_OK
		else: 
			clusterMvip="*n/a Not in Cluster"
			exitStatus=STATE_WARNING

	if sys.stdout.isatty():
		print("+" + "-"*63 + "+")
		print("| SolidFire Monitoring Plugin v." + version + "|".rjust(19))
		print("+" + "-"*63 + "+")
		prettyPrint("Node Status", clusterState , 60)
		prettyPrint("Cluster Name", clusterName , 60)
		prettyPrint("MVIP", clusterMvip , 60)
		prettyPrint("Execution Time ", time.asctime(time.localtime(time.time())) , 60)
		printStatus=prettyStatus(exitStatus)
		prettyPrint("Exit State ", printStatus , 60)
		print("+" + "-"*63 + "+")
		
	else:
		printStatus=prettyStatus(exitStatus)	
		print ("State: " + printStatus + " Node Status: " + clusterState + " Cluster Name: " + clusterName + " MVIP: " + clusterMvip)

elif ipType == 'mvip': 
	#Get bytes and utilization from GetClusterStats
	jsonData=json.dumps({"method":"GetClusterStats","params":{},"id":1})
	response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
	details=response['clusterStats']
	clusterReadBytes=str(details['readBytes'])
	clusterWriteBytes=str(details['writeBytes'])
	clusterUse=str(details['clusterUtilization'])
	

	#Get ISCSI sessions from ListISCSISessions
	jsonData=json.dumps({"method":"ListISCSISessions","params":{},"id":1})
	response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
	details=response['sessions']
	numSessions=len(details)

	#Get name and members from GetClusterInfo
	jsonData=json.dumps({"method":"GetClusterInfo","params":{},"id":1})
	response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
	details=response['clusterInfo']
	clusterName=details['name']
	ensemble=details['ensemble']
	ensembleCount=len(ensemble)

	#get version info
	jsonData=json.dumps({"method":"GetClusterVersionInfo","params":{},"id":1})
	response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
	clusterVersion=response['clusterVersion']

	#Check Cluster Faults
	if checkClusterFaults == 1:
		clusterFaults=""
		jsonData=json.dumps({"method":"ListClusterFaults","params":{},"id":1})
		response=sendRequest(ip, port, murl, username, password, jsonData, ipType)
		clusterFaultsResponse=response['faults']
		for fault in clusterFaultsResponse:
			if fault['resolved'] != True:
				testResult=STATE_CRITICAL
				date=fault['date'][:-8]
				if clusterFaults == "":
					clusterFaults=date + " " +  fault['details']
				else:
					clusterFaults=clusterFaults + ",  " + date + " " +  fault['details']
		if clusterFaults == "":
			clusterFaults="None";
			testResult=STATE_OK
		exitStatus, clusterFaults=addNote(testResult, exitStatus, clusterFaults)
	else:
		clusterFaults="n/a"
	
	
	if checkDiskUse == 1:
		fileName="/tmp/cluster-" + ip + ".txt"
		newUse=clusterReadBytes + clusterWriteBytes
		diskUse, testResult=readwriteCheck(fileName, newUse)
		exitStatus, diskUse=addNote(testResult, exitStatus, diskUse)
		
	else: 
		diskUse="n/a"

	if checkUtilization == 1:
		testResult=rangeCheck(90, 80, float(clusterUse))
		exitStatus, clusterUse=addNote(testResult, exitStatus, clusterUse)	
		
	#In SolidFire OS v.5 we have a soft limit of 250  Volumes * 4 active sessions per node
	maxSessions=ensembleCount * 1000 * .90
	warnSessions=maxSessions * .80
	if checkSessions == 1:
		testResult=rangeCheck(maxSessions, warnSessions, numSessions)
		exitStatus, numSessions=addNote(testResult, exitStatus, str(numSessions))	
		
	#check to see if we are being called from a terminal
	if sys.stdout.isatty():
		print("+" + "-"*63 + "+")
		print("| SolidFire Monitoring Plugin v." + version + "|".rjust(19))
		print("+" + "-"*63 + "+")
		prettyPrint("Cluster", ip , 60)
		prettyPrint("Version", clusterVersion , 60)
		prettyPrint("Disk Activity", diskUse , 60)
		prettyPrint("Read Bytes", clusterReadBytes , 60)
		prettyPrint("Write Bytes", clusterWriteBytes , 60)
		prettyPrint("Utilization %", clusterUse , 60)
		prettyPrint("iSCSI Sessions", str(numSessions) , 60)
		prettyPrint("Cluster Faults", clusterFaults , 60)
		prettyPrint("Cluster Name", clusterName , 60)
		prettyPrint("Ensemble Members", str('[%s]' % ', '.join(map(str, ensemble))) , 60)
		prettyPrint("Execution Time ", time.asctime(time.localtime(time.time())) , 60)
		prettyPrint("Exit State ", prettyStatus(exitStatus) , 60)
		print("+" + "-"*63 + "+")
	else:
		print("Status: " + prettyStatus(exitStatus) + " Cluster IP: " + ip + " Version: " + clusterVersion + 
			" Disk Activity: " + diskUse + " Cluster Faults: " + clusterFaults + 
			" Read Bytes: " + clusterReadBytes + " Write Bytes: " + clusterWriteBytes + 
			" Utilization: " + clusterUse + " ISCSI Sessions: " + str(numSessions) + 
			" Name: " + clusterName + " Ensemble: "  + '[%s]' % ', '.join(map(str, ensemble)) )
 
sys.exit(exitStatus)
