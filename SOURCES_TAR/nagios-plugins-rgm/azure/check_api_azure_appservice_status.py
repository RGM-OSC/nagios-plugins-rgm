#!/usr/bin/env python3
# # -*- coding: utf-8 -*-

import argparse
import re
from ast import arg
import sys
import json
import pprint
import Class.AzureApi as AzureApi

parser = argparse.ArgumentParser(description='Check Azur Operation List')
parser.add_argument('-i','--id', help='Azure VM ID', required=True)
parser.add_argument('-d', '--directory', help='Directory (tenant) ID', required=True)
parser.add_argument('-r', '--resourceGroup', help='Resource Groups Name (tenant) ID', required=True)
parser.add_argument('-s','--secret', help='Azure VM secret', required=True)
parser.add_argument('-S', '--subscription', help='Subscription (tenant) ID', required=True)
parser.add_argument('-a','--appServiceName', help='Azure App Service Name', required=True)
parser.add_argument('-V', '--verbose', help='Verbose', action='store_true')

args = parser.parse_args()

## Api resquest
ressource_url = "https://management.azure.com/subscriptions/{subscription}/resourceGroups/{resourceGroup}/providers/Microsoft.Web/sites/{appServiceName}?api-version=2018-11-01".format(subscription = args.subscription , resourceGroup = args.resourceGroup, appServiceName = args.appServiceName)

api = AzureApi.AzureApi(args.id, args.secret)

print ("[*] Requesting token...") if args.verbose else None
api.get_token(args.directory) 
print('[*] Token received') if args.verbose else None

print("[*] Requesting resource...") if args.verbose else None
try:
    pp = pprint.PrettyPrinter(indent=4)
    res = api.get_info(ressource_url)
    Running_value =  "Running"
    status = 0
    state = res["properties"]["state"]
    usage_state = res["properties"]["usageState"]
    availabilityState = res["properties"]["availabilityState"]
    service = res["properties"]["name"]
    
    if state is None or state == "" :
        print ("[*] Unable to get State status value : UNKNOWN")
        sys.exit(3)
    if usage_state is None or usage_state == "" :
        print ("[*] Unable to get Usage State status value : UNKNOWN")
        sys.exit(3)
    if availabilityState is None or availabilityState == "" : 
        print ("[*] Unable to get Availability State status value : UNKNOWN")
        sys.exit(3)

    output = "{service} : {state} (quotaUsageState : {usageState} - mgmtAvailabilityState : {availabilityState})".format(service = service, state = state, usageState = usage_state, availabilityState = availabilityState)
    if re.search(Running_value, state):
        if usage_state == "Exceeded" and availabilityState == "Normal":
            output = "WARNING : {service} {state} (quotaUsageState : {usageState} )".format(service = service, state = state, usageState = usage_state)
            status = 1
        elif usage_state == "Normal" and (availabilityState ==  "Limited" or availabilityState == "DisasterRecoveryMode") :
            output = "WARNING : {service} {state} (mgmtAvailabilityState : {availabilityState} )".format(service = service, state = state, availabilityState = availabilityState)
            status = 1
        elif usage_state == "Exceeded" and (availabilityState == "Limited" or availabilityState == "DisasterRecoveryMode") :
            output = "WARNING : {service} {state} quotaUsageState : {usageState} - mgmtAvailabilityState : {availabilityState}".format(service = service, state = state, usageState = usage_state, availabilityState = availabilityState)
            status = 1
        elif usage_state == "Normal" and availabilityState == "Normal":
            output = "OK : {service} is {state}".format(service = service, state = state)
            status = 0
    else :
        output = "CRITICAL : {service} is not running".format(service = service)
        status = 2

    print (output)
    sys.exit(status)
except Exception as e:
    print ("[*] UNKNOWN: Error {e}".format(e=e))
    sys.exit(3)
