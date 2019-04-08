#!/usr/bin/python
import os, sys
import subprocess
import logging
import shlex
import time
import signal

def waitTillTimeout(proc, timeout=300):
    """
    poll the process,wait until the process timeout occurs.
    :param proc: process handle
    :param timeout: timeout
    :return:
    """
    start_time = time.time()
    proc.poll()
    while proc.returncode == None:
        if time.time() > start_time + timeout:
            os.kill(proc.pid, signal.SIGKILL)
            return "Timeout while trying to connect to the server"
            break
        time.sleep(0.5)
        proc.poll()

def runCmd(command,timeout):
    """
    run the commands
    :param command: command to run
    :param timeout: timeout for the command.
    :return: return code of the command, output of the command, timeout if the command timed out.
    """
    args = shlex.split(command)
    try:
        proc = subprocess.Popen(args, shell=False, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, preexec_fn=os.setpgrp)
        outTimeout = waitTillTimeout(proc, timeout)
        retcode = proc.returncode

        [stdout, stderr] = proc.communicate()
        if outTimeout == "Timeout while trying to connect to the server":
            stdout = outTimeout

    except OSError, e:
        logging.error("'%s' could not be run: %s" % (command, e.strerror))
    except ValueError, e:
        logging.error("invalid arguments passed to Popen: %s" % (e))
    
    return [retcode, stdout, stderr]
