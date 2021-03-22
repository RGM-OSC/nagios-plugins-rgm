#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION : Nagios plugin to retrieve system time from ES Metricbeat

AUTHOR : Eric Belhomme <ebelhomme@fr.scc.com>
'''

__author__ = 'Eric Belhomme'
__copyright__ = '2020, SCC'
__credits__ = ['Eric Belhomme']
__license__ = 'GPL'
__version__ = '0.1.0'
__maintainer__ = 'Eric Belhomme'


import sys
import logging
import argparse
from datetime import datetime
import dateutil.parser
from dateutil.tz import tzlocal

import elasticsearch_dsl
from elasticsearch_dsl import Q
from pprint import PrettyPrinter


NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

pp = PrettyPrinter()
escnx = None


class ArgumentParser(argparse.ArgumentParser):
    '''
    This override Python ArgumentParser class to allow sys.exit with a custom exit code
    '''
    def error(self, message):
        self.print_help(sys.stderr)
        self.exit(3, '%s\n' % message)


if __name__ == '__main__':

    rc = 3

    #parser = argparse.ArgumentParser(
    parser = ArgumentParser(
        description="""
        Nagios plugin used to return machine system time from ElasticSearch.
        This plugin return the timestamp of latest metricbeat document pushed
        by client and compares it with our local time.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger', default=90)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger', default=180)
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
            Q('match', **{'host.name': args.hostname})
        ]
    )
    # we'll output only '@timestamp' field
    request = request.source(['@timestamp'])
    # sorting by '@timestamp', latest at first
    request = request.sort({'@timestamp': {'order': 'desc', 'unmapped_type': 'boolean'}})
    # we return only the first 10 results
    request = request[0:10]
    # execute request on ES server
    response = request.execute()

    if len(response) > 0:
        esdate = dateutil.parser.parse(response[0]['@timestamp'])
        now = datetime.now(tzlocal())
        delta = now - esdate
        drift = ''
        if delta.total_seconds() < args.warning:
            rc = 0
        elif delta.total_seconds() < args.critical:
            rc = 1
            drift = " - drift time: {}s".format(int(delta.total_seconds()))
        else:
            rc = 2
            drift = " - drift time: {}s".format(int(delta.total_seconds()))
        print(
            "{rc}: last systime - {date}{drift}".format(
                rc=NagiosRetCode[rc],
                date=esdate.astimezone(now.tzinfo).ctime(),
                drift=drift
            )
        )
    else:
        print("{}: failed to retrieve systime information".format(NagiosRetCode[rc]))

    sys.exit(rc)
