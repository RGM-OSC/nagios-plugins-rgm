#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine "CPU (Total, User, System)" from ElasticSearch.
  * CPU values are pushed from MetricBeat agent installed on the monitored machine.
  * CPU resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 03 08:30:00 2018 
              
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
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost


# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################


## Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting an CPU values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.cpu.total.pct"
        metricset_module = "system"
        metricset_name = "cpu"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload()
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
    except:
        print("Error calling \"custom_api_payload\"...")
        sys.exit()

## Request a custom ElasticSearch API REST Call (here: Get CPU in percentage):
def get_cpu(elastic_host, plugin_hostname,data_validity,verbose):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call(elastic_host)
        payload = custom_api_payload(plugin_hostname,data_validity)
        print(addr, header, payload)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        print(results)
        # Extract the "Total Hit" from results (= check if CPU Value has been returned):
        total_hit = int(results_json["hits"]["total"])
        # If request hits: extract results (CPU Values in %) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        if (total_hit != 0) and (verbose == "0") :
            cpu_nb = int(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["cores"])
            cpu_total = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["total"]["pct"]) * 100) / cpu_nb
            cpu_user = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["user"]["pct"]) * 100) / cpu_nb
            cpu_system = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["system"]["pct"]) * 100) / cpu_nb
        elif (total_hit != 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            cpu_nb = int(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["cores"])
            cpu_total = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["total"]["pct"]) * 100
            cpu_user = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["user"]["pct"]) * 100
            cpu_system = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["system"]["pct"]) * 100
        elif (total_hit == 0) and (verbose == "0") :
            cpu_total, cpu_user, cpu_system = 0, 0, 0
        elif (total_hit == 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            cpu_total, cpu_user, cpu_system = 0, 0, 0
        return total_hit, cpu_total, cpu_user, cpu_system
    except:
        print("Error calling \"get_cpu\"...")
        sys.exit()

## Display CPU (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_cpu_output(elastic_host, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get CPU values:
        total_hit, cpu_total, cpu_user, cpu_system = get_cpu(elastic_host, plugin_hostname, data_validity, verbose)
        # Parse value for Alerting returns:
        if total_hit != 0 and cpu_total >= critical_treshold:
            print("CRITICAL - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(2)
        elif total_hit != 0 and cpu_total >= warning_treshold and cpu_total < critical_treshold:
            print("WARNING - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(1)
        elif total_hit != 0 and cpu_total < warning_treshold:
            print("OK - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(0)
        else:
            print("UNKNOWN: CPU has not been returned...")
            sys.exit(3)
    except Exception:
        print("Error calling \"rgm_cpu_output\"...")
        sys.exit(3)


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine "CPU (Total, User, System)" from ElasticSearch.
        CPU values are pushed from MetricBeat agent installed on the monitored machine.
        CPU resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Total CPU for machine srv3 only if monitored data is not anterior at 4 minutes
        (4: default value). Warning alert if Total CPU > 85%%. Critical alert if Total CPU > 90%%

            cpu.py -H srv3 -w 85 -c 90

        * Get Total CPU for machine srv3 only if monitored data is not anterior at 2 minutes.

            cpu.py -H srv3 -w 85 -c 90 -t 2
            
        * Get Total CPU for machine srv3 with Verbose mode enabled.

            cpu.py -H srv3 -w 85 -c 90 -v

        * Get Total CPU for machine srv3 with Verbose mode enabled and only if monitored data
          is not anterior at 2 minutes.

            cpu.py -H srv3 -w 85 -c 90 -t 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger', default=80)
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger', default=90)
    parser.add_argument('-t', '--timeout', type=str, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        rgm_cpu_output(args.elastichost, args.hostname, args.warning, args.critical, args.timeout, args.verbose)

# EOF

