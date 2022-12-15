#!/usr/bin/python3

import requests
import argparse
import sys
from NagiosClasses import print_error

"""
if no uptime CRITICAL - host is down
if respond -> print OK + pretty uptime
"""

def pretty_time_delta(seconds):
    seconds = int(seconds)
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes, seconds = divmod(seconds, 60)
    if days > 0:
        return '%dd%dh%dm%ds' % (days, hours, minutes, seconds)
    elif hours > 0:
        return '%dh%dm%ds' % (hours, minutes, seconds)
    elif minutes > 0:
        return '%dm%ds' % (minutes, seconds)
    else:
        return '%ds' % (seconds,)

parser = argparse.ArgumentParser(
    description='Check Node uptime')
parser.add_argument('-p', '--prometheus', help='Prometheus base API URL', type=str,
    default='http://localhost:9090/prometheus/api'
)
parser.add_argument('-H', '--hostname',
                    help='hostname of instance to check ', type=str, required=True)
parser.add_argument('-v', '--verbose', action='store_true', help='enable verbose mode')
parser.add_argument(
        '-i', '--interval', type=float,
        help='Interval of acceptance to be unseen - default to 6min',
        default=360
    )
args = parser.parse_args()

url = args.prometheus + '/v1/query?query=time()-node_boot_time_seconds{instance=~".*' + \
    args.hostname + '.*"}'
response = requests.get(url)

if args.verbose: print("[*] Parsing to JSON", file=sys.stderr)
result = response.json()
if args.verbose: print(response.json(), file=sys.stderr)

if result['status'] == "success":
    data_result = result['data']['result']
    if len(data_result) > 0:
        uptime_seconds = float(data_result[0]['value'][1])
    else:
        print("CRITICAL: Prometheus request return an empty result")
        sys.exit(2)

    print("OK - uptime: " + pretty_time_delta(uptime_seconds))
else:
    print_error("Prometheus request sent status error")