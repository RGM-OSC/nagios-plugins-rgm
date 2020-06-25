#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return container Disk usage from Prometheus.
  * Disk values are pushed from node-exporter and cadvisor installed on the monitored container environment.
  * Disk usage request is handled by API REST againt Prometheus.

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

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

## Declare Functions ######################################################################################################

# Build a custom URL for Prometheus (Here: HTTP uri for getting Disk usage values)
def get_custom_api_url(prometheus_host, container_name, interval_start):

	# Check interval value and deduce step and interval_end from it
	if isinstance(interval_start, int):
		interval_end = int(time.time())
		step = str(interval_end - interval_start)
	else:
		print("Error - the starting date is not a timestamp in seconds")
		sys.exit(3)

	disk_used_query = urllib.quote("container_fs_usage_bytes{name=~\"" + container_name + "\"}")
	disk_limit_query = urllib.quote("container_fs_limit_bytes{name=~\"" + container_name + "\"}") 

	# Create objects to return
	disk_used_url = str(prometheus_host + "/api/v1/query_range?query=" + disk_used_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)
	disk_limit_url = str(prometheus_host + "/api/v1/query_range?query=" + disk_limit_query + "&start=" + str(interval_start) + "&end=" + str(interval_end) + "&step=" + step)

	urls = {}
	urls['disk_used'] = disk_used_url
	urls['disk_limit'] = disk_limit_url

	return urls

# Request a custom Prometheus API Rest Call (Here : Get Memory : Used, Limit, Swap Used, Swap Limit)
def get_disk(prometheus_host, container_name, interval_start, verbose):

	try:
		# Get the request urls
		urls = get_custom_api_url(prometheus_host, container_name, interval_start)

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
				results[key] = {}	
				# Loop on each disk and get values
				for i in response_json['data']['result']: 
					device = i['metric']['device']
					results[key][device] = float(i['values'][-1][1])

			else:
				results[key] = -1

		return results

	except Exception as e:
		print("Error calling \"get_disk\"... Exception {}".format(e))
		sys.exit(3)

# Return Human Readable size with suffix from Bytes size
def humanreadable_size(num, suffix='B'):
	for unit in ['','K','M','G','T']:
		if abs(num) < 1024.0:
			return "%3.1f%s%s" % (num, unit, suffix)
		num /= 1024.0

# Get pct values and convert Bytes in Human Readable :
def convert_bytes(prometheus_host, container_name, interval_start, warning_threshold, critical_threshold, verbose):
	try:
		results = get_disk(prometheus_host, container_name, interval_start, verbose)

		human_readable_results = []

		if results['disk_limit'] == -1:
			raise e('No disk limit found.')
		elif results['disk_used'] == -1:
			raise e('No disk usage found.')
		else:
			for device, value in results['disk_used'].items():
				device_results = {}
				device_results['used_space'] = humanreadable_size(value)
				device_results['used_pct'] = str(round(float(value / float(results['disk_limit'][device]) * 100),2))
				device_results['free_space'] = humanreadable_size(float(results['disk_limit'][device]) - float(value))
				device_results['total_space'] = humanreadable_size(results['disk_limit'][device])
				device_results['device'] = device

				if device_results['used_pct'] >= critical_threshold:
					device_results['nagios_status'] = 2
				elif device_results['used_pct'] >= warning_threshold:
					device_results['nagios_status'] = 1
				elif device_results['used_pct'] < warning_threshold:
					device_results['nagios_status'] = 0

				human_readable_results.append(device_results)

		return human_readable_results

	except Exception as e:
		print("Error calling \"convert_bytes\"... Exception {}".format(e))
		sys.exit(3)

# Display Disk usage in a format compliant with RGM expectations
def rgm_disk_output(prometheus_host, container_name, interval_start, warning_threshold, critical_threshold, verbose):

	try:
		
		retcode = 3
		# Get Disk usage values
		results = convert_bytes(prometheus_host, container_name, interval_start, warning_threshold, critical_threshold, verbose)

		outtext = []
		outperf = []
		nagios_status = max(results, key=lambda status: status['nagios_status'])['nagios_status']

		if nagios_status != 0:
			crit = [ i['device'] for i in results if i['nagios_status'] == 2 ]
			if len(crit) > 0:
				outtext.append("{} devices in CRITICAL state ({}%): {}".format(
						str(len(crit)),
						str(critical_threshold),
						", ".join(crit)))

			warn = [ i['device'] for i in results if i['nagios_status'] == 1 ]
			if len(warn) > 0:
				outtext.append("{} devices in WARNING state ({}%): {}".format(
						str(len(warn)),
						str(warning_threshold),
						", ".join(warn)))

		else:
			outtext.append("All devices in OK state ({}%, {}%)".format(int(warning_threshold), int(critical_threshold)))

		for item in results:
			outperf.append("'{label}' - Disk Usage : {used_space} ," \
					" Free Space : {free} | " \
					"'{label}'={used_pct};{warn};{crit};0;{total}".format(
					label=item['device'],
					used_space=str(item['used_space']),
					free=str(item['free_space']),
					used_pct=str(item['used_pct']),
					warn=str(warning_threshold),
					crit=str(critical_threshold),
					total=str(item['total_space'])))
						
		print("{}: {} | {}".format(
		NagiosRetCode[nagios_status],
		" ".join(outtext),
		" ".join(outperf)
		))
		sys.exit(nagios_status)

	except Exception as e:
		print("Error calling \"rgm_disk_output\"... Exception {}".format(e))
		sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

	parser = argparse.ArgumentParser(description="""
	* Nagios plugin used to return container Disk usage from Prometheus.
	* Disk values are pushed from node-exporter and cadvisor installed on the monitored container environment.
	* DIsk request is handled by API REST againt Prometheus.
	""",
	usage="""
	Get Disk usage for container "ct1" from timestamp to now

	python check_container_disk.py -H ct1

	Get Disk for container "ct1" with Verbose mode enabled.

	python check_container_disk.py -H ct1 -v

	""",
	epilog="version {}, copyright {}".format(__version__, __copyright__))

	parser.add_argument('-H', '--hostname', type=str, help='container hostname or IP address', required=True)
	parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger threshold', default='85')
	parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger threshold', default='90')
	parser.add_argument('-i', '--intervalstart', type=int, help='timestamp value in seconds to start the disk usage check - default to 6min', default=int(time.time())-360)
	parser.add_argument('-E', '--prometheushost', type=str, help='connection URL of Prometheus server', default="http://localhost:9090")
	parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

	args = parser.parse_args()

	rgm_disk_output(args.prometheushost, args.hostname, args.intervalstart, args.warning, args.critical, args.verbose)

#EOF
