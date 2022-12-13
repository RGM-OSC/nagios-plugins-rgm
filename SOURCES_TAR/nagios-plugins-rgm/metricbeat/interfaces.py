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
  * 0.1.0       2022-12-08  Eric Belhomme <ebelhomme@fr.scc.com>        Initial rewrite using Elasticsearch python module,
                                                                        class factorization,
                                                                        adding NIC filtering features
'''

__author__ = "Eric Belhomme"
__copyright__ = "2019, SCC"
__credits__ = ["Eric Belhomme"]
__license__ = "GPL"
__version__ = "0.1.0"
__maintainer__ = "Eric Belhomme"


## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys
import re
import argparse
import requests
import json
from elasticsearch import Elasticsearch
from datetime import datetime
import logging

from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost


import pprint
pp = pprint.PrettyPrinter()

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')


# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

logger = logging



class ESQuery:


    def __init__(self, es_hosts, index='metricbeat', filter=None, regexp=False, revert=False):
        self.es = Elasticsearch(hosts=es_hosts)
        self.index = index
        self.nic_lst = []
        self.filter_result = not revert
        self.filter_re = regexp
        if filter:
            if regexp:
                self.nicfilter = re.compile(filter)
            else:
                self.nicfilter = filter
        else:
            self.nicfilter = None

    def filter(self, nicname):
        if not self.nicfilter:
            return True
        else:
            if self.filter_re:
                if self.nicfilter.search(nicname):
                    return self.filter_result
                else:
                    return not self.filter_result
            else:
                if nicname == self.nicfilter:
                    return self.filter_result
                else:
                    return not self.filter_result

    def get_interfaces(self, hostname, data_validity):
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

#        try:
        now = datetime.utcnow()
        
        curindex = "{}-*-{:04d}-{:02d}-{:02d}".format(self.index, now.year, now.month, now.day)
        logger.debug("looking-up in ES index: {}".format(curindex))
        results_json = self.es.search(index=self.index + '*', body=esquery)
        logger.debug("request payload: {}".format(json.dumps(esquery, indent=4)))
        logger.debug("reply payload: {}".format(json.dumps(results_json, indent=4)))

        if not bool(results_json['timed_out']) and int(results_json["hits"]["total"]['value']) > 0:
            
            # get a list of returned fs, then keep only latest item of each mountpoint
            allfslist = [ i['_source'] for i in results_json['hits']['hits'] ]
            for nicname in set([ i['system']['network']['name'] for i in allfslist ]):
                logger.debug('nickname: {}'.format(nicname))
                if self.filter(nicname):
                    item = max([ i for i in allfslist if i['system']['network']['name'] == nicname  ], key=lambda timestamp: timestamp['@timestamp'])
                    self.nic_lst.append(item['system']['network'])

            return self.nic_lst

            def sort_list(element):
                return len(element['name'])

            return sorted(self.nic_lst, key=sort_list)
        else:
            # no fs returned
            return []

#        except Exception as e:
#            logger.error("Error calling 'get_interfaces'... Exception {}".format(e))
#            sys.exit(3)


## Get Options/Arguments then Run Script ##################################################################################
if __name__ == '__main__':
    ret = 3

    logging.basicConfig()
    logger = logging.getLogger(__name__)
    logger.setLevel(level=logging.INFO)

    parser = argparse.ArgumentParser(description="""
        Nagios plugin used to return machine network interfaces stats from ElasticSearch.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__))
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=4)
    parser.add_argument('-E', '--elastichost', type=str, help='connection URL of ElasticSearch server', default="http://localhost:9200")
    parser.add_argument('-f', '--filter', help='filter on NIC name', default=None)
    parser.add_argument('-r', '--regexp', help='filter is a regexp', action='store_true')
    parser.add_argument('-i', '--invert', help='invert filter', action='store_true')
    parser.add_argument(
        '-l', '--level', nargs='?', help='log level verbosity', type=lambda s: s.upper(),
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], default='WARNING'
    )
    args = parser.parse_args()
    logger.setLevel(level=getattr(logging, args.level, None))

    if validate_elastichost(args.elastichost):

        es = ESQuery(
            es_hosts=args.elastichost,
            filter=args.filter,
            regexp=args.regexp,
            revert=args.invert,
        )
        lstnic = es.get_interfaces(
            hostname=args.hostname,
            data_validity=args.timeout,
        )
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
