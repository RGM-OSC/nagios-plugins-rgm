#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Load Average (1 minute, 5 minutes, 15 minutes)" from ElasticSearch.
  * Load Average values are pushed from MetricBeat agent installed on the monitored machine.
  * Load Average resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 03 11:00:00 2018 
              
CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2018-09-03  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
  * 1.0.1       2019-03-26  Eric Belhomme <ebelhomme@fr.scc.com>        replace getopts by argparse module
                                                                        code factorization & mutualization
                                                                        added elastichost variable
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
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################


## Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting LOAD values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.load.5"
        metricset_module = "system"
        metricset_name = "load"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(1)
        custom_payload = {}
        custom_payload.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_all":{}} )
        custom_payload["query"]["bool"]["must"].append( {"exists":{"field":""+field_name+""}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.module":{"query":""+metricset_module+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"beat.name":{"query":""+beat_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        return custom_payload
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)

# Request a custom ElasticSearch API REST Call (here: Get Load Average for 1 minute, 5m and 15m):
def get_load(elastichost, plugin_hostname,data_validity,verbose):
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
            print("####################################################################################")
       # Extract the "Total Hit" from results (= check if LOAD Value has been returned):
       total_hit = int(results_json["hits"]["total"])
       # If request hits: extract results (LOAD Values) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
       if total_hit != 0:
           load_1 = float(results_json["hits"]["hits"][0]["_source"]["system"]["load"]["1"])
           load_5 = float(results_json["hits"]["hits"][0]["_source"]["system"]["load"]["5"])
           load_15 = float(results_json["hits"]["hits"][0]["_source"]["system"]["load"]["15"])
       else:
           load_1, load_5, load_15 = 0, 0, 0
       return total_hit, load_1, load_5, load_15
   except Exception as e:
        print("Error calling \"get_load\"... Exception {}".format(e))
        sys.exit(3)

# Display Load Average (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_load_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Load Average values:
        total_hit, load_1, load_5, load_15 = get_load(elastichost, plugin_hostname,data_validity,verbose)
        rc = 3
        # Parse value for Alerting returns:
        if total_hit != 0 and (load_5 >= critical_treshold) :
            rc = 2
        elif total_hit != 0 and (load_5 >= warning_treshold and load_5 < critical_treshold) :
            rc = 1
        elif total_hit != 0 and (load_5 < warning_treshold) :
            rc = 0
        else:
            print("UNKNOWN: Load Average has not been returned")
            sys.exit(rc)

        print("{}: Load Average 1 minute: {}, 5 minutes: {}, 15 minutes: {} | 'Load Average 1m'={};{};{} 'Load Average 5m'={};{};{} 'Load Average 15m'={};{};{}".format(
            NagiosRetCode[rc],
            str(round(load_1,2)),
            str(round(load_5,2)),
            str(round(load_15,2)),
            str(round(load_1,2)),
            str(warning_treshold),
            str(critical_treshold),
            str(round(load_5,2)),
            str(warning_treshold),
            str(critical_treshold),
            str(round(load_15,2)),
            str(warning_treshold),
            str(critical_treshold)))
        sys.exit(rc)

    except Exception as e:
        print("Error calling \"rgm_load_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine "Load Average (1 minute, 5 minutes, 15 minutes)"
        from ElasticSearch.
        Load Average values are pushed from MetricBeat agent installed on the monitored machine.
        Load Average resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Load Average for machine "srv3" only if monitored data is not anterior at 4 minutes
        (4: default value). Warning alert if Load > 70%%. Critical alert if Load > 80%%.

            python load.py -H srv3 -w 70 -c 80

        Get Load Average for machine "srv3" only if monitored data is not anterior at 2 minutes. 

            python load.py -H srv3 -w 70 -c 80 -t 2

        Get Load Average for machine "srv3" with Verbose mode enabled.

            python load.py -H srv3 -w 70 -c 80 -v

        Get Load Average for machine "srv3" with Verbose mode enabled and only if monitored data
        is not anterior at 2 minutes. 

            python load.py -H srv3 -w 70 -c 80 -t 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger', default=70)
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger', default=80)
    parser.add_argument('-t', '--timeout', type=str, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        rgm_load_output(args.elastichost, args.hostname, args.warning, args.critical, args.timeout, args.verbose)
# EOF

