#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return event logs from Clearpass Appliance.
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
				print("Error calling \"get_token\"... Exception {} --- Verify login, mdp or clientID !".format(e))
				sys.exit(3)

# Build a custom URL for Clearpass to get events
def get_events(clearpass_host, access_token, clearpass_severity, event_limit):
		try:

			# Select the correct filter to apply to the query
			if clearpass_severity == 'WARNING':
				url_filter = '{"level":"WARN"}'
			elif clearpass_severity == 'ERROR':
				url_filter = '{"level":"ERROR"}'
			elif clearpass_severity == 'DEFAULT':
				url_filter = '{"level":["WARN","ERROR"]}'

			# Encode the string to be used in the URL
			url_filter = urllib.quote(url_filter)

  			# Create correct url to request
  			request_url = str("https://" + clearpass_host + ":443/api/system-event?filter=" + url_filter + "&sort=%2Bsource&offset=0&limit=" + event_limit + "&calculate_count=false")

  			# Request the URL and return the event list
  			https = urllib3.PoolManager(cert_reqs='NONE')
  			r = https.request('GET', request_url,
     		headers={'Accept': 'application/json',
     		'Authorization': 'Bearer '+ access_token})

  			result = json.loads(r.data)
  			return result['_embedded']['items']

		except Exception as e:
				print("Error calling \"get_events\"... Exception {}".format(e))
				sys.exit(3)

# Manage events output for RGM 
def rgm_event_output(clearpass_host, clearpass_severity, client_id, client_name, client_password, critical_threshold, warning_threshold, event_limit):
		try:

				retcode = 3
				outtext = []
				outevents = []

				# Get authentication token
				access_token = get_token(clearpass_host, client_id, client_name, client_password)

				# Get events 
				event_list = get_events(clearpass_host, access_token, clearpass_severity, event_limit)

				# Check if event list is empty
				if not event_list:
					retcode = 0
					print("No events for host " + clearpass_host + " for severity " + clearpass_severity)
					sys.exit(retcode)

				if(len(event_list) >= int(critical_threshold)):
					retcode = 2
				elif(len(event_list) >= int(warning_threshold)):
					retcode = 1
				else:
					retcode = 0

				outtext.append("{event_count} Events in {severity} state".format(
					event_count=len(event_list),
					severity=clearpass_severity))

				for event in event_list:
					outevents.append("\n{category} - {timestamp}," \
					" level : {level} - action : {action}," \
					" Description : {description}".format(
					category=event['category'],
					timestamp=event['timestamp'],
					level=event['level'],
					action=event['action'],
					description=event['description']))

				print("{}: {} {}".format(
				NagiosRetCode[retcode],
    			" ".join(outtext),
    			" ".join(outevents)
				))

				exit(retcode)

		except Exception as e:
			print("Error calling \"rgm_event_output\"... Exception --- {}".format(e))
			sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

		parser = argparse.ArgumentParser(description="""
				Nagios plugin used to return events from a Clearpass Appliance.
				Event severity is defined as an argument to filter their status.
				""",
				usage="""
        Get events of "clearpass1" Clearpass Server --> Have Critical alert if event number is higher than the critical threshold defined !

				python check_clearpass_API_events.py -H clearpass1 -s severity -u user -i clientID -p password -c criticalThreshold -w warningThreshold
				
				example : python check_clearpass_API_events.py -H clearpass1 -s WARNING -u rgm -i rgmID -p rgmpass -c 10 -w 5
				
				""",
				epilog="version {}, copyright {}".format(__version__, __copyright__))
		parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
		parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger threshold', default='10')
		parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger threshold', default='20')
		parser.add_argument('-l', '--limit', type=str, help='Max events returned', default='25')
		parser.add_argument('-s', '--severity', type=str, help='Clearpass severity filter : WARNING | ERROR | DEFAULT', default='DEFAULT')
		parser.add_argument('-u', '--user', type=str, help='Clearpass API User', required=True)
		parser.add_argument('-i', '--clientID', type=str, help='Clearpass API clientID', required=True)
		parser.add_argument('-p', '--password', type=str, help='Clearpass API password', required=True)
		#parser.add_argument('-l', '--list', type=str, help='list all services')
		#parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
		args = parser.parse_args()	
				
		rgm_event_output(args.hostname, args.severity, args.user, args.clientID, args.password, args.critical, args.warning, args.limit)

#EOF
