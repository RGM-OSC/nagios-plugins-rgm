#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
DESCRIPTION :
  * Nagios plugin used to check the replication status of slaves Clearpass Appliance.
  *
  *

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Tue 19 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-05-19  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
  * 0.0.2       2024-01-26  Vincent FRICOU <vfricou@fr.scc.com>         Update auth model to client_credentials
"""

__author__ = "Lucas, FUEYO"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO", "Vincent FRICOU"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas FUEYO"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json, urllib3, urllib, pytz
from datetime import datetime, timedelta
from dateutil import parser

NagiosRetCode = ("OK", "WARNING", "CRITICAL", "UNKNOWN")

# If required, disable SSL Warning Logging for "requests" library:
urllib3.disable_warnings()


## Declare Functions ######################################################################################################
# Build a custom URL for Clearpass to get a valid Token
def get_token(clearpass_host, client_id, client_secret):
    try:
        # Create correct url to request
        request_url = str("https://" + clearpass_host + ":443/api/oauth")

        # Create body to authenticate
        encoded_body = json.dumps(
            {
                "grant_type": "client_credentials",
                "client_id": client_id,
                "client_secret": client_secret,
            }
        )

        # Request the URL and extract the token
        https = urllib3.PoolManager(cert_reqs="NONE")
        r = https.request(
            "POST",
            request_url,
            headers={"Content-Type": "application/json"},
            body=encoded_body,
        )

        result = json.loads(r.data)
        return result["access_token"]

    except Exception as e:
        print(
            'Error calling "get_token"... Exception {} --- Verify login, passwd or clientID !'.format(
                e
            )
        )
        sys.exit(3)


# Build a custom URL for Clearpass to get cluster informations
def get_cluster(clearpass_host, access_token):
    try:

        # Create correct url to request
        request_url = str("https://" + clearpass_host + ":443/api/cluster/server")

        # Request the URL and return the event list
        https = urllib3.PoolManager(cert_reqs="NONE")
        r = https.request(
            "GET",
            request_url,
            headers={
                "Accept": "application/json",
                "Authorization": "Bearer " + access_token,
            },
        )

        result = json.loads(r.data)
        return result["_embedded"]["items"]

    except Exception as e:
        print('Error calling "get_cluster"... Exception {}'.format(e))
        sys.exit(3)


# Format the output for RGM
def rgm_replication_output(
    clearpass_host,
    client_id,
    client_secret,
    warning_threshold,
    critical_threshold,
):
    try:

        retcode = 3
        outtext = []
        outservers = []

        # Get authentication token
        access_token = get_token(clearpass_host, client_id, client_secret)

        # Get cluster members
        member_list = get_cluster(clearpass_host, access_token)

        # Check if member list is empty
        if not member_list:
            retcode = 0
            print("No cluster members for host " + clearpass_host)
            sys.exit(retcode)
        else:
            retcode = 0

        first_dict = {
            "name": "first",
            "is_master": False,
            "replication_status": "ENABLED",
            "last_replication_timestamp": "2020-05-21T10:00:00.254+02:00",
            "management_ip": "10.112.11.121",
        }
        member_list.append(first_dict)
        second_dict = {
            "name": "second",
            "is_master": False,
            "replication_status": "ENABLED",
            "last_replication_timestamp": "2020-05-22T09:00:00.254+02:00",
            "management_ip": "10.112.11.122",
        }
        member_list.append(second_dict)
        third_dict = {
            "name": "third",
            "is_master": False,
            "replication_status": "ENABLED",
            "last_replication_timestamp": "2020-05-22T10:00:00.254+02:00",
            "management_ip": "10.112.11.123",
        }
        member_list.append(third_dict)

        now = pytz.utc.localize(datetime.utcnow())

        for server in member_list:
            server_status = 3
            if not server["is_master"]:

                if server["replication_status"] == "ENABLED":

                    if server["last_replication_timestamp"]:

                        replication_date = parser.parse(
                            server["last_replication_timestamp"]
                        )
                        delta = now - replication_date

                        delta_minutes = int(delta.days * 1440) + int(delta.seconds / 60)

                        if delta_minutes > int(critical_threshold):
                            retcode = 2
                            server_status = 2
                        elif delta_minutes > int(warning_threshold):
                            server_status = 1
                            if retcode != 2:
                                retcode = 1
                        else:
                            server_status = 0

                        outservers.append(
                            "\n Status : {status} - Name : {name} - Management IP : {mgmt_ip},"
                            " Replication delta : {delta_minutes} minutes".format(
                                status=NagiosRetCode[server_status],
                                name=server["name"],
                                mgmt_ip=server["management_ip"],
                                delta_minutes=delta_minutes,
                            )
                        )

                    else:
                        server_status = 2
                        retcode = 2

                        outservers.append(
                            "\n Status : {status} - Name : {name} - Replication never happened".format(
                                status=NagiosRetCode[server_status], name=server["name"]
                            )
                        )

                else:
                    server_status = 2
                    retcode = 2

                    outservers.append(
                        "\n Status : {status} - Name : {name} - Replication not enabled".format(
                            status=NagiosRetCode[server_status], name=server["name"]
                        )
                    )

            else:
                print("Host " + clearpass_host + " is the cluster publisher")

        outtext.append("Global replication status")

        print(
            "{}: {} {}".format(
                NagiosRetCode[retcode], " ".join(outtext), " ".join(outservers)
            )
        )

        exit(retcode)

    except Exception as e:
        print('Error calling "rgm_replication_output"... Exception --- {}'.format(e))
        sys.exit(3)


## Get Options/Arguments then Run Script ##################################################################################

if __name__ == "__main__":

    argparse = argparse.ArgumentParser(
        description="""
        Nagios plugin used to check the replication status of slaves  Clearpass Appliance.
        """,
        usage="""
        check the replication status of slaves Clearpass Servers
        python check_clearpass_API_replication.py -H clearpass1 -i clientID -s clientSecret
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__),
    )
    argparse.add_argument(
        "-H", "--hostname", type=str, help="hostname or IP address", required=True
    )
    argparse.add_argument(
        "-w",
        "--warning",
        type=str,
        nargs="?",
        help="warning trigger threshold",
        default="60",
    )
    argparse.add_argument(
        "-c",
        "--critical",
        type=str,
        nargs="?",
        help="critical trigger threshold",
        default="120",
    )
    argparse.add_argument(
        "-i", "--clientID", type=str, help="Clearpass API clientID", required=True
    )
    argparse.add_argument(
        "-s",
        "--clientSecret",
        type=str,
        help="Clearpass API clientSecret",
        required=True,
    )
    args = argparse.parse_args()

    rgm_replication_output(
        args.hostname,
        args.clientID,
        args.clientSecret,
        args.warning,
        args.critical,
    )

# EOF
