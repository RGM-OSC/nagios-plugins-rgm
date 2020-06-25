#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return container Memory usage from Prometheus.
  * Memory values are pushed from node-exporter and cadvisor installed on the monitored container environment.
  * Memory usage request is handled by API REST againt Prometheus.

  AUTHOR :
  * Lucas Fueyo <lfueyo@fr.scc.com>   START DATE :    Mar 16 15:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-03-17  Lucas Fueyo <lfueyo@fr.scc.com>             Initial version
'''

__author__ = "Lucas Fueyo"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas Fueyo"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas Fueyo"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json, urllib3, urllib, time
from ast import literal_eval

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

## Declare Functions ######################################################################################################

# Build a custom URL for Prometheus (Here: HTTP uri for getting Memory usage values)
def get_custom_api_url(prometheus_host, container_image, container_label, interval_start):

	# Check interval value and deduce step and interval_end from it
	if isinstance(interval_start, int):
		interval_end = int(time.time())
		step = str(interval_end - interval_start)
	else:
		print("Error - the starting date is not a timestamp in seconds")
		sys.exit(3)

	mem_used_query = urllib.quote("container_memory_usage_bytes{" + container_label + "=~\".*" + container_image + ".*\"}")
	#mem_limit_query = urllib.quote("container_spec_memory_limit_bytes{image=~\".*" + container_image + ".*\"}") 

	swap_used_query = urllib.quote("container_memory_swap{" + container_label + "=~\".*" + container_image + ".*\"}")
	#swap_limit_query = urllib.quote("container_spec_memory_swap_limit_bytes{image=~\".*" + container_image + ".*\"}")

	# Create objects to return
	mem_used_url = str(prometheus_host + "/api/v1/query_range?query=" + mem_used_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)
	#mem_limit_url = str(prometheus_host + "/api/v1/query_range?query=" + mem_limit_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)
	
	swap_used_url = str(prometheus_host + "/api/v1/query_range?query=" + swap_used_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)
	#swap_limit_url = str(prometheus_host + "/api/v1/query_range?query=" + swap_limit_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)

	urls = {}
	urls['mem_used'] = mem_used_url
	#urls['mem_limit'] = mem_limit_url
	urls['swap_used'] = swap_used_url
	#urls['swap_limit'] = swap_limit_url

	return urls

# Request a custom Prometheus API Rest Call (Here : Get Memory : Used, Limit, Swap Used, Swap Limit)
def get_memory(prometheus_host, container_image, container_label, interval_start, verbose):

	try:
		# Get the request urls
		urls = get_custom_api_url(prometheus_host, container_image, container_label, interval_start)

		#Loop on the URLs and store the resulting value in a dictionary
		results = {}

		for key, value in urls.items():
			# Request the Prometheus API
			response = requests.get(url=value)
			response_json = response.json()

			if verbose:
				print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
				print("Object Type : " + key)
				print("JSON output: {}".format(response_json))
				print("####################################################################################")

			# Check if json contains values
			if response_json['data']['result']:
		
				# Get the last metric available 
				results[key] = float(response_json['data']['result'][-1]['values'][-1][1])

			else:
				results[key] = -1

		return results

	except Exception as e:
		print("Error calling \"get_memory\"... Exception {}".format(e))
		sys.exit(3)

# Convert Bytes in MegaBytes :
def convert_bytes(prometheus_host, container_image, container_label, interval_start, verbose):
	try:
		results = get_memory(prometheus_host, container_image, container_label, interval_start, verbose)

		for key, value in results.items():
			# If Memory has been returned in API Response, return converted values:
			if results[key] != -1 :
				results[key] = (value/(1024*1024))

		return results
	except Exception as e:
		print("Error calling \"convert_bytes\"... Exception {}".format(e))
		sys.exit(3)

# Display Memory usage in a format compliant with RGM expectations
def rgm_memory_output(prometheus_host, container_image, container_label, interval_start, warning_threshold, critical_threshold, verbose):

	try:
		
		retcode = 3
		# Get Memory usage value
		results = convert_bytes(prometheus_host, container_image, container_label, interval_start, verbose)

		if results['mem_used'] == -1:
			print("UNKNOWN: Memory used has not been returned...")
			sys.exit(retcode)
		elif results['swap_used'] == -1:
			print("UNKNOWN: Swap used has not been returned...")
			sys.exit(retcode)
		elif results['mem_used'] >= critical_threshold[0] or results['swap_used'] >= critical_threshold[1]:
			retcode = 2
		elif results['mem_used'] >= warning_threshold[0] or results['swap_used'] >= warning_threshold[1]:
			retcode = 1
		elif results['mem_used'] < warning_threshold[0] and results['swap_used'] < warning_threshold[1]:
			retcode = 0

		print("{rc} - Memory Usage : {mmem}MB ," \
				" Swap Usage : {mswp}MB |" \
				" Memory={mmem};{mwt};{mct};0;100 Swap={mswp};{swt};{sct};0;100".format(
				rc=NagiosRetCode[retcode],
				mmem=str(round(results['mem_used'],2)),
				mswp=str(round(results['swap_used'],2)),
				mwt=warning_threshold[0],
				mct=critical_threshold[0],
				swt=warning_threshold[1],
				sct=critical_threshold[1]))
		exit(retcode)

	except Exception as e:
		print("Error calling \"rgm_memory_output\"... Exception {}".format(e))
		sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

	parser = argparse.ArgumentParser(description="""
	* Nagios plugin used to return container Memory usage from Prometheus.
	* Memory values are pushed from node-exporter and cadvisor installed on the monitored container environment.
	* Memory request is handled by API REST againt Prometheus.
	""",
	usage="""
	Get Memory usage for container deployed from image "image-front" from timestamp to now

	python check_container_memory.py -H ct1

	Get Memory for container deployed from image "image-front" with Verbose mode enabled.

	python check_container_memory.py -H ct1 -v

    Get Memory for container matching label 'monitoring = mySpecificAppContainer'

    python check_container_cpu.py -H mySpecificAppContainer -l monitoring 

	Critical and Warning threshold alerts are implemented in MB threshold and not percent from lack of max memory values
	""",
	epilog="version {}, copyright {}".format(__version__, __copyright__))

	parser.add_argument('-H', '--hostname', type=str, help='container hostname or IP address', required=True)
	parser.add_argument('-l', '--label', type=str, help='Container label name', default='image')
	parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger threshold (physical,swap)', default='1024,256')
	parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger threshold (physical,swap)', default='2048,512')
	parser.add_argument('-i', '--intervalstart', type=int, help='timestamp value in seconds to start the memory usage check - default to 1min', default=int(time.time())-60)
	parser.add_argument('-E', '--prometheushost', type=str, help='connection URL of Prometheus server', default="http://localhost:9090")
	parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

	args = parser.parse_args()

	warn = literal_eval(args.warning)
	critical = literal_eval(args.critical)
	if not isinstance(warn, tuple) or not isinstance(critical, tuple):
		parser.print_help()
		exit(3)

	rgm_memory_output(args.prometheushost, args.hostname, args.label, args.intervalstart, warn, critical, args.verbose)

#EOF
