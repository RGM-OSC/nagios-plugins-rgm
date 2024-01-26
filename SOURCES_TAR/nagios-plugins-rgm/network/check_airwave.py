#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DESCRIPTION :
  * Nagios plugin used to monitor Aruba Airwave controller.

AUTHOR :
  * Vincent Fricou <vfricou@fr.scc.com>   START DATE :    Nov 20 09:45:00 2023

CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2023-11-20  Vincent Fricou <vfricou@fr.scc.com>         Initial version
"""

__author__ = "Vincent Fricou"
__copyright__ = "2023, SCC"
__credits__ = ["Vincent Fricou"]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = "Vincent Fricou"

# MODULES FEATURES ####################################################################################################

import sys, requests, xmltodict, re
from argparse import ArgumentParser, RawTextHelpFormatter
from typing import Tuple

from urllib3.exceptions import InsecureRequestWarning
from urllib3 import disable_warnings


# Declare Functions ###################################################################################################
class Nagios:
    def __init__(self, output: str, perf: str):
        self.output = output
        self.perf = perf

    @staticmethod
    def exit_code(value: str) -> int:
        if value == "OK":
            sys.exit(0)
        elif value == "WARNING":
            sys.exit(1)
        elif value == "CRITICAL":
            sys.exit(2)
        elif value == "UNKNOWN":
            sys.exit(3)

    def out(self, warn: int, crit: int):
        """
        Function to perform check output
        :param warn: Warning count value
        :param crit: Critical count value
        """
        if warn > 0:
            self.output = "Warning - Click for details,{output}".format(output=output)
            exit_value = "WARNING"
        elif crit > 0:
            self.output = "Critical - Click for details,{output}".format(output=output)
            exit_value = "CRITICAL"
        else:
            self.output = "OK - Click for details,{output}".format(output=output)
            exit_value = "OK"

        print(self.output.translate(str.maketrans(",", "\n")))
        if perf:
            print("|" + perf)
        self.exit_code(value=exit_value)


class Airwave:
    def __init__(self, host: str, port: int, ssl_verify: bool):
        self.host = host
        self.port = port
        self.ssl_verify = ssl_verify
        self.headers = {
            "Content-Type": "application/x-www-form-urlencoded",
        }
        self.base_url = "https://{host}:{port}".format(host=self.host, port=self.port)
        self.session = None
        disable_warnings(InsecureRequestWarning)

    def login(self, username, password) -> requests.Response:
        """
        Perform login to Airwave controller and return X-BISCOTTI token
        :param username: API username to connect to Airwave controller
        :param password: API password to connect to Airwave controller
        :return: str
        """
        url = "{base_url}/LOGIN".format(base_url=self.base_url)
        payload = (
            "credential_0={username}&credential_1={password}&destination=/api".format(
                username=username, password=password
            )
        )

        try:
            self.session = requests.Session()
            return self.session.post(
                url=url, headers=self.headers, data=payload, verify=self.ssl_verify
            )
        except requests.exceptions as e:
            print("Error calling login API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

    def get_stats(self):
        """
        Retrieve AMP stats from Airwave controller
        :return:
        """
        url = "{base_url}/amp_stats.xml".format(base_url=self.base_url)

        payload = {}
        headers = {}

        try:
            r = self.session.get(
                url=url, headers=headers, data=payload, verify=self.ssl_verify
            )
            return xmltodict.parse(r.content)["amp:amp_stats"]
        except requests.exceptions as e:
            print("Error calling AMP stats API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

    def get_folders(self):
        """
        Retreive folders list from Airwave controller.
        :return:
        """
        url = "{base_url}/folder_list.xml".format(base_url=self.base_url)

        payload = {}
        headers = {}

        try:
            r = self.session.get(
                url=url, headers=headers, data=payload, verify=self.ssl_verify
            )
            return xmltodict.parse(r.content)["amp:amp_folder_list"]["folder"]
        except requests.exceptions as e:
            print("Error calling folders API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

    def get_ap_list(self):
        """
        Retreive ap list from Airwave controller
        :return:
        """
        url = "{base_url}/ap_list.xml".format(base_url=self.base_url)
        payload = {}
        headers = {}

        try:
            r = self.session.get(
                url=url, headers=headers, params=payload, verify=self.ssl_verify
            )
            return xmltodict.parse(r.content)["amp:amp_ap_list"]["ap"]
        except requests.exceptions as e:
            print("Error calling ap list API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

    def get_alerts(self):
        """
        Retreive alerts list from Airwave controller
        :return:
        """
        url = "{base_url}/alerts.xml".format(base_url=self.base_url)
        payload = {}
        headers = {}

        try:
            r = self.session.get(
                url=url, headers=headers, params=payload, verify=self.ssl_verify
            )
            return xmltodict.parse(r.content)["amp:amp_alert"]["record"]
        except requests.exceptions as e:
            print("Error calling ap list API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

    def get_visualrf_status(self) -> bool:
        """
        Retreive visualrf status
        :return:
        """
        # https://{{host}}/visualrf/site.xml
        url = "{base_url}/visualrf/site.xml".format(base_url=self.base_url)
        payload = {}
        headers = {}

        try:
            r = self.session.get(
                url=url, headers=headers, params=payload, verify=self.ssl_verify
            )
        except requests.exceptions as e:
            print("Error calling VisualRF API... Exception {}".format(e))
            Nagios.exit_code("UNKNOWN")

        if "Service Unavailable" in r.content.decode():
            return False
        elif xmltodict.parse(r.content)["visualrf:sites"]["@version"]:
            return True
        else:
            print("Error calling VisualRF status API")
            Nagios.exit_code("UNKNOWN")


# Get Options/Arguments then Run Script ###############################################################################
def check_ap_version(
    __firmware: str, __name: str, __model: str, __critical: int, __output: str
) -> Tuple[str, int]:
    __countcrit = 0

    pattern = re.compile(__critical)

    # if __firmware != str(__critical):
    if not pattern.match(__firmware):
        __countcrit = __countcrit + 1

    __output = "{output}Access point {a_name} ({a_model}) : {a_firmware},".format(
        output=__output,
        a_name=__name,
        a_model=__model,
        a_firmware=__firmware,
    )

    return __output, __countcrit


def main():
    global output
    global perf
    global countwarning
    global countcritical
    parser = ArgumentParser(
        prog="check_airwave.py",
        description="Nagios plugin used to monitor Aruba Airwave controller",
        formatter_class=RawTextHelpFormatter,
        epilog="Author: {author}, version: {version} (Copyright {copyright}), licence: {licence}".format(
            author=__author__,
            version=__version__,
            copyright=__copyright__,
            licence=__license__,
        ),
    )
    parser.add_argument(
        "-H",
        "--hostaddress",
        help="Airwave controller host address",
        type=str,
        required=True,
    )
    parser.add_argument(
        "-p",
        "--port",
        help="Airwave controller port number",
        type=int,
        default=443,
        required=False,
    )
    parser.add_argument(
        "-U",
        "--api-username",
        help="Airwave controller API username",
        type=str,
        required=True,
    )
    parser.add_argument(
        "-P",
        "--api-password",
        help="Airwave controller api password",
        type=str,
        required=True,
    )
    parser.add_argument(
        "-S",
        "--ignore-ssl-check",
        help="Ignore SSL certificate verification",
        action="store_true",
        required=False,
    )
    parser.add_argument(
        "-T",
        "--type",
        help="""
        Check type to perform :
        - folders : Check AP status in folders (Require subtypes usage)
        - alerts : Check Airwave controller alerts
        - ap : Check AP informations (Require subtypes usage)
        - visualrf : Check VisualRF module status
        """,
        choices=["folders", "alerts", "ap", "visualrf"],
        type=str,
        required=True,
    )
    parser.add_argument(
        "-s",
        "--subtype",
        help="""
        Check subtype to perform :
        - Folders
            - clients : Check folders global connected clients (Require -w and -c to define thresholds)
            - bw : Check folders global bandwidth (No threshold to define)
            - mismatch : Check AP in mismatch (Require -w and -c to define thresholds)
            - apstatus : Check global access points status in folder (Require -w and -c to define thresholds)
        - AP
            - clients : Check clients on access points Virtual Controller (Require -w and -c to define thresholds)
            - new : Check new access point pending approval (Require -w and -c to define, and REQUIRE Access Point approval right in Airwave)
            - version : Check AP version (Require -c option to specify target version as regexp — Example '8.10.0.*')

        """,
        choices=["clients", "bw", "mismatch", "version", "apstatus", "new"],
        type=str,
        required=False,
    )
    parser.add_argument(
        "-e",
        "--exclude",
        help="Exclude specified in plugin output as regexp",
        type=str,
        required=False,
    )
    parser.add_argument(
        "-u",
        "--up",
        help="Only for subtype AP Version, filter only on active access points",
        action="store_true",
        required=False,
    )
    parser.add_argument(
        "-w", "--warning", help="Warning threshold", type=int, required=False
    )
    parser.add_argument("-c", "--critical", help="Critical threshold", required=False)
    args = parser.parse_args()

    if args.ignore_ssl_check:
        ssl_verify = False
    else:
        ssl_verify = True

    output = ""
    perf = ""
    countwarning = 0
    countcritical = 0

    nagios = Nagios(output=output, perf=perf)
    airwave = Airwave(host=args.hostaddress, port=args.port, ssl_verify=ssl_verify)
    airwave_session = airwave.login(
        username=args.api_username,
        password=args.api_password,
    )

    # Execute check for type folders
    if args.type.upper() == "FOLDERS":
        folders_datas = ""
        folders_list = airwave.get_folders()

        # Execute subtype check for clients
        if args.subtype and args.subtype.upper() == "CLIENTS":
            if isinstance(folders_list, list):
                for folder in folders_list:
                    f_name = folder["name"]
                    f_client_count = int(folder["client_count"])

                    if f_client_count >= int(args.warning):
                        if f_client_count >= int(args.critical):
                            countcritical = countcritical + 1
                        else:
                            countwarning = countwarning + 1

                    if not args.exclude or not re.search(args.exclude, folder["name"]):
                        output = (
                            "{output}, Folder {f_name} - Clients : {f_client_count}".format(
                                output=output,
                                f_name=f_name,
                                f_client_count=f_client_count,
                            )
                        )
                    perf = "{perf}clients_{f_name}={f_client_count};{warning};{critical} ".format(
                        perf=perf,
                        f_name=f_name,
                        f_client_count=f_client_count,
                        warning=args.warning,
                        critical=args.critical,
                    )
            else:
                f_name = folders_list["name"]
                f_client_count = int(folders_list["client_count"])

                if f_client_count >= int(args.warning):
                    if f_client_count >= int(args.critical):
                        countcritical = countcritical + 1
                    else:
                        countwarning = countwarning + 1

                if not args.exclude or not re.search(args.exclude, folders_list["name"]):
                    output = (
                        "{output}, Folder {f_name} - Clients : {f_client_count}".format(
                            output=output,
                            f_name=f_name,
                            f_client_count=f_client_count,
                        )
                    )
                perf = "{perf}clients_{f_name}={f_client_count};{warning};{critical} ".format(
                    perf=perf,
                    f_name=f_name,
                    f_client_count=f_client_count,
                    warning=args.warning,
                    critical=args.critical,
                )
        # Execute subtype check for bandwidth
        elif args.subtype and args.subtype.upper() == "BW":
            if isinstance(folders_list, list):
                for folder in folders_list:
                    f_name = folder["name"]
                    f_bandwidth_in = folder["bandwidth_in"]
                    f_bandwidth_out = folder["bandwidth_out"]

                    if not args.exclude or not re.search(args.exclude, folder["name"]):
                        output = "{output}, Folder {f_name} - Bandwidth in : {f_bandwidth_in} Bandwidth out : {f_bandwidth_out}".format(
                            output=output,
                            f_name=f_name,
                            f_bandwidth_in=f_bandwidth_in,
                            f_bandwidth_out=f_bandwidth_out,
                        )

                    perf = "{perf}bw_in_{f_name}={f_bandwidth_in};;;; bw_out_{f_name}={f_bandwidth_out};;;; ".format(
                        perf=perf,
                        f_name=f_name,
                        f_bandwidth_in=f_bandwidth_in,
                        f_bandwidth_out=f_bandwidth_out,
                    )
            else:
                f_name = folders_list["name"]
                f_bandwidth_in = folders_list["bandwidth_in"]
                f_bandwidth_out = folders_list["bandwidth_out"]

                if not args.exclude or not re.search(args.exclude, folders_list["name"]):
                    output = "{output}, Folder {f_name} - Bandwidth in : {f_bandwidth_in} Bandwidth out : {f_bandwidth_out}".format(
                        output=output,
                        f_name=f_name,
                        f_bandwidth_in=f_bandwidth_in,
                        f_bandwidth_out=f_bandwidth_out,
                    )

                perf = "{perf}bw_in_{f_name}={f_bandwidth_in};;;; bw_out_{f_name}={f_bandwidth_out};;;; ".format(
                    perf=perf,
                    f_name=f_name,
                    f_bandwidth_in=f_bandwidth_in,
                    f_bandwidth_out=f_bandwidth_out,
                )
        # Execute subtype check for mismatch AP in folder
        elif args.subtype and args.subtype.upper() == "MISMATCH":
            if isinstance(folders_list, list):
                for folder in folders_list:
                    f_name = folder["name"]
                    f_mismatch = int(folder["mismatch"])

                    if f_mismatch >= int(args.warning):
                        if f_mismatch >= int(args.critical):
                            countcritical = countcritical + 1
                        else:
                            countwarning = countwarning + 1

                    if not args.exclude or not re.search(args.exclude, folder["name"]):
                        output = (
                            "{output}, Folder {f_name} - Mismatch ap : {f_mismatch}".format(
                                output=output,
                                f_name=f_name,
                                f_mismatch=f_mismatch,
                            )
                        )
                    perf = "{perf}ap_mismatch_{f_name}={f_mismatch};{warning};{critical} ".format(
                        perf=perf,
                        f_name=f_name,
                        f_mismatch=f_mismatch,
                        warning=args.warning,
                        critical=args.critical,
                    )
            else:
                f_name = folders_list["name"]
                f_mismatch = int(folders_list["mismatch"])

                if f_mismatch >= int(args.warning):
                    if f_mismatch >= int(args.critical):
                        countcritical = countcritical + 1
                    else:
                        countwarning = countwarning + 1

                if not args.exclude or not re.search(args.exclude, folders_list["name"]):
                    output = (
                        "{output}, Folder {f_name} - Mismatch ap : {f_mismatch}".format(
                            output=output,
                            f_name=f_name,
                            f_mismatch=f_mismatch,
                        )
                    )
                perf = "{perf}ap_mismatch_{f_name}={f_mismatch};{warning};{critical} ".format(
                    perf=perf,
                    f_name=f_name,
                    f_mismatch=f_mismatch,
                    warning=args.warning,
                    critical=args.critical,
                )
        # No subtype execute global check
        elif args.subtype and args.subtype.upper() == "APSTATUS":
            if isinstance(folders_list, list):
                for folder in folders_list:
                    f_name = folder["name"]
                    f_up = int(folder["up"])
                    f_down = int(folder["down"])

                    total_ap_in_folder = f_up + f_down + int(folder["mismatch"])

                    if total_ap_in_folder > 0:
                        folder_pct_down = (f_down / total_ap_in_folder) * 100
                    else:
                        folder_pct_down = 0.0

                    if folder_pct_down >= float(args.warning):
                        if folder_pct_down >= float(args.critical):
                            countcritical = countcritical + 1
                        else:
                            countwarning = countwarning + 1

                    if not args.exclude or not re.search(args.exclude, folder["name"]):
                        output = (
                            "{output}, Folder {f_name} - Up : {f_up} Down: {f_down}".format(
                                output=output,
                                f_name=f_name,
                                f_up=f_up,
                                f_down=f_down,
                            )
                        )
                    perf = "{perf}ap_up_{f_name}={f_up};; ap_down_{f_name}={f_down};; pct_ap_down_{f_name}={f_pct_down};{warning};{critical} ".format(
                        perf=perf,
                        f_name=f_name,
                        f_up=f_up,
                        f_down=f_down,
                        f_pct_down=folder_pct_down,
                        warning=args.warning,
                        critical=args.critical,
                    )
            else:
                f_name = folders_list["name"]
                f_up = int(folders_list["up"])
                f_down = int(folders_list["down"])

                total_ap_in_folder = f_up + f_down + int(folders_list["mismatch"])

                if total_ap_in_folder > 0:
                    folder_pct_down = (f_down / total_ap_in_folder) * 100
                else:
                    folder_pct_down = 0.0

                if folder_pct_down >= float(args.warning):
                    if folder_pct_down >= float(args.critical):
                        countcritical = countcritical + 1
                    else:
                        countwarning = countwarning + 1

                if not args.exclude or not re.search(args.exclude, folders_list["name"]):
                    output = (
                        "{output}, Folder {f_name} - Up : {f_up} Down: {f_down}".format(
                            output=output,
                            f_name=f_name,
                            f_up=f_up,
                            f_down=f_down,
                        )
                    )
                perf = "{perf}ap_up_{f_name}={f_up};; ap_down_{f_name}={f_down};; pct_ap_down_{f_name}={f_pct_down};{warning};{critical} ".format(
                    perf=perf,
                    f_name=f_name,
                    f_up=f_up,
                    f_down=f_down,
                    f_pct_down=folder_pct_down,
                    warning=args.warning,
                    critical=args.critical,
                )
        nagios.out(warn=countwarning, crit=countcritical)

    if args.type.upper() == "AP":
        if args.subtype and args.subtype.upper() == "CLIENTS":
            aps_list = airwave.get_ap_list()
            for ap in aps_list:
                if ap["device_category"] != "controller":
                    ap_controller = next(
                        (sub for sub in aps_list if sub["@id"] == ap["controller_id"])
                    )
                    a_ctrl = ap_controller["name"]
                    a_clients = int(ap_controller["client_count"])
                    a_name = ap["name"]
                    a_model = ap["model"]["#text"]

                    if a_clients >= int(args.warning):
                        if a_clients >= int(args.critical):
                            countcritical = countcritical + 1
                        else:
                            countwarning = countwarning + 1

                    output = "{output}{controller_name} ({a_model}) - {ap_name} : {client_count},".format(
                        output=output,
                        controller_name=a_ctrl,
                        ap_name=a_name,
                        client_count=a_clients,
                        a_model=a_model,
                    )
                    perf = "{perf}clients_on_{controller_name}_{ap_name}={client_count};{warning};{critical} ".format(
                        perf=perf,
                        controller_name=a_ctrl,
                        ap_name=a_name,
                        client_count=a_clients,
                        warning=args.warning,
                        critical=args.critical,
                    )

        if args.subtype and args.subtype.upper() == "NEW":
            stats = airwave.get_stats()
            new_count = int(stats["new_count"])
            if new_count >= int(0):
                if new_count >= int(args.warning):
                    if new_count >= int(args.critical):
                        countcritical = countcritical + 1
                    else:
                        countwarning = countwarning + 1
                output = "Found {new_count} devices pending approval".format(
                    new_count=new_count
                )
            else:
                output = "No new devices pending"

            perf = "pending_access_point={new_count};{warning};{critical} ".format(
                new_count=new_count, warning=args.warning, critical=args.critical
            )

        if args.subtype and args.subtype.upper() == "VERSION":
            aps_list = airwave.get_ap_list()
            for ap in aps_list:
                if ap["device_category"] != "controller":
                    if args.up and ap["is_up"] != "false":
                        output, countcritical = check_ap_version(
                            __firmware=ap["firmware"].split("-")[0],
                            __model=ap["model"]["#text"],
                            __name=ap["name"],
                            __output=output,
                            __critical=args.critical,
                        )
                    elif not args.up:
                        output, countcritical = check_ap_version(
                            __firmware=ap["firmware"].split("-")[0],
                            __model=ap["model"]["#text"],
                            __name=ap["name"],
                            __output=output,
                            __critical=args.critical,
                        )
        nagios.out(warn=countwarning, crit=countcritical)

    if args.type.upper() == "ALERTS":
        alerts_datas = airwave.get_alerts()
        alerts_count = 0

        for alert in alerts_datas:
            if alert["message"]["@ascii_value"].strip() != "wlsxColdStart":
                if (
                    alert["severity"]["@ascii_value"].strip() == "Warning"
                    or alert["severity"]["@ascii_value"].strip() == "Minor"
                ):
                    alerts_count = alerts_count + 1
                    countwarning = countwarning + 1
                    output = "{output}{alert_message},".format(
                        output=output, alert_message=alert["message"]["#text"]
                    )
                elif (
                    alert["severity"]["@ascii_value"].strip() == "Critical"
                    or alert["severity"]["@ascii_value"].strip() == "Major"
                ):
                    alerts_count = alerts_count + 1
                    countcritical = countcritical + 1
                    output = "{output}{alert_message},".format(
                        output=output, alert_message=alert["message"]["#text"]
                    )

        perf = "{perf}alerts_count={alerts_count};; ".format(
            perf=perf, alerts_count=alerts_count
        )
        nagios.out(warn=countwarning, crit=countcritical)

    if args.type.upper() == "VISUALRF":
        if airwave.get_visualrf_status():
            output = "VisualRF is up and running,"
        else:
            countcritical = countcritical + 1
            output = "VisualRF is down"
        nagios.out(warn=countwarning, crit=countcritical)


if __name__ == "__main__":
    output = ""
    perf = ""
    countwarning = 0
    countcritical = 0
    main()
# EOF
