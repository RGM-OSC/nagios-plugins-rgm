#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return container uptime from Prometheus.
  * Uptime values are pushed from node-exporter and cadvisor installed on the monitored container environment.
  * Uptime request is handled by API REST againt Prometheus.

  AUTHOR :
  * Lucas Fueyo <lfueyo@fr.scc.com>   START DATE :    Mar 17 15:00:00 2020

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

# MODULES FEATURES ####################################################################################################

# Import the following modules:
import sys
import argparse
import requests
import urllib
import time
from datetime import datetime, timedelta
from dateutil import relativedelta

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# Declare Functions ###################################################################################################


# Build a custom URL for Prometheus (Here: HTTP uri for getting Start time value)
def get_custom_api_url(prometheus_host, container_name, interval_start):

    # Check interval value and deduce step and interval_end from it
    if isinstance(interval_start, int):
        interval_end = int(time.time())
        step = str(interval_end - interval_start)
    else:
        print("Error - the starting date is not a timestamp in seconds")
        sys.exit(3)

    prometheus_query = urllib.parse.quote("container_start_time_seconds{name=~\"" + container_name + "\"}")

    # Create object to return
    request_url = str(
        prometheus_host + "/api/v1/query_range?query=" + prometheus_query + "&start=" +
        str(interval_start) + "&end=" + str(interval_end) + "&step=" + step
    )

    return request_url


# Request a custom Prometheus API Rest Call (Here : Get Container start time)
def get_uptime(prometheus_host, container_name, interval_start, verbose):

    try:
        # Get the request url
        request_url = get_custom_api_url(prometheus_host, container_name, interval_start)

        # Request the Prometheus API
        results = requests.get(url=request_url)
        results_json = results.json()

        if verbose:
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print("JSON output: {}".format(results_json))
            print("####################################################################################")

        # Check if json contains values
        if results_json['data']['result']:
            # Get the last metric available and deduce uptime from it
            start_time = int(results_json['data']['result'][-1]['values'][-1][1])
            uptime = int(time.time()) - start_time

        else:
            uptime = -1

        return uptime

    except Exception as e:
        print("Error calling \"get_uptime\"... Exception {}".format(e))
        sys.exit(3)


# Display CPU usage in a format compliant with RGM expectations
def rgm_uptime_output(prometheus_host, container_name, interval_start, warning_threshold, critical_threshold, verbose):

    try:

        retcode = 3
        upstr = []

        # Get uptime value
        uptime = int(get_uptime(prometheus_host, container_name, interval_start, verbose))

        # Convert Thresholds from minutes to seconds
        warning_threshold = 60 * int(warning_threshold)
        critical_threshold = 60 * int(critical_threshold)

        # Format relative uptime to get values
        now = datetime.now()
        start = now - timedelta(seconds=uptime)
        rel = relativedelta.relativedelta(now, start)

        if uptime == -1:
            print("UNKNOWN: Uptime has not been returned...")
            sys.exit(retcode)
        elif uptime > 0:
                # Format relative uptime to get values
                now = datetime.now()
                start = now - timedelta(seconds=uptime)
                rel = relativedelta.relativedelta(now, start)

                upstr.append('Device up since ')
                if rel.years > 0:
                    upstr.append("{} years,".format(str(rel.years)))
                if rel.months > 0:
                    upstr.append("{} months,".format(str(rel.months)))
                if rel.days > 0:
                    upstr.append("{} days,".format(str(rel.days)))
                if rel.hours > 0:
                    upstr.append("{} hours,".format(str(rel.hours)))
                if rel.minutes > 0:
                    upstr.append("{} minutes,".format(str(rel.minutes)))
                if rel.seconds > 0:
                    upstr.append("{} seconds,".format(str(rel.seconds)))
                if uptime <= warning_threshold:
                    retcode = 1
                if uptime <= critical_threshold:
                    retcode = 2
                else:
                    retcode = 0

        print("{rc} - {results} | 'uptime': {uptime}s".format(
                rc=NagiosRetCode[retcode],
                results=" ".join(upstr),
                uptime=str(uptime)))
        exit(retcode)

    except Exception as e:
        print("Error calling \"rgm_uptime_output\"... Exception {}".format(e))
        sys.exit(3)


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="""
        * Nagios plugin used to return container Uptime from Prometheus.
        * Uptime values are pushed from node-exporter and cadvisor installed on the monitored container environment.
        * Uptime request is handled by API REST againt Prometheus.
        """,
        usage="""
        Get Uptime for container "ct1"

        Warning alert if Uptime < 10 minutes.
        Critical alert if Uptime < 5 minutes.

        python check_container_uptime.py -H ct1 -w 10 -c 5

        Get Uptime for container "ct1" with Verbose mode enabled.

        python check_container_uptime.py -H ct1 -w 10 -c 5 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument('-H', '--hostname', type=str, help='container hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger threshold', default='10')
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger threshold', default='5')
    parser.add_argument(
        '-i', '--intervalstart', type=int,
        help='timestamp value in seconds to start the Uptime check - default to 6min',
        default=int(time.time())-360
    )
    parser.add_argument(
        '-E', '--prometheushost', type=str,
        help='connection URL of Prometheus server', default="http://localhost:9090"
    )
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    rgm_uptime_output(args.prometheushost, args.hostname, args.intervalstart, args.warning, args.critical, args.verbose)
