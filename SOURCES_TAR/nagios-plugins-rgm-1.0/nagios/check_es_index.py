#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to check the state of the elasticsearch indexes. 
  * 
  * 

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Wed 02 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-12-02  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
'''

__author__ = "Lucas, FUEYO"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas Fueyo"

## MODULES FEATURES ###################################################################################################

# Import the following modules:
import sys
import argparse
import requests
import json
import urllib3
import re

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')


## Declare Functions ##################################################################################################


# Build a custom URL for Veeam to get a valid Token
def get_data(ES_host, ES_port):

    try:
        # Create correct url to request
        request_url = str(
            "http://" + ES_host + ":" + ES_port + "/_all/_settings"
        )

        headers = {"Content-Type": "application/json"}

        # Request the URL and extract the token
        http = urllib3.PoolManager()
        r = http.request(
            'GET', request_url,
            headers=headers
        )

        # convert result to a usable string for regex
        result = json.loads(r.data)
        result = json.dumps(result)

        return result

    except Exception as e:
        print("Error calling \"get_data\"... Exception {} --- Verify host address or port !".format(e))
        sys.exit(3)


# Build a custom URL for Veeam to get a specific backup status (by name if specified)
def get_indexes_state(ES_host, ES_port):

    try:
        retcode = 0

        # Get indexes data
        index_string = get_data(ES_host, ES_port)

        # Get index state
        if(re.search('"read_only_allow_delete": "true"', index_string)):
            retcode = 2
            outtext = 'Some indexes are in read_only_allow_delete state.'
        else:
            retcode = 0
            outtext = 'All indexes are fine.'

        print(
            "{}: {state}".format(
                NagiosRetCode[retcode],
                state=outtext
            )
        )

        exit(retcode)

    except Exception as e:
        print("Error calling \"get_indexes_state\"... Exception --- Verify host address or port ! {}".format(e))
        sys.exit(3)


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin used to check the state of the elasticsearch indexes.
        You can also specify a hostname or port in case you would like to check a remote ES server.
        """,
        usage="""
        Get index status of local elastic server.

        python3 check_es_index.py

        Get index status of remote "ES_host" --> Have Critical alert if some indexes have read_only_allow_delete enabled !

        python3 check_es_index.py -H <ES_host> -p <ES_port>
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address of Elastic server', default='localhost')
    parser.add_argument('-p', '--port', type=str, help='Elastic server Port', default='9200')
    args = parser.parse_args()

    get_indexes_state(
        args.hostname,
        args.port
    )
