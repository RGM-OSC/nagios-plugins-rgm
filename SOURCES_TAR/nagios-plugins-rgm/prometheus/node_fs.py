#!/usr/bin/python3

import argparse
import requests
import sys
from NagiosClasses import NagiosDisplay, print_error, nagios_exit_codes
import pprint

parser = argparse.ArgumentParser(
    description='Check Node fs and return usage in %')
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
parser.add_argument('-m', '--mountpoint', help="Specify a mountpoint, if not specified, list all mountpoint", default=None)
args = parser.parse_args()

url = args.prometheus + '/v1/query?query=(1-node_filesystem_avail_bytes'
if args.mountpoint is not None:
    url = '{instance=~".*' + args.hostname + '.*",mountpoint="'+ args.mountpoint +'"}/node_filesystem_size_bytes)*100'
else:
    url = '{instance=~".*' + args.hostname + '.*"}/node_filesystem_size_bytes)*100'

if args.verbose: print("[*] Requesting to url: " + url, file=sys.stderr)

response = requests.get(url)

if args.verbose: print("[*] Parsing to JSON", file=sys.stderr)
result = response.json()
if args.verbose: print(response.json(), file=sys.stderr)

pp = pprint.PrettyPrinter(indent=4)

if result['status'] == "success":
    data_result = result['data']['result']
    if len(data_result) == 0:
        print_error("Prometheus request return an empty result")

    # loop on result
    fs_usages = dict() 
    for metric in data_result:
        mountpoint = metric['metric']['mountpoint']
        fs_usages[mountpoint] = float(metric['value'][1])

    nag = NagiosDisplay()
    nag.warning = args.warning
    nag.critical = args.critical
    nag.give_values(**fs_usages)
    # print(nagios_exit_codes[nag.return_code] + ": FileSystem are " + nagios_exit_codes[nag.return_code])
    # print(nag)
    nag.print_message("FileSystem are " + nagios_exit_codes[nag.return_code])
    exit(nag.return_code)
else:
    print_error("Prometheus request sent status error")
