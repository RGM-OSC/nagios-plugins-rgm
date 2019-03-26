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
    except:
        print("Error calling \"generic_api_call\"...")
        sys.exit()



# Build a generic Payload for ElasticSearch:
def generic_api_payload():
    try:
        generic_payload = {}
        # Sort / Request the Last Item:
        response_list_size = "1"
        generic_payload.update( {"version":"true","size":""+response_list_size+""} )
        generic_payload.update( {"sort":[{"@timestamp":{"order":"desc","unmapped_type":"boolean"}}]} )
        # Add Exclusion capability if needed later:
        generic_payload.update( {"_source":{"excludes":[]}} )
        return generic_payload
    except:
        print("Error calling \"generic_api_payload\"...")
        sys.exit()


# Return a range of time between 2x Epoch-Millisecond Timestamps:
def get_data_validity_range(data_validity):
    try:
        newest_valid_timestamp = int(round(time.time() * 1000))
        data_validity_ms = ( int(data_validity) * 60 * 1000 )
        oldest_valid_timestamp = ( newest_valid_timestamp - data_validity_ms )
        return newest_valid_timestamp, oldest_valid_timestamp
    except:
        print("Error calling \"get_data_validity_range\"...")
        sys.exit()

def validate_elastichost(elastichost):
    regex = re.compile(r"^https?://[-_\.\d\w]+:\d{2,5}/?$")
    if not regex.search(elastichost):
        print("Error: invalid ElasticSearch connection URL (must be of the fomr \"http://hostname:port\"")
        exit(2)
    return True;
