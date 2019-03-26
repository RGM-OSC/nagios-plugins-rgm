#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Disk space" from ElasticSearch.
  * Disk space values are pushed from MetricBeat agent installed on the monitored machine.
  * Disk resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 04 11:00:00 2018 
              
CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2018-09-04  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
  * 1.0.1       2019-03-26  Eric Belhomme <ebelhomme@fr.scc.com>        replace getopts by argparse module
                                                                        code factorization & mutualization
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


# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting Disk space values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.filesystem.device_name"
        metricset_module = "system"
        metricset_name = "filesystem"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(100)
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

# Request a custom ElasticSearch API REST Call (here: Get space for all Disks with: Percentage Used, Quantity Used (GigaBytes), and Quantity Free (GigaBytes)):
def get_disk(elastichost, plugin_hostname,data_validity,verbose):
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
        # Extract the "Total Hit" from results (= check if Disk Value has been returned):
        total_hit = int(results_json["hits"]["total"])
        # If request hits: find out how many Items are required to get space for all disks:
        if total_hit != 0:
            disks_names_list = []
            for index in (range(total_hit)) :
                disk_name = results_json["hits"]["hits"][index]["_source"]["system"]["filesystem"]["device_name"]
                if disk_name not in disks_names_list :
                    disks_names_list.append(disk_name)
                else :
                    resp_entries_range = int(index)
                    break
        # If request hits: for each Disk, extract results (Disk Values in %) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        disk_values_dic = {}
        if total_hit != 0:
            for position in (range(resp_entries_range)) :
                disk_values_dic.update( {"disk_"+str(position)+"": []} )
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["device_name"])
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["mount_point"])
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["pct"] * (100),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["bytes"] / (1024*1024*1024),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["free"] / (1024*1024*1024),2)))
        else:
            disk_values_dic.update( {"0": [0, 0, 0, 0, 0]} )
        return total_hit, resp_entries_range, disk_values_dic
    except Exception as e:
        print("Error calling \"get_disk\"... Exception {}".format(e))
        sys.exit(3)

# Build Alerting lists (sorted by Severity with Disk Space used %) and Performance Data lists (sorted by Severity with: Disk Space used %, Quantity Used (GB), and Quantity Free (GB)) :
def build_alerting_list(elastichost,plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Disk values:
        total_hit, resp_entries_range, disk_values_dic = get_disk(elastichost, plugin_hostname,data_validity,verbose)
        #print("Debug - \"disk_values_dic\" -> "+str(disk_values_dic)+"")
        # Build Alerting dic and Performance Data dic:
        alerting_dic, perfdata_dic = {}, {}
        for index in range(resp_entries_range) :
            if total_hit != 0 and (disk_values_dic["disk_"+str(index)][2] >= critical_treshold) :
                alerting_dic.update( {"CRITICAL_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )
                perfdata_dic.update( {"CRITICAL_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            elif total_hit != 0 and (disk_values_dic["disk_"+str(index)][2]  >= warning_treshold and disk_values_dic["disk_"+str(index)][2] < critical_treshold) :
                alerting_dic.update( {"WARNING_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )    
                perfdata_dic.update( {"WARNING_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            elif total_hit != 0 and (disk_values_dic["disk_"+str(index)][2] < warning_treshold) :  
                alerting_dic.update( {"OK_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )  
                perfdata_dic.update( {"OK_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            else:     
                alerting_dic.update( {"UNKNOWN_"+str(index)+"": "NA | NA"} ) 
                perfdata_dic.update( {"UNKNOWN_"+str(index)+"": "NA | NA"} ) 
        #print("Debug - \"alerting_dic\" -> "+str(alerting_dic)+"")
        #print("Debug - \"perfdata_dic\" -> "+str(perfdata_dic)+"")
        
        # Parse Alerting dic for storing System Information sorted by Severity in relevant lists:
        rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown = [], [], [], []
        rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, rgm_perfdata_unknown = [], [], [], []
        for index in range(resp_entries_range) :
            if ("UNKNOWN_"+str(index)+"") in alerting_dic :
                rgm_info_unknown.append(alerting_dic["UNKNOWN_"+str(index)+""])
                rgm_perfdata_unknown.append(perfdata_dic["UNKNOWN_"+str(index)+""])
            if ("CRITICAL_"+str(index)+"") in alerting_dic :
                rgm_info_critical.append(alerting_dic["CRITICAL_"+str(index)+""])
                rgm_perfdata_critical.append(perfdata_dic["CRITICAL_"+str(index)+""])
            if ("WARNING_"+str(index)+"") in alerting_dic :
                rgm_info_warning.append(alerting_dic["WARNING_"+str(index)+""])
                rgm_perfdata_warning.append(perfdata_dic["WARNING_"+str(index)+""])
            if ("OK_"+str(index)+"") in alerting_dic :
                rgm_info_ok.append(alerting_dic["OK_"+str(index)+""])
                rgm_perfdata_ok.append(perfdata_dic["OK_"+str(index)+""])
            
        # Prepare Performance Data to be return in a compliant format to RGM:
        rgm_perfdata_critical = str(rgm_perfdata_critical).replace("[\"", "").replace("\"]", "").replace("\", \"", "")
        rgm_perfdata_warning = str(rgm_perfdata_warning).replace("[\"", "").replace("\"]", "").replace("\", \"", "")
        rgm_perfdata_ok = str(rgm_perfdata_ok).replace("[\"", "").replace("\"]", "").replace("\", \"", "")

        # Return RGM System Information and Performance Data ready to display:
        return rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown, rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, rgm_perfdata_unknown

    except Exception as e:
        print("Error calling \"build_alerting_list\"... Exception {}".format(e))
        sys.exit(3)

# Display Disk space (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_disk_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get "ready to display" System Information and Performance Data:
        rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown, \
            rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, \
            rgm_perfdata_unknown = build_alerting_list(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
        # Return System Information + Performance Data in a format compliant with RGM expectations:
        if rgm_info_unknown:
            print("UNKNOWN: Disk space value has not been returned...")
            sys.exit(3)
        elif (rgm_info_critical) and (not rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 0 0\"")
            print("CRITICAL: "+str(rgm_info_critical)+""+str(rgm_perfdata_critical))
            sys.exit(2)
        elif (not rgm_info_critical) and (rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 1 0\"")
            print("WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_warning))
            sys.exit(1)
        elif (not rgm_info_critical) and (not rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 0 1\"")
            print("OK: "+str(rgm_info_ok)+""+str(rgm_perfdata_ok))
            sys.exit(0)
        elif (not rgm_info_critical) and (not rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 0 0\"")
            print("UNKNOWN: Disk space value has not been returned...")
            sys.exit(3)
        elif (rgm_info_critical) and (rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 1 1\"")
            print("CRITICAL: "+str(rgm_info_critical)+", WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_critical)+""+str(rgm_perfdata_warning))
            sys.exit(2)
        elif (rgm_info_critical) and (rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 1 0\"")
            print("CRITICAL: "+str(rgm_info_critical)+", WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_critical)+""+str(rgm_perfdata_warning))
            sys.exit(2)
        elif (not rgm_info_critical) and (rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 1 1\"")
            print("WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_warning))
            sys.exit(1)
        elif (rgm_info_critical) and (not rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 0 1\"")
            print("CRITICAL: "+str(rgm_info_critical)+""+str(rgm_perfdata_critical))
            sys.exit(2)
    except Exception as e:
        print("Error calling \"rgm_disk_output\"... Exception {}".format(e))
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine "Disk space" from ElasticSearch.
        Disk space values are pushed from MetricBeat agent installed on the monitored machine.
        Disk resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Disk space for machine "srv3" only if monitored data is not anterior at 4 minutes
        (4: default value). Warning alert if Disk > 85%%. Critical alert if Disk > 95%%.

            disk.py -H srv3 -w 85 -c 95

        Get Disk space for machine "srv3" only if monitored data is not anterior at 2 minutes. 

            disk.py -H srv3 -w 85 -c 95 -t 2

        Get Disk space for machine "srv3" with Verbose mode enabled.

            disk.py -H srv3 -w 85 -c 95 -v
        Get Disk space for machine "srv3" with Verbose mode enabled and only if monitored data
        is not anterior at 2 minutes. 

            disk.py -H srv3 -w 85 -c 95 -t 2 -v
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger', default=85)
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger', default=95)
    parser.add_argument('-t', '--timeout', type=str, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        rgm_disk_output(args.elastichost, args.hostname, args.warning, args.critical, args.timeout, args.verbose)
# EOF
