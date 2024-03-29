#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return status for a specified Linux or Windows Service from ElasticSearch.
  * Service status is pushed from MetricBeat agent installed on the monitored machine.
  * Service status resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Alex Rocher <arocher@fr.scc.com>   START DATE :    Aug 02 13:00:00 2022

CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2022-08-02  Alex Rocher <arocher@fr.scc.com>    Initial version

'''

__author__ = "Alex Rocher"
__copyright__ = "2022, SCC"
__credits__ = ["Alex Rocher"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Alex Rocher"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting latest Windows/Service event with given beat hostname and service name):
def custom_api_payload(hostname, service, data_validity, os):
    try:
        # ElasticSearch Custom Variables:
        if os == 'windows':
            field_name = "windows.service.name"
            event_module = "windows"
        else:
            field_name = "system.service.name"
            event_module = "system"
        
        beat_name = hostname
        metricset_name = "service"

        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(1)
        custom_payload = {}
        custom_payload.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_all":{}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{""+field_name+"":{"query":""+service+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"event.module":{"query":""+event_module+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"host.name":{"query":""+beat_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        return custom_payload
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)


# Request a custom ElasticSearch API REST Call (here: Get relevant details about the given Service name):
def get_service(elastichost, verbose, custom_payload, os):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call(elastichost)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=custom_payload, verify=False)
        results_json = results.json()
        if verbose:
            print("## VERBOSE MODE - API REST HTTP REQUEST - PAYLOAD: ####################################################################################")
            print("REQUESTED PAYLOAD: {}".format(custom_payload) + '\n')
            print("## VERBOSE MODE - API REST HTTP RESPONSE - JSON OUTPUT: ###############################################################################")
            print("JSON RESPONSE: {}".format(results_json) + '\n')
            print("## VERBOSE MODE - API REST HTTP RESPONSE - HITS: #####################################################################################")
            print("TOTAL HIT: {}".format(str(results_json["hits"]["total"])) + '\n')
            print("######################################################################################################################################")
        # Extract the "Total Hit" from results (= check if LOAD Value has been returned):
        total_hit = int(results_json["hits"]["total"]['value'])
        # If request hits: extract results and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        display_name, service_status = "TBD", "TBD"

        if total_hit != 0:
            # For debugging purpose
            # print("{}".format(results_json["hits"]["hits"][0]["_source"]["system"]["service"]))
            
            if os == 'windows':
                display_name = results_json["hits"]["hits"][0]["_source"]['windows']["service"]["display_name"]
                service_status = results_json["hits"]["hits"][0]["_source"]['windows']["service"]["state"]
            else:
                display_name = results_json["hits"]["hits"][0]["_source"]["system"]["service"]["name"]
                service_status = results_json["hits"]["hits"][0]["_source"]["system"]["service"]["state"]

        return total_hit, display_name, service_status
    except Exception as e:
            print("Error calling \"get_service\"... Exception {}".format(e))
            sys.exit(3)


# Display Nagios Status (System Information: yes, Performance Data: no) in a format compliant with RGM expectations:
def rgm_service_output(warning_treshold, critical_treshold, total_hit, display_name, service_status, os):
    try:
        # Get Memory values:
        retcode = 3
        # Parse value for Alerting returns:
        if total_hit == 0:
            print("UNKNOWN: Service has not been returned...")
            sys.exit(retcode)

        if os == 'windows':
            if service_status == "Stopped" and critical_treshold == True:
                retcode = 2
            if service_status == "Stopped" and warning_treshold == True:
                retcode = 1
            elif service_status == "Running":
                retcode = 0
        else:
            if service_status != "active" and critical_treshold == True:
                retcode = 2
            if service_status == "inactive" and warning_treshold == True:
                retcode = 1
            elif service_status == "active":
                retcode = 0

        print("{rc} - Service \"{display_name}\" is: {service_status}".format(
            rc = NagiosRetCode[retcode],
            display_name = str(display_name),
            service_status = str(service_status)))

        exit(retcode)
    except Exception as e:
        print("Error calling \"rgm_service_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return status for a specified OS (linux or windows) Service from ElasticSearch.
        Service status is pushed from MetricBeat agent installed on the monitored machine.
        Service status resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""

        Get Service status for Service "IKEEXT" hosted on monitored machine "srv3" only if monitored data is not anterior at 4 minutes (4: default value). Critical alert if Service Status is Stopped.

            python service.py -H srv3 -S IKEEXT -c

        Get Service status for Service "CryptSvc" hosted on monitored machine "srv3" only if monitored data is not anterior at 2 minutes.  Warning alert if Service Status is Stopped.

            python service.py -H srv3 -S CryptSvc -w -t 2

        Get Service status for Service "IKEEXT" hosted on monitored machine "srv3" with Verbose mode enabled.

            python service.py -H srv3 -S IKEEXT -c -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))

    parser.add_argument('-H', '--hostname', type=str, help='Hostname or IP address', required=True)
    parser.add_argument('-S', '--service', type=str, help='Windows service to monitor', required=True)
    parser.add_argument('-w', '--warning', help='Raise as a Warning alert if service is stopped', action='store_true')
    parser.add_argument('-c', '--critical', help='Raise as a Crtical alert if service is stopped', action='store_true')
    parser.add_argument('-t', '--timeout', type=int, help='Data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='Connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
    parser.add_argument('-o', '--os', help='Should be linux or windows, default to linux', default='linux')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        custom_payload = custom_api_payload(args.hostname, args.service, args.timeout, args.os)
        total_hit, display_name, service_status = get_service(args.elastichost, args.verbose, custom_payload, args.os)
        rgm_service_output(args.warning, args.critical, total_hit, display_name, service_status, args.os)


## EOF ####################################################################################################################
