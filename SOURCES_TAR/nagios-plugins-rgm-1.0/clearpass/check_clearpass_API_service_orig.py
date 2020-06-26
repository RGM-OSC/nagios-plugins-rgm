#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return service state from Clearpass Appliance.
  * 
  * 

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>, Samuel RONCIAUX <sronciaux@fr.scc.com>    START DATE :    Thu 16 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-04-16  Lucas FUEYO <lfueyo@fr.scc.com>, Samuel RONCIAUX <sronciaux@fr.scc.com>             Initial version
'''

__author__ = "Lucas, FUEYO, Samuel RONCIAUX"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO, Samuel RONCIAUX"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Samuel RONCIAUX"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json, urllib3, urllib

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
urllib3.disable_warnings()


## Declare Functions ######################################################################################################
# Build a custom URL for Clearpass to get a valid Token
def get_token(clearpass_host, client_id, client_name, client_password):
	# Create correct url to request
  request_url = str("https://" + clearpass_host + ":443/api/oauth")

  #Create body to authenticate
  encoded_body = json.dumps({
  "grant_type": "password",
  "client_id": client_id,
  "username": client_name,
  "password": client_password
  })

  # Request the URL and extract the token
  https = urllib3.PoolManager(cert_reqs='NONE')
  r = https.request('POST', request_url,
	headers={'Content-Type': 'application/json'},
	body=encoded_body)

  result = json.loads(r.data)

  return result['access_token']


# Build a custom URL for Clearpass to get the uuid server
def get_server_uuid(clearpass_host, access_token):

  # Create correct url to request
  request_url = str("https://" + clearpass_host + ":443/api/cluster/server")

  # Request the URL and extract the uuid server
  https = urllib3.PoolManager(cert_reqs='NONE')
  r = https.request('GET', request_url,
     headers={'Accept': 'application/json',
     'Authorization': 'Bearer '+ access_token})

  result = json.loads(r.data)

  return result['_embedded']['items'][0]['server_uuid']

# Build a custom URL for Clearpass to get a specific service status by name
def get_service_status(clearpass_host, clearpass_service, client_id, client_name, client_password):

  try:

    retcode = 3

    # Get authentication token
    access_token = get_token(clearpass_host, client_id, client_name, client_password)

    # Get server uuid
    server_uuid = get_server_uuid(clearpass_host, access_token)

    # Create correct url to request
    request_url = str("https://" + clearpass_host + ":443/api/server/service/" + server_uuid + "/" + clearpass_service)

    # Request the URL and extract the token
    https = urllib3.PoolManager(cert_reqs='NONE')
    r = https.request('GET', request_url,
       headers={'Accept': 'application/json',
       'Authorization': 'Bearer '+ access_token})

    result = json.loads(r.data)

    if(result['state'] != 'Running'):

      retcode = 2

    else:

       retcode = 0

    print("{rc} - {name} - 'state': {state}".format(
        rc=NagiosRetCode[retcode],
        name=result['display_name'],
        state=result['state']))
    exit(retcode)

  except Exception as e:
    print("Error calling \"get_service_status\"... Exception {}".format(e))
    sys.exit(3)

if __name__ == '__main__':

  get_service_status('10.112.11.196', 'cpass-sysmon.service', 'rgm', 'rgm', 'Constell@tion123')
