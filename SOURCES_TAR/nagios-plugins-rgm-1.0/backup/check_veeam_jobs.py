#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return jobs state from Veeam Enterprise Manager Rest API.
  * 
  * 

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Thu 29 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-10-29  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
'''

__author__ = "Lucas, FUEYO"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas Fueyo"

## MODULES FEATURES ###################################################################################################

# Import the following modules:
import sys
import argparse
import requests
import json
import urllib3
import base64
import jmespath

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
urllib3.disable_warnings()

## Declare Functions ##################################################################################################


# Build a custom URL for Veeam to get a valid Token
def get_token(EM_host, username, password):

    try:
        # Create correct url to request
        request_url = str(
            "https://" + EM_host + ":9398/api/sessionMngr/?v=latest"
        )

        auth_string = username + ":" + password
        auth_bytes = auth_string.encode('ascii')
        encoded_auth = base64.b64encode(auth_bytes)
        headers = {"Authorization": "Basic " + encoded_auth.decode()}

        # Request the URL and extract the token
        https = urllib3.PoolManager(cert_reqs='NONE')
        r = https.request(
            'POST', request_url,
            headers=headers
        )

        access_token = r.headers['X-RestSvcSessionId']

        return access_token

    except Exception as e:
        print("Error calling \"get_token\"... Exception {} --- Verify login or password !".format(e))
        sys.exit(3)


# Build a custom URL for Veeam to get the job list
def get_job_list(EM_host, access_token, job_name):

    try:
        # Create correct url to request
        request_url = str(
            "https://" + EM_host + ":9398/api/jobs"
        )

        # Request the URL and extract the job IDs
        https = urllib3.PoolManager(cert_reqs='NONE')
        r = https.request(
            'GET', request_url,
            headers={
                'Accept': 'application/json',
                'X-RestSvcSessionId': access_token
            }
        )

        result = json.loads(r.data)

        if(job_name):
            job_list = jmespath.search(
                "Refs[*].Links[?Type == 'Job' && Name == '" + job_name + "'].Href",
                result
            )
        else:
            job_list = jmespath.search(
                "Refs[*].Links[?Type == 'Job'].Href",
                result
            )

        return job_list

    except Exception as e:
        print("Error calling \"get_job_list\"... Exception {}".format(e))
        sys.exit(3)


# Build a custom URL for Veeam to get the last backup session state from each job
def get_last_backupsession(EM_host, access_token, job_list):

    try:
        https = urllib3.PoolManager(cert_reqs='NONE')

        # Create the query to retrieve the last backup session
        query = jmespath.compile(
            "sort_by(BackupJobSessions, &CreationTimeUTC)[-1].{JobName: JobName, CreationTimeUTC: CreationTimeUTC, State: State, Result: Result, FailureMessage: FailureMessage}"
            )

        state_list = []
        # Create correct url to request
        for request_url in job_list:
            if(request_url):
                request_url = request_url[0].replace(
                    '?format=Entity','/backupSessions?format=Entity'
                )

                r = https.request(
                    'GET', request_url,
                    headers={
                        'Accept': 'application/json',
                        'X-RestSvcSessionId': access_token
                    }
                )

                result = json.loads(r.data)
                state_list += [query.search(result)]

        return state_list

    except Exception as e:
        print("Error calling \"get_last_backupsession\"... Exception {}".format(e))
        sys.exit(3)


# Build a custom URL for Veeam to get a specific backup status (by name if specified)
def get_last_backupstatus(EM_host, username, password, job_name):

    try:
        retcode = 0
        outtext = []
        outjobs = []
        sortedjobs = []

        # Get authentication token
        access_token = get_token(EM_host, username, password)

        # Get job list
        job_list = get_job_list(EM_host, access_token, job_name)

        # Get last backup job state 
        state_list = get_last_backupsession(EM_host, access_token, job_list)

        total_jobs_failed = 0

        # Retrieve results and format them
        for job in state_list:
            if(job['Result'] == 'Success'):
                job_ret_code = 0
            elif(job['Result'] == 'Warning'):
                job_ret_code = 1
                total_jobs_failed += 1
                if(retcode == 0):
                    retcode = 1
            elif(job['Result'] == 'Failed'):
                job_ret_code = 2
                total_jobs_failed += 1
                retcode = 2
            else:
                job_ret_code = 3

            outjobs.append(
                "\n {state} - Status : {jobResult} - Name : {name} -" \
                " Creation Time (UTC) : {creationTime} - Failure Message : {failureMessage}".format(
                    state=NagiosRetCode[job_ret_code],
                    jobResult=job['Result'],
                    name=job['JobName'],
                    creationTime=job['CreationTimeUTC'],
                    failureMessage=job['FailureMessage']
                )
            )

        outtext.append(
            "{total_jobs_failed} job failed".format(
                total_jobs_failed=total_jobs_failed
            )
        )

        for line in outjobs:
            if 'CRITICAL' in line:
                sortedjobs.append(line)
        for line in outjobs:
            if 'WARNING' in line:
                sortedjobs.append(line)
        for line in outjobs:
            if 'OK' in line:
                sortedjobs.append(line)

        print(
            "{}: {} {}".format(
                NagiosRetCode[retcode],
                " ".join(outtext),
                " ".join(sortedjobs)
            )
        )

        exit(retcode)

    except Exception as e:
        print("Error calling \"get_last_backupstatus\"... Exception --- Verify service name ! {}".format(e))
        sys.exit(3)


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin used to return Veeam "backup jobs last Status" from a Veeam Enterprise Manager server.
        Job Name is defined as an argument to select only one job.
        """,
        usage="""
        Get job status of "veeam_server" --> Have Critical alert if jobs are failed !

        python3 check_veeam_jobs.py -H veeam_server -n job_name -u username -p password
        
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address of Enterprise Manager server', required=True)
    parser.add_argument('-u', '--user', type=str, help='Veeam user name', required=True)
    parser.add_argument('-p', '--password', type=str, help='Veeam password', required=True)
    parser.add_argument('-n', '--job', type=str, help='Veeam Backup job name', required=False)
    args = parser.parse_args()	

    get_last_backupstatus(
        args.hostname,
        args.user,
        args.password,
        args.job
    )
