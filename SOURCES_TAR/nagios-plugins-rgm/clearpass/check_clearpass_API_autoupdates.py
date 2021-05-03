#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to check cluster wide auto updates parameters of a Clearpass Appliance.
  * 
  * 

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Tue 19 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-05-19  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
'''

__author__ = "Lucas, FUEYO"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas FUEYO"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json, urllib3, urllib

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
urllib3.disable_warnings()


## Declare Functions ######################################################################################################
# Build a custom URL for Clearpass to get a valid Token
def get_token(clearpass_host, client_id, client_name, client_password):
		try:	
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

		except Exception as e:
				print("Error calling \"get_token\"... Exception {} --- Verify login, passwd or clientID !".format(e))
				sys.exit(3)

# Build a custom URL for Clearpass to get the file backup server informations
def get_autoupdates(clearpass_host, access_token):
		try:

  			# Create correct url to request
  			request_url = str("https://" + clearpass_host + ":443/api/cluster/parameters")

  			# Request the URL and return the syslog_target list
  			https = urllib3.PoolManager(cert_reqs='NONE')
  			r = https.request('GET', request_url,
     		headers={'Accept': 'application/json',
     		'Authorization': 'Bearer '+ access_token})

  			result = json.loads(r.data)
  			return result

		except Exception as e:
				print("Error calling \"get_autoupdates\"... Exception {}".format(e))
				sys.exit(3)

# Format the output for RGM
def rgm_autoupdates_output(clearpass_host, client_id, client_name, client_password):
		try:

				retcode = 3
				outtext = []
				outparams = []

				# Get authentication token
				access_token = get_token(clearpass_host, client_id, client_name, client_password)

				# Get cluster wide parameters 
				cluster_parameters = get_autoupdates(clearpass_host, access_token)

				# Check if syslog list is empty
				if not cluster_parameters:
					retcode = 3
					print("No cluster parameters found for host " + clearpass_host)
					sys.exit(retcode)
				
				# Check for each auto updates parameter
				if cluster_parameters['OnGuardAutoUpdatesFlag'] == 'TRUE':
					server_status = 0
				else:
					server_status = 2
					retcode = 2

				outparams.append("\n Status : {status} - Parameter : OnGuardAutoUpdatesFlag - Value : {value}".format(
					status=NagiosRetCode[server_status],
					value=cluster_parameters['OnGuardAutoUpdatesFlag']))

				if cluster_parameters['ProfilingAutoUpdatesFlag'] == 'TRUE':
					server_status = 0
				else:
					server_status = 2
					retcode = 2

				outparams.append("\n Status : {status} - Parameter : ProfilingAutoUpdatesFlag - Value : {value}".format(
					status=NagiosRetCode[server_status],
					value=cluster_parameters['ProfilingAutoUpdatesFlag']))

				if cluster_parameters['SoftwareAutoUpdatesFlag'] == 'TRUE':
					server_status = 0
				else:
					server_status = 2
					retcode = 2

				outparams.append("\n Status : {status} - Parameter : SoftwareAutoUpdatesFlag - Value : {value}".format(
					status=NagiosRetCode[server_status],
					value=cluster_parameters['SoftwareAutoUpdatesFlag']))

				outtext.append("Global auto updates parameters")

				print("{}: {} {}".format(
				NagiosRetCode[retcode],
    			" ".join(outtext),
    			" ".join(outparams)
				))

				exit(retcode)

		except Exception as e:
			print("Error calling \"rgm_autoupdates_output\"... Exception --- {}".format(e))
			sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

		parser = argparse.ArgumentParser(description="""
				Nagios plugin used to check cluster wide auto updates parameters of a Clearpass Appliance.
				""",
				usage="""
        Check cluster wide auto updates parameters of a Clearpass Appliance.

				python check_clearpass_API_autoupdates.py -H clearpass1 -u user -i clientID -p password
				
				example : python check_clearpass_API_autoupdates.py -H clearpass1 -u rgm -i rgmID -p rgmpass
				
				""",
				epilog="version {}, copyright {}".format(__version__, __copyright__))
		parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
		parser.add_argument('-u', '--user', type=str, help='Clearpass API User', required=True)
		parser.add_argument('-i', '--clientID', type=str, help='Clearpass API clientID', required=True)
		parser.add_argument('-p', '--password', type=str, help='Clearpass API password', required=True)
		#parser.add_argument('-l', '--list', type=str, help='list all services')
		#parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
		args = parser.parse_args()	
				
		rgm_autoupdates_output(args.hostname, args.user, args.clientID, args.password)

#EOF
