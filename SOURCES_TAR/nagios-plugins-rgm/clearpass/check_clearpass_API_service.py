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
				print("Error calling \"get_token\"... Exception {} --- Verify login, mdp or clientID !".format(e))
				sys.exit(3)

# Build a custom URL for Clearpass to get the uuid server
def get_server_uuid(clearpass_host, access_token):
		try:
  			# Create correct url to request
  			request_url = str("https://" + clearpass_host + ":443/api/cluster/server")

  			# Request the URL and extract the uuid server
  			https = urllib3.PoolManager(cert_reqs='NONE')
  			r = https.request('GET', request_url,
     		headers={'Accept': 'application/json',
     		'Authorization': 'Bearer '+ access_token})

  			result = json.loads(r.data)
  			return result['_embedded']['items'][0]['server_uuid']

		except Exception as e:
				print("Error calling \"get_server_uuid\"... Exception {}".format(e))
				sys.exit(3)

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
			print("Error calling \"get_service_status\"... Exception --- Verify service name ! {}".format(e))
			sys.exit(3)


# Build a custom URL for Clearpass to get all services status
def get_all_services_status(clearpass_host, clearpass_service, client_id, client_name, client_password):
    try:

				retcode = 3

				# Get authentication token
				access_token = get_token(clearpass_host, client_id, client_name, client_password)

				# Get server uuid
				server_uuid = get_server_uuid(clearpass_host, access_token)

				# Create correct url to request
				request_url = str("https://" + clearpass_host + ":443/api/server/service/" + server_uuid)

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
			print("Error calling \"get_all_services_status\"... Exception {}".format(e))
			sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

		parser = argparse.ArgumentParser(description="""
				Nagios plugin used to return machine "Service Status" from Clearpass Appliance.
				Service Name is defined as an argument to have his status.
				""",
				usage="""
        Get service status of "clearpass1" Cleearpass Server --> Have Critical alert if service is stopped or failed !

				python check_clearpass_api.py -H clearpass1 -n service_name -u user -c clientID -p password
				
				example : python check_clearpass_api.py -H clearpass1 -n cpass-radius-server.service -u rgm -c rgmID -p rgmpass
				
				list of Clearpass services : 
				- ClearPass RADIUS server --> "cpass-radius-server.service"
				- ClearPass IPsec service --> "strongswan.service"
				- AirGroup notification service --> "airgroup-workqueue"
				- Stats aggregation service --> "cpass-carbon-server.service"
				- Async network services --> "cpass-async-netd.service"
				- DB change notification server --> "cpass-dbcn-daemon.service"
				- Async DB write service --> "cpass-fdb.service"
				- ClearPass Policy server --> "cpass-policy-server.service"
				- Ingress logger service --> "cpass-igslogger.service"
				- Data cache for Guest and Onboard --> "cpg-redis-cache"
				- ClearPass Extensions service --> "docker"
				- ClearPass TACACS server --> "cpass-tacacs-server.service"
				- DB replication service --> "cpass-londiste.service"
				- Multi-Master cache --> "battery.service"
				- RadSec service --> "cpass-radsec"
				- Stats collection service --> "cpass-statsd-server.service"
				- Micros Fidelio FIAS --> "fias-server"
				- System auxiliary services --> "backend-tomcat.service"
				- System monitor service --> "cpass-sysmon.service"
				- Ingress logrepo service --> "cpass-igslogrepo.service"
				- Virtual IP service --> "cpass-vip.service"
				- Guest Background Service --> "cpg-background"
				""",
				epilog="version {}, copyright {}".format(__version__, __copyright__))
		parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
		parser.add_argument('-n', '--service', type=str, help='Clearpass service name', required=True)
		parser.add_argument('-u', '--user', type=str, help='Clearpass API User', required=True)
		parser.add_argument('-c', '--clientID', type=str, help='Clearpass API clientID', required=True)
		parser.add_argument('-p', '--password', type=str, help='Clearpass API password', required=True)
		#parser.add_argument('-l', '--list', type=str, help='list all services')
		#parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
		args = parser.parse_args()	
				
		#if validate_elastichost(args.elastichost):
		get_service_status(args.hostname, args.service, args.user, args.clientID, args.password)

#EOF
