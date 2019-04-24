#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: expandtab ts=4 sw=4:

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Disk space" from ElasticSearch.
  * Disk space values are pushed from MetricBeat agent installed on the monitored machine.
  * Disk resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 04 11:00:00 2018 
  * Eric Belhomme <ebelhomme@fr.scc.com>
  
CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2018-09-04  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
  * 1.0.1       2019-03-26  Eric Belhomme <ebelhomme@fr.scc.com>        replace getopts by argparse module
                                                                        code factorization & mutualization
  * 1.1.0       2019-04-04  Eric Belhomme <ebelhomme@fr.scc.com>        massive rewrite with list comprehension
                                                                        perfdata are absolute MB instead of percentage                                                                        
'''

__author__ = "Julien Dumarchey, Eric Belhomme"
__copyright__ = "2018, SCC"
__credits__ = ["Julien Dumarchey", "Eric Belhomme"]
__license__ = "GPL"
__version__ = "1.1.0"
__maintainer__ = "Julien Dumarchey"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import urllib3
urllib3.disable_warnings()
import sys, re, argparse, requests, json, pprint
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

# If required, disable SSL Warning Logging for "requests" library:
requests.packages.urllib3.disable_warnings()

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
        resp_entries_range = 0
        addr, header = generic_api_call(elastichost)
        payload = custom_api_payload(plugin_hostname,data_validity)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        if verbose:
            pp = pprint.PrettyPrinter(indent=4)
            print("### VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print("### request payload:")
            pp.pprint(payload)
            print("### JSON output:")
            pp.pprint(results_json)
            print("####################################################################################")

        if int(results_json["hits"]["total"]) > 0:
            fslist = []
            # get a list of returned fs, then keep only latest item of each mountpoint
            allfslist = [ i['_source'] for i in results_json['hits']['hits'] ]
            for fs in set([ i['system']['filesystem']['mount_point'] for i in allfslist ]):
                item = max([ i for i in allfslist if i['system']['filesystem']['mount_point'] == fs ], key=lambda timestamp: timestamp['@timestamp'])
                
                fslist.append({
                    'device_name': item['system']['filesystem']['device_name'],
                    'mount_point': item['system']['filesystem']['mount_point'],
                    'total': int(item['system']['filesystem']['total']),
                    'free': int(item['system']['filesystem']['free']),
                    'used': int(item['system']['filesystem']['used']['bytes'])}
                )
            def sort_fslist(element):
                return len(element['mount_point'])

            return sorted(fslist, key=sort_fslist)
        else:
            # no fs returned
            return False

    except Exception as e:
        print("Error calling \"get_disk\"... Exception {}".format(e))
        sys.exit(3)

# Build Alerting lists (sorted by Severity with Disk Space used %) and Performance Data lists (sorted by Severity with: Disk Space used %, Quantity Used (GB), and Quantity Free (GB)) :
def build_alerting_list(elastichost,plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Disk values:
        ret = []
        fslist = get_disk(elastichost, plugin_hostname, data_validity, verbose)

        if isinstance(fslist, list):
            for item in fslist:
                item['warn_treshold_abs'] = (int(warning_treshold) * item['total']) / 100
                item['crit_treshold_abs'] = (int(critical_treshold) * item['total']) / 100
                item['nagios_status'] = 3

                if item['used'] >= item['crit_treshold_abs']:
                    item['nagios_status'] = 2
                elif item['used'] >= item['warn_treshold_abs']:
                    item['nagios_status'] = 1
                elif item['used'] < item['warn_treshold_abs']:
                    item['nagios_status'] = 0

                ret.append(item)
            return ret
        else:
            return False

    except Exception as e:
        print("Error calling \"build_alerting_list\"... Exception {}".format(e))
        sys.exit(3)

def byte2mbyte(bytes):
    return int(bytes/(1024*1024))

# Display Disk space (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_disk_output(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):

    try:
        nagios_status = 3
        fslist = build_alerting_list(elastichost, plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
        if isinstance(fslist, list):
            nagios_status = max(fslist, key=lambda status: status['nagios_status'])['nagios_status']
            outtext = []
            outperf = []
            if nagios_status != 0:
                crit = [ i['mount_point'] for i in fslist if i['nagios_status'] == 2 ]
                if len(crit) > 0:
                    outtext.append("{} mountpoints in CRITICAL state ({}%): {}".format(
                        str(len(crit)),
                        str(critical_treshold),
                        ", ".join(crit)))
                warn = [ i['mount_point'] for i in fslist if i['nagios_status'] == 1 ]
                if len(warn) > 0:
                    outtext.append("{} mountpoints in WARNING state ({}%): {}".format(
                        str(len(warn)),
                        str(warning_treshold),
                        ", ".join(warn)))
            else:
                outtext.append("All mountpoints in OK state ({}%, {}%)".format(int(warning_treshold), int(critical_treshold)))

            for item in fslist:
                outperf.append("'{label}'={value}MB;{warn};{crit};0;{total}".format(
                    label=item['mount_point'],
                    value=str(byte2mbyte(item['used'])),
                    warn=str(byte2mbyte(item['warn_treshold_abs'])),
                    crit=str(byte2mbyte(item['crit_treshold_abs'])),
                    total=str(byte2mbyte(item['total']))
                ))

        else:
            print("{}: no output returned for time period ({} min)".format(NagiosRetCode[nagios_status], data_validity))

        print("{}: {} | {}".format(
            NagiosRetCode[nagios_status],
            " ".join(outtext),
            " ".join(outperf)
        ))
        sys.exit(nagios_status)

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
    else:
        print("can't validate elastic host")
# EOF
