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
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.module":{"query":""+metricset_module+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"beat.name":{"query":""+beat_name+""}}} )
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
        total_hit = int(results_json["hits"]["total"])
        # If request hits: extract results (Uptime in ms) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        if total_hit != 0:
            uptime_ms = results_json["hits"]["hits"][0]["_source"]["system"]["uptime"]["duration"]["ms"]
        else:
            uptime_ms = 0
        return uptime_ms
    except Exception as e:
        print("Error calling \"get_uptime\"... Exception {}".format(e))
        sys.exit(3)

# Convert Uptime in milliseconds in a human-readable format -> Days:Hours:Minutes:Seconds:
def convert_uptime(elastichost, plugin_hostname,data_validity,verbose):
    try:
        uptime = int(get_uptime(elastichost, plugin_hostname,data_validity,verbose))
        # If Uptime has been returned in API Response, return converted values:
        if uptime != 0 :
            uptime_exists = 1
            seconds = int((uptime/1000)%60)
            minutes = int((uptime/(1000*60))%60)
            hours = int((uptime/(1000*60*60))%24)
            days = int((uptime/(24*60*60*1000)))
            converted_uptime = "Uptime is: "+str(days)+"d:"+str(hours)+"h:"+str(minutes)+"m:"+str(seconds)+"s"
        # If Uptime has not been returned in API Response, return a static code (0):
        elif uptime == 0 :
            uptime_exists, days, hours, minutes, converted_uptime = 0, 0, 0, 0, 0
        return uptime_exists, days, hours, minutes, converted_uptime
    except Exception as e:
        print("Error calling \"convert_uptime\"... Exception {}".format(e))
        sys.exit(3)

# Display Uptime (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_uptime_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Uptime values:
        uptime_exists, days, hours, minutes, converted_uptime = convert_uptime(elastichost,plugin_hostname,data_validity,verbose)
        uptime_mn = ( days * 24 * 60 ) + ( hours * 60) + minutes
        # Parse value for Alerting returns:
        if uptime_exists == 1 and uptime_mn < critical_treshold:
            print("CRITICAL: \"" +converted_uptime+ "\" | 'Uptime Minutes'="+str(uptime_mn)+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(2)
        elif uptime_exists == 1 and uptime_mn < warning_treshold and uptime_mn >= critical_treshold:
            print("WARNING: \"" +converted_uptime+ "\" | 'Uptime Minutes'="+str(uptime_mn)+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(1)
        elif uptime_exists == 1 and uptime_mn >= warning_treshold:
            print("OK: \"" +converted_uptime+ "\" | 'Uptime Minutes'="+str(uptime_mn)+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(0)
        else:
            print("UNKNOWN: Uptime has not been returned...")
            sys.exit(3)
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
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger', default=10)
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger', default=5)
    parser.add_argument('-t', '--timeout', type=str, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        rgm_uptime_output(args.elastichost, args.hostname, args.warning, args.critical, args.timeout, args.verbose)
# EOF
