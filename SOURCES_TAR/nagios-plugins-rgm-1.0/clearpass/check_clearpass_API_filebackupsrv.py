#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to check connectivity to a clearpass file backup server if defined.
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
import sys, re, argparse, requests, json, urllib3, urllib, socket

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
urllib3.disable_warnings()


## Declare Functions ######################################################################################################
# Check connectivity to a host port by opening a socket connection
def check_connectivity(host_address, server_port):

	sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	result = sock.connect_ex((host_address,server_port))
	if result == 0:
		sock.close()
		return True
	else:
		sock.close()
		return False

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

# Build a custom URL for Clearpass to get the file backup server informations
def get_filebackupsrv(clearpass_host, access_token):
		try:

  			# Create correct url to request
  			request_url = str("https://" + clearpass_host + ":443/api/file-backup-server?filter=%7B%7D&sort=%2Bid&offset=0&limit=25&calculate_count=false")

  			# Request the URL and return the syslog_target list
  			https = urllib3.PoolManager(cert_reqs='NONE')
  			r = https.request('GET', request_url,
     		headers={'Accept': 'application/json',
     		'Authorization': 'Bearer '+ access_token})

  			result = json.loads(r.data)
  			return result['_embedded']['file_backup_server']

		except Exception as e:
				print("Error calling \"get_filebackupsrv\"... Exception {}".format(e))
				sys.exit(3)

# Format the output for RGM
def rgm_filebackupsrv_output(clearpass_host, client_id, client_name, client_password):
		try:

				retcode = 3
				outtext = []
				outservers = []

				# Get authentication token
				access_token = get_token(clearpass_host, client_id, client_name, client_password)

				# Get file backup servers 
				filebackupsrv_list = get_filebackupsrv(clearpass_host, access_token)

				# Check if syslog list is empty
				if not filebackupsrv_list:
					retcode = 0
					print("No file backup servers for host " + clearpass_host)
					sys.exit(retcode)
				else:
					
					outtext.append("{member_count} file backup servers for host {clearpass_host}".format(
						member_count=len(filebackupsrv_list),
						clearpass_host=clearpass_host))

					retcode = 0

					for server in filebackupsrv_list:

						# server_status is used to show the connectivity status of each server 
						server_status = 0

						if not check_connectivity(server['host_address'], server['port']):
							retcode = 2
							server_status = 2

						outservers.append("\n Status : {status} - Host : {host_address} - Port : {port}," \
						" Protocol : {protocol}," \
						" Description : {description}".format(
						status=NagiosRetCode[server_status],
						host_address=server['host_address'],
						port=server['port'],
						protocol=server['protocol'],
						description=server['description']))

					print("{}: {} {}".format(
					NagiosRetCode[retcode],
    				" ".join(outtext),
    				" ".join(outservers)
					))

					exit(retcode)

		except Exception as e:
			print("Error calling \"rgm_filebackupsrv_output\"... Exception --- {}".format(e))
			sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

		parser = argparse.ArgumentParser(description="""
				Nagios plugin used to check connectivity to a Clearpass file backup server if defined.
				""",
				usage="""
        Check connectivity with the file backup targets of a Clearpass Appliance. 

				python check_clearpass_API_filebackupsrv.py -H clearpass1 -u user -i clientID -p password
				
				example : python check_clearpass_API_filebackupsrv.py -H clearpass1 -u rgm -i rgmID -p rgmpass
				
				""",
				epilog="version {}, copyright {}".format(__version__, __copyright__))
		parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
		parser.add_argument('-u', '--user', type=str, help='Clearpass API User', required=True)
		parser.add_argument('-i', '--clientID', type=str, help='Clearpass API clientID', required=True)
		parser.add_argument('-p', '--password', type=str, help='Clearpass API password', required=True)
		#parser.add_argument('-l', '--list', type=str, help='list all services')
		#parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
		args = parser.parse_args()	
				
		rgm_filebackupsrv_output(args.hostname, args.user, args.clientID, args.password)

#EOF
