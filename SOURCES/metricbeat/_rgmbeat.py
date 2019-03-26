#!/usr/bin/env python
# -*- coding: utf-8 -*-


import sys, time, re

# Build ElasticSearch URL for generic API Call:
def generic_api_call(elastic_host):

    try:
        addr = "{}/_search".format(elastic_host)
        # Build HEADER:
        header = {'Content-Type': 'application/json'}
        return addr, header
    except Exception as e:
        print("Error calling \"generic_api_call\"... Exception {}".format(e))
        sys.exit(3)

# Build a generic Payload for ElasticSearch:
def generic_api_payload(response_list_size):
    try:
        generic_payload = {}
        # Sort / Request the Last Item:
        generic_payload.update( {"version":"true","size":"{}".format(str(response_list_size))} )
        generic_payload.update( {"sort":[{"@timestamp":{"order":"desc","unmapped_type":"boolean"}}]} )
        # Add Exclusion capability if needed later:
        generic_payload.update( {"_source":{"excludes":[]}} )
        return generic_payload
    except Exception as e:
        print("Error calling \"generic_api_payload\"... Exception {}".format(e))
        sys.exit(3)

# Return a range of time between 2x Epoch-Millisecond Timestamps:
def get_data_validity_range(data_validity):
    try:
        newest_valid_timestamp = int(round(time.time() * 1000))
        data_validity_ms = ( int(data_validity) * 60 * 1000 )
        oldest_valid_timestamp = ( newest_valid_timestamp - data_validity_ms )
        return newest_valid_timestamp, oldest_valid_timestamp
    except Exception as e:
        print("Error calling \"get_data_validity_range\"... Exception {}".format(e))
        sys.exit(3)

def validate_elastichost(elastichost):
    regex = re.compile(r"^https?://[-_\.\d\w]+:\d{2,5}/?$")
    if not regex.search(elastichost):
        print("Error: invalid ElasticSearch connection URL (must be of the fomr \"http://hostname:port\"")
        exit(2)
    return True;
