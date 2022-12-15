#!/usr/bin/python3

import argparse
import requests
import sys
from NagiosClasses import NagiosDisplay, print_error

parser = argparse.ArgumentParser(
    description='Check Node memory and return usage in %')
parser.add_argument('-p', '--prometheus', help='Prometheus base API URL', type=str,
    default='http://localhost:9090/prometheus/api'
)
parser.add_argument('-w', '--warning',
                    help='warning threshold in %', type=int, default=80)
parser.add_argument('-c', '--critical',
                    help='critical threshold in %', type=int, default=90)
parser.add_argument('-H', '--hostname',
                    help='hostname of instance to check ', type=str, required=True)
parser.add_argument('-v', '--verbose', action='store_true', help='enable verbose mode')
args = parser.parse_args()

url = args.prometheus + '/v1/query?query=(1-node_memory_MemAvailable_bytes{instance=~".*'+ args.hostname + '.*"}/node_memory_MemTotal_bytes{instance=~".*' + args.hostname + '.*"})*100'
if args.verbose: print("[*] Requesting to url: " + url, file=sys.stderr)

response = requests.get(url)

if args.verbose: print("[*] Parsing to JSON", file=sys.stderr)
result = response.json()
if args.verbose: print(response.json(), file=sys.stderr)

if result['status'] == "success":
    data_result = result['data']['result']
    if len(data_result) > 0:
        memory_usage = int(float(data_result[0]['value'][1]))
    else:
        print_error("Prometheus request return an empty result")

    nag = NagiosDisplay(memory_usage_pct={
        'warning': args.warning, 'critical': args.critical, 'value': memory_usage})
    nag.print_message("memory is used at {} %".format(memory_usage))
    exit(nag.return_code)
    
else:
    print_error("Prometheus request sent status error")
