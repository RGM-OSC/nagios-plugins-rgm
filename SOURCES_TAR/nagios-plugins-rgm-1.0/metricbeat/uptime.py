#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Uptime" from ElasticSearch.
  * Uptime is pushed from MetricBeat agent installed on the monitored machine.
  * Uptime resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Aug 30 10:00:00 2018 
              
CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2018-08-30  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
  * 1.0.1       2019-03-26  Eric Belhomme <ebelhomme@fr.scc.com>        replace getopts by argparse module
                                                                        code factorization & mutualization
                                                                        added elastichost variable
  * 1.0.2       2019-09-30  Eric Belhomme <ebelhomme@fr.scc.com>        fix argument type casting to int for warning, critical, timeout
'''

__author__ = "Julien Dumarchey, Eric Belhomme"
__copyright__ = "2018, SCC"
__credits__ = ["Julien Dumarchey", "Eric Belhomme"]
__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = "Julien Dumarchey"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost, seconds_to_duration

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting an Uptime value for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.uptime.duration.ms"
        metricset_module = "system"
        metricset_name = "uptime"
        ## Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(1)
        custom_payload = {}
        custom_payload.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_all":{}} )
        custom_payload["query"]["bool"]["must"].append( {"exists":{"field":""+field_name+""}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"event.module":{"query":""+metricset_module+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"host.name":{"query":""+beat_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        return custom_payload
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)

# Request a custom ElasticSearch API REST Call (here: Get an Uptime in millisecond):
def get_uptime(elastichost, plugin_hostname,data_validity,verbose):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call(elastichost)
        payload = custom_api_payload(plugin_hostname,data_validity)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        if verbose:
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print("request payload: {}".format(payload))
            print("JSON output: {}".format(results_json))
            print("####################################################################################")        # Extract the "Total Hit" from results (= check if an Uptime has been returned):
        total_hit = int(results_json["hits"]["total"]['value'])
        # If request hits: extract results (Uptime in ms) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        if total_hit != 0:
            uptime_ms = results_json["hits"]["hits"][0]["_source"]["system"]["uptime"]["duration"]["ms"]
        else:
            uptime_ms = 0
        return uptime_ms/1000
    except Exception as e:
        print("Error calling \"get_uptime\"... Exception {}".format(e))
        sys.exit(3)


# Display Uptime (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_uptime_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        rc = 3
        upstr = []
        # convert minutes into seconds
        warning_treshold = 60 * int(warning_treshold)
        critical_treshold = 60 * int(critical_treshold)
        # Get Uptime values:
        uptime = int(get_uptime(elastichost, plugin_hostname, data_validity, verbose))
        if uptime > 0:
            years, months, days, hours, minutes, seconds = seconds_to_duration(uptime)
            upstr.append('Device up since')
            if years > 0:
                upstr.append("{} years,".format(str(years)))
            if months > 0:
                upstr.append("{} months,".format(str(months)))
            if days > 0:
                upstr.append("{} days,".format(str(days)))
            if hours > 0:
                upstr.append("{} hours,".format(str(hours)))
            if minutes > 0:
                upstr.append("{} minutes,".format(str(minutes)))
            if seconds > 0:
                upstr.append("{} seconds,".format(str(seconds)))
            if uptime <= warning_treshold:
                rc = 1
            if uptime <= critical_treshold:
                rc = 2
            else:
                rc = 0

        if rc == 3:
            upstr = ['Uptime has not been returned']
        print("{} - {} | 'uptime': {}s".format(
            NagiosRetCode[rc],
            " ".join(upstr),
            str(uptime)))
        sys.exit(rc)

    except Exception as e:
        print("Error calling \"rgm_uptime_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine "Uptime" from ElasticSearch.
        Uptime is pushed from MetricBeat agent installed on the monitored machine.
        Uptime resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Uptime for machine "srv3" only if monitored data is not anterior at 4 minutes
        (4: default value). Warning alert if Uptime < 10 minutes. Critical alert if
        Uptime < 5 minutes.

            python uptime.py -H srv3 -w 10 -c 5

        Get Uptime for machine "srv3 only if monitored data is not anterior at 2 minutes. 

            python uptime.py -H srv3 -w 10 -c 5 -t 2

        Get Uptime for machine "srv3 with Verbose mode enabled.

            python uptime.py -H srv3 -w 10 -c 5 -v

        Get Uptime for machine "srv3 with Verbose mode enabled and only if monitored data is
        not anterior at 2 minutes. 

            python uptime.py -H srv3 -w 10 -c 5 -t 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger', default=10)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger', default=5)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        rgm_uptime_output(args.elastichost, args.hostname, args.warning, args.critical, args.timeout, args.verbose)
# EOF
