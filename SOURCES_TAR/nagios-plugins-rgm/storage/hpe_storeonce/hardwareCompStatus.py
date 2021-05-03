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

HARDWARE_INFO = "HARDWARE INFORMATION:"


def getHardwarejsonOutput(stdout):
    """
    converts the hardware tree into a proper json output
    :param stdout: output of hardwareTree command
    :return: Dictionary with hardware information
    """
    extended_info = "{"
    for line in stdout.split("\n"):
        if "D2DHwItem" not in line and "{" not in line and "}" not in line and "]" not in line:
            extended_info += line + "\n"
    extended_info += "}"
    return extended_info


def getStatusHardwareInfo(dict_hardware_tree):
    """
      get the status information from the hardware dictionary
     :Dictionary with hardware information
     :return: hardware status
     """
    for key, value in dict_hardware_tree.iteritems():
        if key == 'statusText':
            return value


def main():
    """
    parses the command line arguments and does some sanity checks on them, runs the curl commands and displays
    appropriate output
    :return:
    """
    total = len(sys.argv)
    if total <= 3:
        print("Invalid Input, please pass the IP, username and password")
        exit(1)

    ip = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

    command_hwTree = "curl -s --insecure --user '%s:%s' \"https://%s/d2dservices/hwDetail/D2DHwViewTree?media=json\"" % (
    username, password, ip)
    command_serverHardware = "curl -s  --insecure --user '%s:%s' \"https://%s/fusion/chassis/*all*/serverhardware/*all*?view=info&media=txt&notitle=true\"" % (
    username, password, ip)

    timeout = 300
    [retcode, stdout, stderr] = runCmd(command_hwTree, timeout)

    found = 0
    for line in stdout.split("\n"):
        if line.find("D2DHwItem") != -1:
            found = 1

    if found == 0:
        print "UNKNOWN ERROR: unable to retrieve Hardware Information"
        print stdout
        sys.exit(3)

    if retcode == 0:
        hardwarejsonOp = getHardwarejsonOutput(stdout)
        my_dict = json.loads(hardwarejsonOp);
        status = getStatusHardwareInfo(my_dict)

        [serverHardcode, serverHardout, serHardErr] = runCmd(command_serverHardware, 300)
        if serverHardcode == 0:
            if status == 'failure':
                print "CRITICAL - Hardware Status: %s" % status
                print "\n" + HARDWARE_INFO + "\n"
                print serverHardout
                sys.exit(2)
            elif status == 'up':
                print "OK - Hardware Status: %s" % status
                print "\nHARDWARE INFORMATION:\n"
                print serverHardout
                sys.exit(0)
            else:
                print "WARNING - Hardware Status: %s" % status
                print "\nHARDWARE INFORMATION:\n"
                print serverHardout
                sys.exit(1)

        else:
            print "UNKNOWN ERROR - unable to retrieve hardware information"
            for line in stdout.split("\n"):
                extended_info += line + "\n"
                print extended_info
            sys.exit(3)


if __name__ == "__main__":
    """
    """
    main()
