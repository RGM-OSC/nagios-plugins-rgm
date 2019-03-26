#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Memory (1 minute, 5 minutes, 15 minutes)" from ElasticSearch.
  * Memory values are pushed from MetricBeat agent installed on the monitored machine.
  * Memory resquest is handled by API REST againt ElasticSearch.
    
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
import sys, argparse, requests, json
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost, get_tuple_numeric_args

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting Memory values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.memory.actual.used.pct"
        metricset_module = "system"
        metricset_name = "memory"
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

# Request a custom ElasticSearch API REST Call (here: Get Memories: Used, Free, Swap for Linux distrib):
def get_memory(elastichost, plugin_hostname,data_validity,verbose):
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
       # If request hits: extract results (Memory Values in %) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
       if total_hit != 0:
            mem_used_pct = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["actual"]["used"]["pct"]) * 100
            mem_used_bytes = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["actual"]["used"]["bytes"])
            mem_free_bytes = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["actual"]["free"])
            swap_used_pct = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["swap"]["used"]["pct"]) * 100
            swap_used_bytes = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["swap"]["used"]["bytes"])
            swap_free_bytes = float(results_json["hits"]["hits"][0]["_source"]["system"]["memory"]["swap"]["free"])
       else:
           mem_used_pct, mem_used_bytes, mem_free_bytes, swap_used_pct, swap_used_bytes, swap_free_bytes = 0, 0, 0, 0, 0, 0
       return total_hit, mem_used_pct, mem_used_bytes, mem_free_bytes, swap_used_pct, swap_used_bytes, swap_free_bytes
   except Exception as e:
        print("Error calling \"get_memory\"... Exception {}".format(e))
        sys.exit(3)

# Convert Bytes in GigaBytes :
def convert_bytes(elastichost, plugin_hostname,data_validity,verbose):
    try:
        total_hit, mem_used_pct, mem_used_bytes, mem_free_bytes, swap_used_pct, swap_used_bytes, swap_free_bytes = get_memory(elastichost, plugin_hostname,data_validity,verbose)
        # If Memory has been returned in API Response, return converted values:
        if total_hit != 0 :
            mem_used_gb = (mem_used_bytes/(1024*1024*1024))
            mem_free_gb = (mem_free_bytes/(1024*1024*1024))
            swap_used_gb = (swap_used_bytes/(1024*1024*1024))
            swap_free_gb = (swap_free_bytes/(1024*1024*1024))
        # If Memory has not been returned in API Response, return a static code (0):
        elif total_hit == 0 :
            mem_used_gb, mem_free_gb, swap_used_gb, swap_free_gb = 0, 0, 0, 0
        return total_hit, mem_used_pct, mem_used_gb, mem_free_gb, swap_used_pct, swap_used_gb, swap_free_gb
    except Exception as e:
        print("Error calling \"convert_bytes\"... Exception {}".format(e))
        sys.exit(3)

# Display Memory (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_memory_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Memory values:
        retcode = 3
        total_hit, mem_used_pct, mem_used_gb, mem_free_gb, swap_used_pct, swap_used_gb, swap_free_gb = convert_bytes(elastichost,plugin_hostname,data_validity,verbose)
        # Parse value for Alerting returns:
        if total_hit == 0:
            print("UNKNOWN: Memory has not been returned...")
            sys.exit(retcode)

        if mem_used_pct >= critical_treshold[0] or swap_used_pct >= critical_treshold[1]:
            retcode = 2
        elif (mem_used_pct >= warning_treshold[0] and mem_used_pct < critical_treshold[0]) or \
            (swap_used_pct >= warning_treshold[1] and swap_used_pct < critical_treshold[1]):
            retcode = 1
        elif mem_used_pct < warning_treshold[0] and swap_used_pct < warning_treshold[1]:
            retcode = 0

        print("{rc} - Memory Usage: {mmem}% (Qty Used: {umem}GB, Qty Free: {fmem}GB)," \
            " Swap Usage: {mswp}% (Qty Used: {uswp}GB, Qty Free: {fswp}GB) |" \
            " 'Memory'={mmem}%;{mtw};{mtc} | 'swap'={mswp};{stw},{stc}".format(
            rc=NagiosRetCode[retcode],
            mmem=str(round(mem_used_pct,2)),
            umem=str(round(mem_used_gb,2)),
            fmem=str(round(mem_free_gb,2)),
            mswp=str(round(swap_used_pct,2)),
            uswp=str(round(swap_used_gb,2)),
            fswp=str(round(swap_free_gb,2)),
            mtw=warning_treshold[0],
            mtc=critical_treshold[0],
            stw=warning_treshold[1],
            stc=critical_treshold[1]))
        exit(retcode)

    except Exception as e:
        print("Error calling \"rgm_memory_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine "Memory (1 minute, 5 minutes, 15 minutes)" from ElasticSearch.
        Memory values are pushed from MetricBeat agent installed on the monitored machine.
        Memory resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Memory for machine "srv3" only if monitored data is not anterior at 4 minutes
        (4: default value).
        Warning alert if Memory > 85%% or swap > 40%%.
        Critical alert if Memory > 95%% or swap > 50%%.

            python memory.py -H srv3 -w 85,40 -c 95,50

        Get Memory for machine "srv3" only if monitored data is not anterior at 2 minutes. 

            python memory.py -H srv3 -w 85,40 -c 95,50 -t 2

        Get Memory for machine "srv3" with Verbose mode enabled.

            python memory.py -H srv3 -w 85,40 -c 95,50 -v

        Get Memory for machine "srv3" with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 

            python memory.py -H srv3 -w 85,40 -c 95,50 -t 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger (physical,swap)', default='85,40')
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger (physical,swap)', default='95,50')
    parser.add_argument('-t', '--timeout', type=str, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    warn = get_tuple_numeric_args(args.warning)
    crit = get_tuple_numeric_args(args.critical)
    if not isinstance(warn, tuple) or not isinstance(crit, tuple):
        parser.print_help()
        exit(3)

    if validate_elastichost(args.elastichost):
        rgm_memory_output(args.elastichost, args.hostname, warn, crit, args.timeout, args.verbose)
# EOF
