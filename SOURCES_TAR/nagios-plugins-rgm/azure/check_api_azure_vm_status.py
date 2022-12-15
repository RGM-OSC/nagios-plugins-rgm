# # -*- coding: utf-8 -*-

import argparse
import re
import sys
import json
import pprint
from NagiosClasses import AzureApi

parser = argparse.ArgumentParser(description='Check Azure VM status')
parser.add_argument('-d', '--directory', help='Directory (tenant) ID', required=True)
parser.add_argument('-i','--id', help='Azure VM ID', required=True)
parser.add_argument('-r', '--ressource', help='Azure VM ressource name', required=True)
parser.add_argument('-s','--secret', help='Azure VM secret', required=True)
parser.add_argument('-S','--subscription', help='Azure subscription ID', required=True)
parser.add_argument('-v', '--vmname', help='Azure VM name', required=True)
parser.add_argument('-V', '--verbose', help='Verbose', action='store_true')
args = parser.parse_args()

ressource_url = 'https://management.azure.com/subscriptions/{args.subscription}/resourceGroups/{args.ressource}/providers/Microsoft.Compute/virtualMachines/{args.vmname}/instanceView?api-version=2018-04-01'.format(args=args)

api = AzureApi.AzureApi(args.id, args.secret)

print ("[*] Requesting token...") if args.verbose else None
api.get_token(args.directory)
print('[*] Token received') if args.verbose else None

print("[*] Requesting resource...") if args.verbose else None
try:
    pp = pprint.PrettyPrinter(indent=4)
    res = api.get_info(ressource_url)
    Running_value = "VM deallocated"

    for valueStatuses in res["statuses"]:
        if re.search(Running_value, valueStatuses["displayStatus"]):
            print('OK: VM "{args.vmname}" is running'.format(args=args))
            sys.exit(0)

    print('CRITICAL: VM {args.vmname} is not running: {res}'.format(args=args, res=res)) 
    sys.exit(2)
except Exception as e:
    print('UNKNOWN: Error {e}'.format(e=e))
    sys.exit(3)

