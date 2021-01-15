#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION : Nagios plugin to retrieve cpu queue length from ES Metricbeat for Windows systems

AUTHOR : Lucas Fueyo <lfueyo@fr.scc.com>
'''

__author__ = 'Lucas Fueyo'
__copyright__ = '2020, SCC'
__credits__ = ['Lucas Fueyo']
__license__ = 'GPL'
__version__ = '0.1.0'
__maintainer__ = 'Lucas Fueyo'


import sys
import logging
import rgmbeat
from datetime import datetime
import dateutil.parser
from dateutil.tz import tzlocal

import elasticsearch_dsl
from elasticsearch_dsl import Q


NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

escnx = None


if __name__ == '__main__':

    rc = 3

    parser = rgmbeat.RGMArgumentParser(
        description="""
        Nagios plugin used to return windows machine cpu queue length from ElasticSearch.
        This plugin return the value of latest metricbeat document pushed by client.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger', default=5)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger', default=10)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=5)
    parser.add_argument(
        '-E', '--elastichost', type=str, help='connection URL of ElasticSearch server',
        default="localhost:9200"
    )
    args = parser.parse_args()

    escnx = elasticsearch_dsl.connections.create_connection(hosts=[args.elastichost], timeout=20)
    # construct an Elasticsearch DSL Search() object, using Q() shortcuts to build the query
    request = elasticsearch_dsl.Search(using=escnx, index="metricbeat-*", doc_type='_doc')
    request = request.query(
        'bool', must=[
            'match_all',
            # as Q shortcut doesn't support nested keywords (eg. 'agent.type' for instance)
            # we must provide keywords as kwargs dict type
            Q('match', **{'agent.type': 'metricbeat'}),
            Q('match', **{'host.name': args.hostname}),
            Q('exists', **{'field': 'windows.perfmon.system.processor_queue_length'})
        ]
    )
    # we'll output 'windows.perfmon.system.processor_queue_length' and '@timestamp' fields
    request = request.source(['@timestamp', 'windows.perfmon.system.processor_queue_length'])
    # sorting by '@timestamp', latest at first
    request = request.sort({'@timestamp': {'order': 'desc', 'unmapped_type': 'boolean'}})
    # we return only the first result
    request = request[0]
    # execute request on ES server
    response = request.execute()

    if len(response) > 0:
        esdate = dateutil.parser.parse(response[0]['@timestamp'])
        now = datetime.now(tzlocal())
        delta = (now - esdate).total_seconds() / 60

        if(delta > args.timeout):
            print("Latest data was too old for processing - older than " + str(args.timeout) + " minutes.")
            sys.exit(3)

        esqueue = response[0]['windows']['perfmon']['system']['processor_queue_length']

        queue_length = "processor queue length: {}".format(int(esqueue))
        if esqueue < args.warning:
            rc = 0
        elif esqueue < args.critical:
            rc = 1
        else:
            rc = 2
        print(
            "{rc}: {queue_length}".format(
                rc=NagiosRetCode[rc],
                queue_length=queue_length
            )
        )
    else:
        print("{}: failed to retrieve processor queue length information".format(NagiosRetCode[rc]))

    sys.exit(rc)
