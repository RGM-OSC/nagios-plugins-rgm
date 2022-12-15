#!/usr/bin/env python3
# # -*- coding: utf-8 -*-

import argparse
import sys
import json
import pprint
from textwrap import indent
from NagiosClasses import AzureApi

parser = argparse.ArgumentParser(description='Check Azur Operation List')
parser.add_argument('-i','--id', help='Azure VM ID', required=True)
parser.add_argument('-d', '--directory', help='Directory (tenant) ID', required=True)
parser.add_argument('-S', '--subscription', help='Subscription (tenant) ID', required=True)
parser.add_argument('-r', '--resourceGroupName', help='Resource Group Name (tenant) ID', required=True)
parser.add_argument('-s','--secret', help='Azure VM secret', required=True)
parser.add_argument('-V', '--verbose', help='Verbose', action='store_true')

args = parser.parse_args()

ressource_url = 'https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/publicIPAddresses?api-version=2021-08-01'.format(subscription = args.subscription , resourceGroupName = args.resourceGroupName)

api = AzureApi.AzureApi(args.id, args.secret)

print ("[*] Requesting token...") if args.verbose else None
api.get_token(args.directory)
print('[*] Token received') if args.verbose else None

print("[*] Requesting resource...") if args.verbose else None
try:
    succeeded_ip = 0
    res = api.get_info(ressource_url)

    total_ip = len(res["value"])
    # pp = pprint.PrettyPrinter(indent=4)
    # pp.pprint(res)
    for ip in res["value"]:
        # pp.pprint(ip)
        if ip["properties"]["provisioningState"] == "Succeeded":
            succeeded_ip += 1
    print("[*]  IP Succeeded : " , succeeded_ip ) if args.verbose else None
    
    if succeeded_ip == total_ip:
        print("OK : {succeeded_ip}/{total_ip} IP are Succeeded".format(succeeded_ip=succeeded_ip , total_ip=total_ip))
        sys.exit(0)
    else:
        print("CRITICAL : {error_ip}/{total_ip} IP are Failed".format(error_ip = total_ip - succeeded_ip , total_ip=total_ip))
        sys.exit(2)
        # Other Method ret code sys.exit(1)
        # print("Warning  : {}/{} IP are Failed".format(total_ip - succeeded_ip , total_ip))

    with open('public_ip_succeeded.json', 'w') as outfile:
        json.dump(res, outfile , indent=4)
    
except Exception as e:
    print('UNKNOWN: Error {e}'.format(e=e))
    sys.exit(3)
