#!/usr/bin/python

# (C) Copyright 2017 Hewlett Packard Enterprise Development LP

import os, sys
import datetime
from datetime import timedelta 
import time
import subprocess
import logging
import shlex
import json
from commands import waitTillTimeout, runCmd

def printvtl_libInfo(stdout):
    """
    extract the list of VTL libraries
    :param stdout: VTL library information
    :return: VTL library URI
    """
    uri_list = []
    for line in stdout.split("\n"):
        if "Report URI" in line:
            uri_list.append(line[line.find('Report URI') + 15 :])
    return uri_list

def get_servicesets(stdout):
    """
    get the list of service sets
    :param stdout: service set information
    :return: list of service sets
    """
    serviceset_list = []
    for line in stdout.split("\n"):
        if "ServiceSet ID" in line:
            serviceset_list.append(line[line.find(':') + 3:])
    return serviceset_list


def run_vtl_commands(username, password,ip,serviceset_id):
    """
    :param username: username
    :param password: password
    :param ip: ip
    :param serviceset_id: service set id
    :return:
    """
    cmdstorageHour = "curl  -s --insecure --user '%s:%s' \"https://%s/storeonceservices/cluster/servicesets/%s/services/vtl/parametrics/storage/reports/hour/libraries?media=txt\""%(username,password,ip,serviceset_id)
    tmpCmd = "curl -s  --insecure --user '%s:%s' \"https://%s/storeonceservices"%(username,password,ip)

    timeout=300

    [retcode, stdout, stderr] = runCmd(cmdstorageHour,timeout)
    content = ''
    if retcode ==0 :

        libList = printvtl_libInfo(stdout)
        for x in libList:
            currentDateTime = datetime.datetime.now()
            myTime = currentDateTime - timedelta(minutes=60)

            timestamp = myTime.strftime('%Y-%m-%dT%H:%M:%SZ')
            cmdstorage = tmpCmd+x+"?startTime="+timestamp+"&media=txt"+"\""
            [libretcode, libstdout, libstderr] = runCmd(cmdstorage,300)
            readTh =''
            writeTh =''
            lib =  x[x.find('/libraries/') + 1 :]
            content += lib +"\n"
            for line in libstdout.split("\n"):
                if "User Bytes" in line:
                    content += line 
                if "Disk Bytes" in line:
                    content +=line 
                if "Configured Cartridges" in line:
                    content += line 
                    content +="\n"
        if content == "":
            print "WARNING | No VTL Libraries Configured"
            sys.exit(1)
        else:
            print "OK | %s" %content
            sys.exit(0)
    else:
        if content == "":
            print "WARNING | No VTL Libraries Configured"
            sys.exit(1)
        else:
            print "ERROR - unable to retrieve VTL storage information"
            print "%s" %stdout
            sys.exit(3)

def main():
    """
    parses the command line arguments and does some sanity checks on them, runs curl commands
    and displays the output
    :return:
    """

    total = len(sys.argv)
    if total <= 3:
      print("Invalid Input, please pass the IP, username and password")
      exit(1)

    ip = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]
    
    timeout = 300

    serviceset_cmd = "curl  -s --insecure --user '%s:%s' \"https://%s/storeonceservices/cluster/servicesets?media=txt\""%(username,password,ip)

    [retcode, stdout, stderr] = runCmd(serviceset_cmd,timeout)
    
    if stdout =="":
        print "No Service Sets returned"
        sys.exit(1)

    serviceset_list = get_servicesets(stdout)

    for i in serviceset_list:
        run_vtl_commands(username,password,ip,i)

if __name__ == "__main__":
    main()


