#!/usr/bin/python3
'''
This script take the first argument, verify his status in openshift constante url with constante token, and return a nagios format
'''
import requests
import argparse
import sys

parser = argparse.ArgumentParser(description='CLI for request openshift api cluster operator and return a nagios format')
parser.add_argument(
    '-m', '--mode', nargs='?',
    choices=[
        'authentication',
        'baremetal',
        'cloud-controller-manager',
        'cloud-credential',
        'cluster-autoscaler',
        'config-operator',
        'console',
        'csi-snapshot-controller',
        'dns',
        'etcd',
        'image-registry',
        'ingress',
        'insights',
        'kube-apiserver',
        'kube-controller-manager',
        'kube-scheduler',
        'kube-storage-version-migrator',
        'machine-api',
        'machine-approver',
        'machine-config',
        'marketplace',
        'monitoring',
        'network',
        'node-tuning',
        'openshift-apiserver',
        'openshift-controller-manager',
        'openshift-samples',
        'operator-lifecycle-manager',
    ],
    help='operator name', required=True
)
parser.add_argument(
    '-u', '--url',
    type=str, help='OpenShit Kubernetes API base URL. Example: https://127.0.0.1:6443/apis',
    required=True
)
parser.add_argument('-t', '--token', type=str, help="OpenShift API token", required=True)
parser.add_argument('-v', '--verbose', action='store_true', help="verbose mode", default=False)

args = parser.parse_args()


url = "{}/config.openshift.io/v1/clusteroperators/{}".format(
    args.url,
    args.mode
)
token = args.token

def error(msg):
    print("UNKNOWN - " + msg)
    exit(3)

requests.packages.urllib3.disable_warnings()

options={
    "url": url,
    "method": "GET",
    "verify": False,
    "headers": {"Authorization":"Bearer " + token},
}

try:
    response = requests.request(**options)
except requests.exceptions.ConnectionError:
    error("Connection Error... Exiting")

if not response.ok:
    error("Error, http status {}".format(response.status_code))

try:
    result = response.json()
except:
    error("Can't parse JSON")

# Data processing
checkConfig = {
    'Available': {
        'shouldBe': 'True',
        'codeIfNot': 2,
        'messageError': 'is not available'
    },
    'Degraded': {
        'shouldBe': 'False',
        'codeIfNot': 1,
        'messageError': 'is degraded'
    }
}

returnCode = 0
messages = list()

for statusDetails in result['status']['conditions']:
    if args.verbose: print(statusDetails, file=sys.stderr)
    statusDetailsType = statusDetails['type']
    statusDetailsStatus = statusDetails['status']
    if statusDetailsType in checkConfig:
        if statusDetailsStatus != checkConfig[statusDetailsType]['shouldBe']:
            messages.append(checkConfig[statusDetailsType]['messageError'])
            returnCode = max(returnCode, checkConfig[statusDetailsType]['codeIfNot'])

if returnCode == 0:
    status = 'OK'
    message = 'is OK'
elif returnCode == 1:
    status = 'WARNING'
    message = ', '.join(messages)
elif returnCode == 2:
    status = 'CRITICAL'
    message = ', '.join(messages)
else:
    status = 'UNKNOWN'
    message = 'unknow return code'

print('{} - {} {}'.format(status, args.mode, message))
exit(returnCode)
