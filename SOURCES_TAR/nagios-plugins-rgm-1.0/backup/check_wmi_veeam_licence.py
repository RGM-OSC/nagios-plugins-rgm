#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  * Nagios plugin used to return support date status from Veeam Enterprise Manager through WMI.
  * 
  * 

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Tue 03 15:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-11-03  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
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
import json
import wmi_client_wrapper as wmi
from datetime import datetime

NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

## Declare Functions ##################################################################################################


# Retrieve data from the wmi Veeam host
def get_wmi_data(EM_host, username, password):

    try:
        # Connect to the Host in the correct WMI Namespace
        wmic = wmi.WmiClientWrapper(
            username=username,
            password=password,
            host=EM_host,
            namespace='//./root/veeamEM'
        )

        output = wmic.query('Select * FROM License')

        return output

    except Exception as e:
        print("Error calling \"get_wmi_data\"... Exception {} --- Verify login or password !".format(e))
        sys.exit(3)


# Build a custom URL for Clearpass to get a specific service status by name
def get_license_status(EM_host, username, password, warning_threshold, critical_threshold, domain):

    try:
        retcode = 0
        outtext = []
        outlicenses = []
        sortedlicenses = []

        # Generate login from username and domain
        if(domain):
            username = domain + '/' + username

        # Get wmi data
        wmi_data = get_wmi_data(EM_host, username, password)

        total_licenses_failed = 0

        for line in wmi_data:
            if(line['IsSupportExpirationDateSpecified']):
                ExpirationDate = datetime.strptime(line['SupportExpirationDate'][0:8], '%Y%m%d')
                timeDelta = ExpirationDate.date() - datetime.now().date()

                if(timeDelta.days <= critical_threshold):
                    license_ret_code = 2
                    retcode = 2
                    total_licenses_failed += 1
                elif(timeDelta.days <= warning_threshold):
                    license_ret_code = 1
                    total_licenses_failed += 1
                    if(retcode == 0):
                        retcode = 1
                else:
                    license_ret_code = 0

                outlicenses.append(
                    "\n {state} - Expired : {supportState} - Expiration Date : {expirationDate} -" \
                    " Edition : {edition} - Email : {email}".format(
                        state=NagiosRetCode[license_ret_code],
                        supportState=line['IsSupportExpired'],
                        expirationDate=ExpirationDate.date(),
                        edition=line['Edition'],
                        email=line['EMail']
                    )
                )
            else:
                # No support date so we use the licenses dates if we have any
                if(line['IsExpirationDateSpecified']):

                    ExpirationDate = datetime.strptime(line['ExpirationDate'][0:8], '%Y%m%d')
                    timeDelta = ExpirationDate.date() - datetime.now().date()

                    if(timeDelta.days < 0):
                        isExpired = True
                    else:
                        isExpired = False

                    if(timeDelta.days <= critical_threshold):
                        license_ret_code = 2
                        retcode = 2
                        total_licenses_failed += 1
                    elif(timeDelta.days <= warning_threshold):
                        license_ret_code = 1
                        total_licenses_failed += 1
                        if(retcode == 0):
                            retcode = 1
                    else:
                        license_ret_code = 0
                else:
                    license_ret_code = 3
                    retcode = 2
                    total_licenses_failed += 1

                outlicenses.append(
                    "\n {state} - Expired : {isExpired} - Expiration Date : {expirationDate} -" \
                    " Edition : {edition} - Email : {email} - No support Data, licenses dates were used".format(
                        state=NagiosRetCode[license_ret_code],
                        isExpired=isExpired,
                        expirationDate=ExpirationDate.date(),
                        edition=line['Edition'],
                        email=line['EMail']
                    )
                )

        outtext.append(
            "{total_licenses_failed} license(s) at risk".format(
                total_licenses_failed=total_licenses_failed
            )
        )

        for line in outlicenses:
            if 'CRITICAL' in line:
                sortedlicenses.append(line)
        for line in outlicenses:
            if 'WARNING' in line:
                sortedlicenses.append(line)
        for line in outlicenses:
            if 'UNKNOWN' in line:
                sortedlicenses.append(line)
        for line in outlicenses:
            if 'OK' in line:
                sortedlicenses.append(line)

        print(
            "{}: {} {}".format(
                NagiosRetCode[retcode],
                " ".join(outtext),
                " ".join(sortedlicenses)
            )
        )

        exit(retcode)

    except Exception as e:
        print("Error calling \"get_license_status\"... Exception --- {}".format(e))
        sys.exit(3)


# Get Options/Arguments then Run Script ###############################################################################
if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin used to return Veeam "license expiration status" from a Veeam Enterprise Manager server.
        """,
        usage="""
        Get license status of "veeam_enterpriseManager" --> Have Critical alert if licenses are close to expiring !

        python3 check_wmi_veeam_licence.py -H veeam_EM -u username -p password -w warning_threshold -c critical_threshold -d domain

        Example : 

        Connect to the Enterprise Manager dcaveeam01 as a local user

        python3 check_wmi_veeam_licence.py -H dcaveeam01 -u Administrator -p MyPassword -w 40 -c 20

        Connect to the Enterprise Manager dcaveeam01 as a domain user

        python3 check_wmi_veeam_licence.py -H dcaveeam01 -u myServiceUser -p MyPassword -w 90 -c 60 -d myDomain

        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address of Enterprise Manager server', required=True)
    parser.add_argument('-u', '--user', type=str, help='Veeam user name', required=True)
    parser.add_argument('-p', '--password', type=str, help='Veeam password', required=True)
    parser.add_argument('-w', '--warning', type=int, help='warning trigger threshold', default='60')
    parser.add_argument('-c', '--critical', type=int, help='critical trigger threshold', default='30')
    parser.add_argument('-d', '--domain', type=str, help='Veeam Backup domain name', required=False)
    args = parser.parse_args()

    get_license_status(
        args.hostname,
        args.user,
        args.password,
        args.warning,
        args.critical,
        args.domain
    )