#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return the number of specified Process from ElasticSearch (Windows + Linux).
  * Process details are pushed from MetricBeat agent installed on the monitored machine.
  * Process details resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Jul 29 11:00:00 2019

CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2019-31-07  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version

'''

__author__ = "Julien Dumarchey"
__copyright__ = "2019, SCC"
__credits__ = ["Julien Dumarchey"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Julien Dumarchey"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost, get_tuple_numeric_args

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting latest System/Process event with given beat hostname):
def custom_api_payload_get_timestamp(hostname,process_name,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = hostname
        field_name = "process.name"
        event_module = "system"
        metricset_name = "process"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(1)
        payload_get_timestamp = {}
        payload_get_timestamp.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        payload_get_timestamp.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"match_all":{}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"match_phrase":{""+field_name+"":{"query":""+process_name+""}}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"match_phrase":{"event.module":{"query":""+event_module+""}}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"match_phrase":{"host.name":{"query":""+beat_name+""}}} )
        payload_get_timestamp["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        return payload_get_timestamp
    except Exception as e:
        print("Error calling \"custom_api_payload_get_timestamp\"... Exception {}".format(e))
        sys.exit(3)

# Request a custom ElasticSearch API REST Call (here: Get the latest Timestamp where Process events has been collected by Elasticsearch):
def get_timestamp(elastichost,hostname,process_name,data_validity,verbose,payload_get_timestamp):
   try:
       # Get prerequisites for ElasticSearch API:
       addr, header = generic_api_call(elastichost)
       # Request the ElasticSearch API:
       results = requests.get(url=addr, headers=header, json=payload_get_timestamp, verify=False)
       results_json = results.json()
       if verbose:
            print("## GET TIMESTAMP - VERBOSE MODE - API REST HTTP REQUEST - PAYLOAD: #######################################################################")
            print("REQUESTED PAYLOAD: {}".format(payload_get_timestamp) + '\n')
            print("## GET TIMESTAMP - VERBOSE MODE - API REST HTTP RESPONSE - JSON OUTPUT: ##############################################################################")
            print("JSON RESPONSE: {}".format(results_json) + '\n')
            print("## GET TIMESTAMP - VERBOSE MODE - API REST HTTP RESPONSE - HITS: #########################################################################")
            print("TOTAL HIT: {}".format(str(results_json["hits"]["total"])) + '\n')
            print("######################################################################################################################################")
       # Extract the "Total Hit" from results (= check if LOAD Value has been returned):
       total_hit = int(results_json["hits"]["total"]['value'])
       # If request hits: extract results and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
       timestamp = "TBD"
       if total_hit != 0:
           timestamp = results_json["hits"]["hits"][0]["_source"]["@timestamp"]
       return total_hit, timestamp

   except Exception as e:
        print("Error calling \"get_timestamp\"... Exception {}".format(e))
        sys.exit(3)

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting System/Process events for a specific Timestamp and with a given beat hostname):
def custom_api_payload_get_process(hostname,process_name,data_validity,timestamp):
    try:
        if timestamp != "TBD" :
            # ElasticSearch Custom Variables:
            beat_name = hostname
            field_name = "process.name"
            event_module = "system"
            metricset_name = "process"
            # Get Data Validity Epoch Timestamp:
            newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
            # Build the generic part of the API Resquest Body:
            generic_payload = generic_api_payload(50)
            payload_get_process = {}
            payload_get_process.update(generic_payload)
            # Add the Query structure with ElasticSearch Variables:
            payload_get_process.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_all":{}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_phrase":{""+field_name+"":{"query":""+process_name+""}}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_phrase":{"@timestamp":{"query":""+timestamp+""}}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_phrase":{"event.module":{"query":""+event_module+""}}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
            payload_get_process["query"]["bool"]["must"].append( {"match_phrase":{"host.name":{"query":""+beat_name+""}}} )
            payload_get_process["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        else :
            payload_get_process = "No_Payload"
            print("No Event found for Process \"{}\".format(process_name)")
        return payload_get_process
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)

# Request a custom ElasticSearch API REST Call (here: Count the number of process about the given Process name and beat hostname):
def get_process_nb(elastichost,hostname,process_name,data_validity,verbose,payload_get_process):
   try:
       if payload_get_process != "No_Payload" :
           # Get prerequisites for ElasticSearch API:
           addr, header = generic_api_call(elastichost)
           # Request the ElasticSearch API:
           results = requests.get(url=addr, headers=header, json=payload_get_process, verify=False)
           results_json = results.json()
           if verbose:
                print("## GET PROCESS - VERBOSE MODE - API REST HTTP REQUEST - PAYLOAD: ####################################################################################")
                print("REQUESTED PAYLOAD: {}".format(payload_get_process) + '\n')
                print("## GET PROCESS - VERBOSE MODE - API REST HTTP RESPONSE - JSON OUTPUT: ###############################################################################")
                print("JSON RESPONSE: {}".format(results_json) + '\n')
                print("## GET PROCESS - VERBOSE MODE - API REST HTTP RESPONSE - HITS: #####################################################################################")
                print("TOTAL HIT: {}".format(str(results_json["hits"]["total"])) + '\n')
                print("######################################################################################################################################")
           # Extract the "Total Hit" from results (= check if LOAD Value has been returned):
           ##process_nb = int(results_json["hits"]["total"])
           process_nb = 0
           for event in range(len(results_json["hits"]["hits"])) :
               process_state = results_json["hits"]["hits"][event]["_source"]["system"]["process"]["state"]
               if (process_state == "running") or (process_state == "sleeping") :
                   process_nb = process_nb + 1
       else :
           process_nb = 0
       return process_nb

   except Exception as e:
        print("Error calling \"get_process_nb\"... Exception {}".format(e))
        sys.exit(3)

# Display Nagios Status (System Information: yes, Performance Data: no) in a format compliant with RGM expectations:
def rgm_process_nb_output(elastichost,plugin_hostname,process_name,warning_treshold,critical_treshold,data_validity,verbose,process_nb):
    try:
        # Get Alert values:
        retcode = 3

        # Parse value for Alerting returns:
        if process_nb <= critical_treshold :
            retcode = 2
        if (process_nb > critical_treshold) and (process_nb <= warning_treshold) :
            retcode = 1
        elif process_nb > warning_treshold:
            retcode = 0

        print("{rc} - Number of Process for \"{process_name}\" is: {process_nb}.".format(
            rc=NagiosRetCode[retcode],
            process_name=str(process_name),
            process_nb=str(process_nb)))
        exit(retcode)

    except Exception as e:
        print("Error calling \"rgm_process_nb_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return the number of specified Process from ElasticSearch (Windows + Linux).
        Process details are pushed from MetricBeat agent installed on the monitored machine.
        Process details resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""

        Get Number of active process for Process "httpd.exe" hosted on monitored machine "srv3" only if monitored data is not anterior at 4 minutes (4: default value).
        Critical alert if Number of process <= 2. Critical alert if Number of process <= 4.

            python process.py -H srv3 -P httpd.exe -w 4 -c 2

        Get Number of active process for Process "nginx.exe" hosted on monitored machine "srv3" only if monitored data is not anterior at 2 minutes.

            python process.py -H srv3 -P nginx.exe -w 4 -c 2 -t 2

        Get Number of active process for Process "httpd.exe" hosted on monitored machine "srv3" with Verbose mode enabled.

            python process.py -H srv3 -P httpd.exe -w 4 -c 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='Hostname or IP address', required=True)
    parser.add_argument('-P', '--process', type=str, help='Process Name to monitor', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='Raise as a Warning alert if the number of process is <= the given parameter', default=4)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='Raise as a Critical alert if the number of process is <= the given parameter', default=2)
    parser.add_argument('-t', '--timeout', type=str, help='Data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='Connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        payload_get_timestamp = custom_api_payload_get_timestamp(args.hostname,args.process,args.timeout)
        total_hit, timestamp = get_timestamp(args.elastichost,args.hostname,args.process,args.timeout,args.verbose,payload_get_timestamp)
        payload_get_process = custom_api_payload_get_process(args.hostname,args.process,args.timeout,timestamp)
        process_nb = get_process_nb(args.elastichost,args.hostname,args.process,args.timeout,args.verbose,payload_get_process)
        rgm_process_nb_output(args.elastichost,args.hostname,args.process,args.warning,args.critical,args.timeout,args.verbose,process_nb)

## EOF ####################################################################################################################
