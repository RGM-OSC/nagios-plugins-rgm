#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine network statistics from ElasticSearch.

AUTHOR :
  * Eric Belhomme <ebelhomme@fr.scc.com>
  
CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2019-04-04  Eric Belhomme <ebelhomme@fr.scc.com>        Initial version
  * 0.0.2       2019-08-14  Samuel Ronciaux <sronciaux@fr.scc.com>      change metricset variable name to metricbeat agent 7.2.x  
'''

__author__ = "Eric Belhomme"
__copyright__ = "2019, SCC"
__credits__ = ["Eric Belhomme"]
__license__ = "GPL"
__version__ = "0.0.2"
__maintainer__ = "Eric Belhomme"


## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys
import re
import argparse
import requests
import json
import pprint
from elasticsearch import Elasticsearch
from datetime import datetime

from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')


# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################



def get_interfaces(elastichost, hostname, data_validity, verbose):

    es = Elasticsearch()

    # ElasticSearch Custom Variables:
    metricset_module = "system"
    metricset_name = "network"

    # Get Data Validity Epoch Timestamp:
    newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)

    esquery = {
        'query': {
            'bool': {
                'must': [
                    {'match_all': {}},
                    {'match_phrase': {'event.module': {'query': metricset_module}}},
                    {'match_phrase': {'metricset.name': {'query': metricset_name}}},
                    {'match_phrase': {'host.name': {'query': hostname}}},
                    {'exists': {'field': 'system.network'}},
                    {'range': {'@timestamp': {
                        'gte': str(oldest_valid_timestamp),
                        'lte': str(newest_valid_timestamp),
                        'format': 'epoch_millis'
                    }}},
                ],
                'should': [
                ],
                'must_not': [
                    {'match': {'system.network.name': {'query': 'lo'}}},
                ],
                'filter': [
#                    {'term': {'hostname': hostname}},
#                    {'term': {'_type': '_doc'}},
#                    {'range': {'timestamp': {'gte': str(oldest_valid_timestamp), 'format': 'epoch_millis'}}}
                ],
            },
        },
        'sort': [
            {'timestamp': {'order': 'desc', 'unmapped_type': 'boolean'}},
        ],
        '_source': {"excludes":[]},
        'size': '40',
        'version': 'true'
    }


    try:
        # Get prerequisites for ElasticSearch API:
#        addr, header = generic_api_call(elastichost)
#        payload = custom_api_payload(hostname,data_validity)
        # Request the ElasticSearch API:
#        results = requests.get(url=addr, headers=header, json=payload, verify=False)
#        results_json = results.json()
        now = datetime.utcnow()
        elindexname = 'metricbeat'
        curindex = "{}-*-{:04d}-{:02d}-{:02d}".format(elindexname, now.year, now.month, now.day)
        print(curindex)
        results_json = es.search(index='metricbeat*', body=esquery)
        if verbose:
            pp = pprint.PrettyPrinter(indent=4)
            print("### VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print("### request payload:")
            pp.pprint(esquery)
            print("### JSON output:")
            print(results_json)
            print("####################################################################################")

        if not bool(results_json['timed_out']) and int(results_json["hits"]["total"]['value']) > 0:
            niclst = []
            # get a list of returned fs, then keep only latest item of each mountpoint
            allfslist = [ i['_source'] for i in results_json['hits']['hits'] ]
            for nicname in set([ i['system']['network']['name'] for i in allfslist ]):
                item = max([ i for i in allfslist if i['system']['network']['name'] == nicname  ], key=lambda timestamp: timestamp['@timestamp'])
                
                niclst.append(item['system']['network'])
            def sort_list(element):
                return len(element['name'])

            return sorted(niclst, key=sort_list)
        else:
            # no fs returned
            return False

    except Exception as e:
        print("Error calling \"get_interfaces\"... Exception {}".format(e))
        sys.exit(3)


## Get Options/Arguments then Run Script ##################################################################################
if __name__ == '__main__':
    ret = 3
    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine network interfaces stats from ElasticSearch.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')

    args = parser.parse_args()
    
    if validate_elastichost(args.elastichost):
        lstnic = get_interfaces(args.elastichost, args.hostname, args.timeout, args.verbose)
        if isinstance(lstnic, list) and len(lstnic) > 0:
            print("OK: {} | {}".format(
                ", ".join([ "interface {} is up".format(i['name']) for i in lstnic ]),
                " ".join([ "'{nic}_in_octet'={oin}c '{nic}_out_octet'={out}c".format(nic=i['name'], oin=i['in']['bytes'], out=i['out']['bytes']) for i in lstnic ])
            ))
            ret = 0
        else:
            print("UNKNOWN: no interface returned")
    else:
        print("UNKNOWN: invalid Elastic server specified")

    sys.exit(ret)
# EOF
