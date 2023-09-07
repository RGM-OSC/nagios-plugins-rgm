#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DESCRIPTION :
  * Nagios plugin used to check the state of the elasticsearch cluster.

  AUTHOR :
  * Vincent FRICOU <vfricou@fr.scc.com>    START DATE :    Thu 07 14:00:00 2023

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 1.0.0       2023-09-07  Vincent FRICOU <vfricou@fr.scc.com>         Initial version
"""

__author__ = "Vincent FRICOU"
__copyright__ = "2023, SCC"
__credits__ = ["Vincent FRICOU"]
__license__ = "GPL"
__version__ = "1.0.0"
__maintainer__ = __author__

import argparse
import json
import pprint
import sys

import requests

pp = pprint.PrettyPrinter()

nagios_exit_codes = {
    'OK': 0,
    'WARNING': 1,
    'CRITICAL': 2,
    'UNKNOWN': 3
}


class ElasticSearch:

    def __init__(self, host: str, port: str, schema: str):
        self.host = host
        self.port = port
        self.schema = schema
        self.base_url = '{schema}://{host}:{port}'.format(schema=self.schema, host=self.host, port=self.port)
        self.headers = {'Content-Type': 'application/json'}

    @staticmethod
    def __api_get(url: str, headers: dict) -> json:
        try:
            response = requests.get(url, headers=headers)
        except Exception as e:
            print('Error calling ES backend... Exception {}'.format(e))
            sys.exit(nagios_exit_codes['CRITICAL'])
        return json.loads(response.content)

    def get_cluster_health(self) -> json:
        url = '{base_url}/_cluster/health'.format(base_url=self.base_url)
        return self.__api_get(url=url,headers=self.headers)


def gen_output(status: str) -> tuple:
    if status == 'green':
        output = 'Elasticsearch cluster status {status}'.format(status=status)
        exit_code = nagios_exit_codes['OK']
    elif status == 'yellow':
        output = 'WARNING - Elasticsearch cluster status {status}'.format(status=status)
        exit_code = nagios_exit_codes['WARNING']
    elif status == 'red':
        output = 'CRITICAL - Elasticsearch cluster status {status}'.format(status=status)
        exit_code = nagios_exit_codes['CRITICAL']
    else:
        output = 'UNKNOWN - Elasticsearch cluster status {status}'.format(status=status)
        exit_code = nagios_exit_codes['UNKNOWN']

    return output, exit_code


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog='check_es_cluster',
        description='Check Elasticsearch cluster health status',
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('-H', '--hostname', help='Elasticsearch engine host address', type=str)
    parser.add_argument('-P', '--port', help='Elasticsearch engine port', type=str)
    parser.add_argument('-S', '--schema', help='Elasticsearch engine schema (http or https)', type=str)
    args = parser.parse_args()

    es_backend = ElasticSearch(host=args.hostname, port=args.port, schema=args.schema)
    cluster_status = es_backend.get_cluster_health()['status'].replace("'", "")

    output, exit_code = gen_output(cluster_status)
    print("{}".format(output))
    sys.exit(exit_code)
