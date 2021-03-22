#!/usr/bin/python

# (C) Copyright 2017 Hewlett Packard Enterprise Development LP

import os, sys
import time
import subprocess
import logging
import shlex
import json
from commands import waitTillTimeout, runCmd

def getStatusServicesetInfo(stdout):
    """
    gets the serviceSet overallstatus
    :param stdout: servcieSet output
    :return: overallSTatus of serviceSets
    """
    mark_status = 0
    status = ''
    for line in stdout.split("\n"):
        if 'ServiceSet Status' in line:
            status+= line
    for line in status.split("\n"):
        if "Running" not in line:
            mark_status = 1
            break
    if mark_status == 0:
        overall_status = 'Running'
    else:
        overall_status = 'Fault'
    if status =='':
        return status
    else:
        return overall_status

def getServciesetoutput(stdout):
    """
    removes the output with URL's not requiredto be displayed as part of serviceset infromation
    :param stdout: serviceSetOutput retrieved from curl command
    :return: ServiceSet ouput after removing unnecessary information.
    """

    output =''
    not_include_line = 0
    for line in stdout.split("\n"):
        if "Services" in line or "URL" in line:
            not_include_line = 1
        if "Services" not in line and "/cluster/" not in line and "URL" not in line:
            if not_include_line == 0:
                output+= line+ "\n"
            else:
                not_include_line = 0
    return output


def main():
    """ parses the command line arguments and does some sanity checks on them, runs curl commands
        and displays the output
    """

    total = len(sys.argv)
    if total <= 3:
        print("Invalid Input, please pass the IP, username and password")
        exit(1)

    ip = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

    command_serviceset_health = "curl -s --insecure --user '%s:%s' \"https://%s/storeonceservices/cluster/servicesets?view=info&media=txt\"" % (
    username, password, ip)
    timeout = 300
    [retcode, stdout, stderr] = runCmd(command_serviceset_health, 300)

    for line in stdout.split("\n"):
        if line.find("Timeout") != -1:
            print "WARNING - Timeout while trying to reach the server"
            sys.exit(1)
    if stdout =="":
        print "WARNING - No Service Sets returned"
        sys.exit(1)

    if retcode == 0:
        servcieSetoutput = getServciesetoutput(stdout)
        status = getStatusServicesetInfo(stdout)
        if status == "Running":
            print "OK - Serviceset Status: Running\n"
            print servcieSetoutput 
            sys.exit(0)
        elif status == "Fault":
            print " WARNING - ServiceSet Status: %s\n" % status
            print servcieSetoutput
            sys.exit(1)
        else:
            print
            "UNKNOWN ERROR: Unknown Status: %s\n" % status
            print servcieSetoutput
            sys.exit(3)
    else:
        print "UNKNOWN ERROR - Unable to retrieve Servcieset Information"
        print stdout
        sys.exit(3)

if __name__ == "__main__":
    main()
