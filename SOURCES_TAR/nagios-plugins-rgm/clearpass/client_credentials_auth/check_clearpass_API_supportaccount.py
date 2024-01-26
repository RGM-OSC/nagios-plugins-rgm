#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
DESCRIPTION :
  * Nagios plugin used to check presence of support account with Super Admin rights on a Clearpass Appliance.
  *
  *

  AUTHOR :
  * Lucas FUEYO <lfueyo@fr.scc.com>    START DATE :    Tue 19 09:00:00 2020

  CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2020-05-19  Lucas FUEYO <lfueyo@fr.scc.com>             Initial version
"""

__author__ = "Lucas, FUEYO"
__copyright__ = "2020, SCC"
__credits__ = ["Lucas, FUEYO"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Lucas FUEYO"

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import sys, re, argparse, requests, json, urllib3, urllib
import urllib.parse

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
def get_account(clearpass_host, access_token, clearpass_account):
    try:

        # Create the url_filter
        url_filter = (
            '{"$and":[{"user_id":"'
            + clearpass_account
            + '"},{"role_name":"[TACACS Super Admin]"}]}'
        )

        # Encode the string to be used in the URL
        url_filter = urllib.parse.quote(url_filter)

        # Create correct url to request
        request_url = str(
            "https://"
            + clearpass_host
            + ":443/api/local-user?filter="
            + url_filter
            + "&sort=%2Bid&offset=0&limit=25&calculate_count=false"
        )

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
        print('Error calling "get_account"... Exception {}'.format(e))
        sys.exit(3)


# Format the output for RGM
def rgm_supportaccount_output(
    clearpass_host, client_id, client_password, clearpass_account
):
    try:

        retcode = 3

        # Get authentication token
        access_token = get_token(clearpass_host, client_id, client_password)

        # Get cluster members
        account_info = get_account(clearpass_host, access_token, clearpass_account)

        # Check if member list is empty
        if not account_info:
            retcode = 2
            print(
                NagiosRetCode[retcode]
                + " - No account with ID "
                + clearpass_account
                + " on host "
                + clearpass_host
            )
            sys.exit(retcode)
        elif not account_info[0]["enabled"]:
            retcode = 2
            print(
                NagiosRetCode[retcode]
                + " - The account "
                + clearpass_account
                + " is not enabled on host "
                + clearpass_host
            )
            sys.exit(retcode)
        else:
            retcode = 0

        print(
            "{status} - Account : {account} - Role : {role} - Enabled : {enabled}".format(
                status=NagiosRetCode[retcode],
                account=clearpass_account,
                role=account_info[0]["role_name"],
                enabled=account_info[0]["enabled"],
            )
        )

        exit(retcode)

    except Exception as e:
        print('Error calling "rgm_supportaccount_output"... Exception --- {}'.format(e))
        sys.exit(3)


## Get Options/Arguments then Run Script ##################################################################################

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="""
        Nagios plugin used to check presence of support account with Super Admin rights on a Clearpass Appliance.
        """,
        usage="""
        Check presence of support account SCC with Super Admin rights on a Clearpass Appliance.
            python check_clearpass_API_supportaccount.py -H clearpass1 -a account_username -i clientID -s clientSecret
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__),
    )
    parser.add_argument(
        "-H", "--hostname", type=str, help="hostname or IP address", required=True
    )
    parser.add_argument(
        "-a", "--account", type=str, help="Clearpass Account user_id", default="SCC"
    )
    parser.add_argument(
        "-i", "--clientID", type=str, help="Clearpass API clientID", required=True
    )
    parser.add_argument(
        "-s",
        "--clientSecret",
        type=str,
        help="Clearpass API clientSecret",
        required=True,
    )
    args = parser.parse_args()

    rgm_supportaccount_output(
        args.hostname, args.clientID, args.clientSecret, args.account
    )

# EOF
