#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return machine network statistics from ElasticSearch.

AUTHOR :
  * Eric Belhomme <ebelhomme@fr.scc.com>

CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2019-04-04  Eric Belhomme <ebelhomme@fr.scc.com>        Initial version
  * 0.0.2       2019-08-14  Samuel Ronciaux <sronciaux@fr.scc.com>      change metricset variable name to metricbeat
                                                                        agent 7.2.x
'''

__author__ = "Eric Belhomme"
__copyright__ = "2019, SCC"
__credits__ = ["Eric Belhomme"]
__license__ = "GPL"
__version__ = "0.0.2"
__maintainer__ = "Eric Belhomme"

# MODULES FEATURES ####################################################################################################

# Import the following modules:
import sys
import argparse
import requests
import pprint
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')


# Declare Functions ###################################################################################################


def custom_api_payload(hostname, data_validity):
    '''
    Build a custom Payload for ElasticSearch
    here: HTTP Request Body for getting Disk space values for a specified hostname
    '''
    try:
        # ElasticSearch Custom Variables:
        metricset_module = "system"
        metricset_name = "network"

        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)

        # Build the generic part of the API Resquest Body:
        custom_payload = generic_api_payload(40)

        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update({'query': {'bool': {'must': [], 'filter': [], 'should': [], 'must_not': []}}})
        custom_payload['query']['bool']['must'].append({'match_all': {}})
        custom_payload['query']['bool']['must'].append({'match_phrase': {'event.module': {'query': metricset_module}}})
        custom_payload['query']['bool']['must'].append({'match_phrase': {'metricset.name': {'query': metricset_name}}})
        custom_payload['query']['bool']['must'].append({'match_phrase': {'host.name': {'query': hostname}}})
        custom_payload['query']['bool']['must'].append({'exists': {'field': 'system.network'}})
        custom_payload['query']['bool']['must_not'].append({'match': {'system.network.name': {'query': 'lo'}}})
        custom_payload['query']['bool']['must'].append(
            {'range': {'@timestamp': {
                'gte': str(oldest_valid_timestamp),
                'lte': str(newest_valid_timestamp),
                'format': 'epoch_millis'
            }}}
        )
        return custom_payload
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)


# Request a custom ElasticSearch API REST Call (here: Get Load Average for 1 minute, 5m and 15m):
def get_interfaces(elastichost, hostname, data_validity, verbose):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call(elastichost)
        payload = custom_api_payload(hostname, data_validity)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        if verbose:
            pp = pprint.PrettyPrinter(indent=4)
            print("### VERBOSE MODE - API REST HTTP RESPONSE: #########################################")
            print("### request payload:")
            pp.pprint(payload)
            print("### JSON output:")
            print(results_json)
            print("####################################################################################")

        if not bool(results_json['timed_out']) and int(results_json["hits"]["total"]['value']) > 0:
            niclst = []
            # get a list of returned fs, then keep only latest item of each mountpoint
            allfslist = [i['_source'] for i in results_json['hits']['hits']]
            for nicname in set([i['system']['network']['name'] for i in allfslist]):
                item = max(
                    [i for i in allfslist if i['system']['network']['name'] == nicname],
                    key=lambda timestamp: timestamp['@timestamp']
                )
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


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':
    ret = 3
    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin used to return machine network interfaces stats from ElasticSearch.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=4)
    parser.add_argument(
        '-E', '--elastichost', type=str, help='connection URL of ElasticSearch server',
        default="http://localhost:9200"
    )
    parser.add_argument('-v', '--verbose', help='be verbose', action='store_true')
    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        lstnic = get_interfaces(args.elastichost, args.hostname, args.timeout, args.verbose)
        if isinstance(lstnic, list) and len(lstnic) > 0:
            print(
                "OK: {} | {}".format(
                    ", ".join(["interface {} is up".format(i['name']) for i in lstnic]),
                    " ".join(
                        [
                            "'{nic}_in_octet'={oin}c '{nic}_out_octet'={out}c".format(
                                nic=i['name'],
                                oin=i['in']['bytes'],
                                out=i['out']['bytes']
                            ) for i in lstnic
                        ]
                    )
                )
            )
            ret = 0
        else:
            print("UNKNOWN: no interface returned")
    else:
        print("UNKNOWN: invalid Elastic server specified")

    sys.exit(ret)
# EOF
