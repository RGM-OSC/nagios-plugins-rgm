#!/usr/bin/env python3
# # -*- coding: utf-8 -*-


import argparse
import sys
import json
import pprint
from NagiosClasses import AzureApi

# A faire:

parser = argparse.ArgumentParser(description='Check Azur Operation List')
parser.add_argument('-i','--id', help='Azure VM ID', required=True)
parser.add_argument('-d', '--directory', help='Directory (tenant) ID', required=True)
parser.add_argument('-S', '--subscription', help='Subscription (tenant) ID', required=True)
parser.add_argument('-s','--secret', help='Azure VM secret', required=True)
parser.add_argument('-V', '--verbose', help='Verbose', action='store_true')

args = parser.parse_args()

ressource_url = "https://management.azure.com/subscriptions/{subscription}/providers/Microsoft.RecoveryServices/vaults?api-version=2016-06-01".format(subscription = args.subscription)

api = AzureApi.AzureApi(args.id, args.secret)

print ("[*] Requesting token...") if args.verbose else None
api.get_token(args.directory)
print('[*] Token received') if args.verbose else None

print("[*] Requesting resource...") if args.verbose else None
try:
    # ressource = api.get_resource(ressource_url)
    succeeded_backup = 0
    res = api.get_info(ressource_url)
    # print(res)
    total_backup = len(res["value"])
    pp = pprint.PrettyPrinter(indent=4)
    pp.pprint(res)
    for backupStatus in res['value']:
        # print(backupStatus)
        if backupStatus["properties"]["provisioningState"] == "Succeeded":
        # if backupStatus["properties"]["provisioningStateForBackup"] == "Succeeded":
            succeeded_backup += 1
        print("[*]  Backup Succeeded : " , succeeded_backup ) if args.verbose else None
    if succeeded_backup == total_backup:
        print("OK : {succeeded_backup}/{total_backup} Backup are Succeeded".format(succeeded_backup=succeeded_backup , total_backup=total_backup))
    else:
        print("CRITICAL : {error_backup}/{total_backup} Backup are Failed".format(error_backup = total_backup - succeeded_backup , total_backup=total_backup))
    with open('public_backup_succeeded.json', 'w') as outfile:
        json.dump(res, outfile , indent=4)
except Exception as e:
    print('UNKNOWN: Error {e}'.format(e=args.e))
    sys.exit(3)