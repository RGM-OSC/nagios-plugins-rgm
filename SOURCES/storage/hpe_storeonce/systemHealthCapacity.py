#!/usr/bin/python

# (C) Copyright 2017 Hewlett Packard Enterprise Development LP

import os
import sys
import time
import subprocess
import logging
import shlex
import json
from commands import waitTillTimeout, runCmd


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

    IP = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

    command_systemhealth_capacity = "curl -s --insecure --user '%s:%s' \"https://%s/d2dservices/storagesets?view=info&media=txt\""%(username,password,IP)

    timeout = 300
    [retcode, stdout, stderr] = runCmd(command_systemhealth_capacity,timeout)
    retStatus = 0

    for line in stdout.split("\n"):
        if line.find("Timeout") != -1:
            print "WARNING - Timeout while trying to reach the server"
            sys.exit(1)

    for line in stdout.split("\n"):
        if line.find("Status") != -1:
            retStatus = 1

    if retcode == 0:
        if retStatus ==1:
            print "OK - Successfully retrieved System Health and Capacity Information\n"
            print stdout
            sys.exit(0)
        else:
            print "Warning - %s" %stdout
            sys.exit(1)
    else:
        print "ERROR - unable to retrieve System Health and Capacity Information "
        print stdout
        sys.exit(3)

if __name__ == "__main__":
   main()
