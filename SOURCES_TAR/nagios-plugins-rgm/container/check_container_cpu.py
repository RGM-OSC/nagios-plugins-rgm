#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return container CPU usage from Prometheus.
  * CPU values are pushed from node-exporter and cadvisor installed on the monitored container environment.
  * CPU usage request is handled by API REST againt Prometheus.

  AUTHOR :
  * Lucas Fueyo <lfueyo@fr.scc.com>   START DATE :    Mar 16 15:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-03-16  Lucas Fueyo <lfueyo@fr.scc.com>             Initial version
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

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# Declare Functions ###################################################################################################


# Build a custom URL for Prometheus (Here: HTTP uri for getting CPU usage values)
def get_custom_api_url(prometheus_host, container_image, container_label, interval_start):

    # Check interval value and deduce step and interval_end from it
    if isinstance(interval_start, int):
        interval_end = int(time.time())
        step = str(interval_end - interval_start)
    else:
        print("Error - the starting date is not a timestamp in seconds")
        sys.exit(3)

    prometheus_query = urllib.parse.quote(
        "sum(rate(container_cpu_usage_seconds_total{" + container_label + "=~\".*" +
        container_image + ".*\"}[" + step + "s]))*100"
    )

    # Create object to return
    request_url = str(
        prometheus_host + "/api/v1/query_range?query=" + prometheus_query + "&start=" +
        str(interval_start) + "&end=" + str(interval_end) + "&step=" + step
    )

    return request_url


# Request a custom Prometheus API Rest Call (Here : Get CPU : Used)
def get_cpu(prometheus_host, container_image, container_label, interval_start, verbose):

    try:
        # Get the request url
        request_url = get_custom_api_url(prometheus_host, container_image, container_label, interval_start)

        # Request the Prometheus API
        results = requests.get(url=request_url)
        results_json = results.json()

        if verbose:
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print("JSON output: {}".format(results_json))
            print("####################################################################################")

        # Check if json contains values
        if results_json['data']['result']:

            # Get the last metric available
            cpu_used_pct = float(results_json['data']['result'][-1]['values'][-1][1])

        else:
            cpu_used_pct = -1

        return cpu_used_pct

    except Exception as e:
        print("Error calling \"get_cpu\"... Exception {}".format(e))
        sys.exit(3)


# Display CPU usage in a format compliant with RGM expectations
def rgm_cpu_output(
    prometheus_host, container_image, container_label, interval_start, warning_threshold, critical_threshold, verbose
):

    try:

        retcode = 3
        # Get CPU usage value
        cpu_used_pct = get_cpu(prometheus_host, container_image, container_label, interval_start, verbose)

        if cpu_used_pct == -1:
            print("UNKNOWN: CPU has not been returned...")
            sys.exit(retcode)
        elif cpu_used_pct >= critical_threshold:
            retcode = 2
        elif cpu_used_pct >= warning_threshold:
            retcode = 1
        elif cpu_used_pct < warning_threshold:
            retcode = 0

        print(
            "{rc} - CPU Usage : {cpu}% |"
            " CPU={cpu};{wt};{ct};0;100".format(
                rc=NagiosRetCode[retcode],
                cpu=str(round(cpu_used_pct, 2)),
                wt=warning_threshold,
                ct=critical_threshold
            )
        )
        exit(retcode)

    except Exception as e:
        print("Error calling \"rgm_cpu_output\"... Exception {}".format(e))
        sys.exit(3)


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="""
        * Nagios plugin used to return container CPU usage from Prometheus.
        * CPU values are pushed from node-exporter and cadvisor installed on the monitored container environment.
        * CPU request is handled by API REST againt Prometheus.
        """,
        usage="""
        Get CPU usage for container "ct1" from timestamp (default 1min) to now

        Warning alert if CPU > 80%%.
        Critical alert if CPU > 95%%.

        python check_container_cpu.py -H 'image-front' -w 80 -c 95

        Get CPU for container deployed from image "image-front" with Verbose mode enabled.

        python check_container_cpu.py -H 'image-front' -w 85 -c 95 -v

        Get CPU for container matching label 'monitoring = mySpecificAppContainer'

        python check_container_cpu.py -H mySpecificAppContainer -l monitoring
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument('-H', '--hostname', type=str, help='Container image name', required=True)
    parser.add_argument('-l', '--label', type=str, help='Container label name', default='image')
    parser.add_argument('-w', '--warning', type=int, help='warning trigger threshold', default='80')
    parser.add_argument('-c', '--critical', type=int, help='critical trigger threshold', default='95')
    parser.add_argument(
        '-i', '--intervalstart', type=int,
        help='timestamp value in seconds to start the CPU usage check - default to 6min',
        default=int(time.time())-60
    )
    parser.add_argument(
        '-E', '--prometheushost', type=str, help='connection URL of Prometheus server',
        default="http://localhost:9090"
    )
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()
    rgm_cpu_output(
        args.prometheushost,
        args.hostname,
        args.label,
        args.intervalstart,
        args.warning,
        args.critical,
        args.verbose
    )
