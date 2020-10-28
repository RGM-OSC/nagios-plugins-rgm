#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: expandtab ts=4 sw=4:

'''
DESCRIPTION :
  * Nagios plugin used to return machine "Disk space" from ElasticSearch.
  * Disk space values are pushed from MetricBeat agent installed on the monitored machine.
  * Disk resquest is handled by API REST againt ElasticSearch.

AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 04 11:00:00 2018
  * Eric Belhomme <ebelhomme@fr.scc.com>

CHANGES :
  * VERSION     DATE        WHO                                         DETAIL
  * 0.0.1       2018-09-04  Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
  * 1.0.1       2019-03-26  Eric Belhomme <ebelhomme@fr.scc.com>        replace getopts by argparse module
                                                                        code factorization & mutualization
  * 1.1.0       2019-04-04  Eric Belhomme <ebelhomme@fr.scc.com>        massive rewrite with list comprehension
                                                                        perfdata are absolute MB instead of percentage
  * 1.1.1       2019-08-14  Samuel Ronciaux <sronciaux@fr.scc.com>      change metricset variable name to metricbeat
                                                                        agent 7.2.x
  * 1.1.2       2019-09-30  Eric Belhomme <ebelhomme@fr.scc.com>        fix argument type casting to int for
                                                                        warning, critical, timeout
  * 1.1.3       2020-10-15  Eric Belhomme <ebelhomme@fr.scc.com>        add mountpoint filter feature
                                                                        add verbose flags
                                                                        add storage unit autodetection
'''

__author__ = "Julien Dumarchey, Eric Belhomme"
__copyright__ = "2018, SCC"
__credits__ = ["Julien Dumarchey", "Eric Belhomme"]
__license__ = "GPL"
__version__ = "1.1.3"
__maintainer__ = "Eric Belhomme"

# MODULES FEATURES ####################################################################################################

# Import the following modules:
import sys
import re
import argparse
import requests
import pprint
import math
from _rgmbeat import generic_api_call, generic_api_payload, get_data_validity_range, validate_elastichost

import urllib3
urllib3.disable_warnings()


class disk_cfg():

    def __init__(
        self,
        es_api_url,
        hostname,
        treshold_warning,
        treshold_critical,
        data_ttl,
        filter_pattern,
        filter_not_re,
        verbose_level,
        display_units,
    ):
        self.es_api_url = es_api_url
        self.hostname = hostname
        self.treshold_warning = treshold_warning
        self.treshold_critical = treshold_critical
        self.data_ttl = data_ttl
        self.filter_pattern = filter_pattern
        self.filter_not_re = filter_not_re
        self.verbose_level = verbose_level
        self.display_units = display_units


class Unit:
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")

    def __init__(self, cfg: disk_cfg, volume_used, volume_total):
        self.cfg = cfg
        self.volume_used = volume_used
        self.volume_total = volume_total

    def _get_value(self, value):
        if value == 0:
            return '0 B'
        i = 0
        if self.cfg.display_units in ['auto', '%']:
            i = int(math.floor(math.log(value, 1024)))
        else:
            i = self.__class__.size_name.index(self.cfg.display_units)
        p = math.pow(1024, i)
        s = round(value / p, 2)
        return "{} {}".format(s, self.__class__.size_name[i])

    def get_usage(self):
        return self._get_value(self.volume_used)

    def get_total(self):
        return self._get_value(self.volume_total)

    def get_free(self):
        return self._get_value(self.volume_total-self.volume_used)

    def get_usage_percent(self):
        return round((int(self.volume_used * 100)) / self.volume_total, 2)


cfg = None
NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')


def custom_api_payload(plugin_hostname, data_validity):
    '''
    Build a custom Payload for ElasticSearch
    here: HTTP Request Body for getting Disk space values for a specified hostname
    '''
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.filesystem.device_name"
        metricset_module = "system"
        metricset_name = "filesystem"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload(100)
        custom_payload = {}
        custom_payload.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update({"query": {"bool": {"must": [], "filter": [], "should": [], "must_not": []}}})
        custom_payload["query"]["bool"]["must"].append({"match_all": {}})
        custom_payload["query"]["bool"]["must"].append({"exists": {"field": ""+field_name+""}})
        custom_payload["query"]["bool"]["must"].append(
            {"match_phrase": {"event.module": {"query": ""+metricset_module+""}}}
        )
        custom_payload["query"]["bool"]["must"].append(
            {"match_phrase": {"metricset.name": {"query": ""+metricset_name+""}}}
        )
        custom_payload["query"]["bool"]["must"].append(
            {"match_phrase": {"host.name": {"query": ""+beat_name+""}}}
        )
        custom_payload["query"]["bool"]["must"].append(
            {"range": {"@timestamp": {
                "gte": ""+str(oldest_valid_timestamp)+"",
                "lte": ""+str(newest_valid_timestamp)+"",
                "format": "epoch_millis"
            }}}
        )
        return custom_payload
    except Exception as e:
        print("Error calling \"custom_api_payload\"... Exception {}".format(e))
        sys.exit(3)


def get_disk(cfg: disk_cfg):
    '''
    Request a custom ElasticSearch API REST Call
    here: Get space for all Disks with: Percentage Used, Quantity Used (GigaBytes), and Quantity Free (GigaBytes)
    '''
    def _list_append(item):
        return {
            'device_name': item['system']['filesystem']['device_name'],
            'mount_point': item['system']['filesystem']['mount_point'],
            'total': int(item['system']['filesystem']['total']),
            'free': int(item['system']['filesystem']['free']),
            'used': int(item['system']['filesystem']['used']['bytes'])
        }

    def _sort_fslist(element):
        return len(element['mount_point'])

    try:
        # Get prerequisites for ElasticSearch API:
        # resp_entries_range = 0
        addr, header = generic_api_call(cfg.es_api_url)
        payload = custom_api_payload(cfg.hostname, cfg.data_ttl)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        if cfg.verbose_level >= 3:
            pp = pprint.PrettyPrinter(indent=4)
            print("### VERBOSE MODE - API REST HTTP RESPONSE: #########################################")
            print("### request payload:")
            pp.pprint(payload)
            print("### JSON output:")
            pp.pprint(results_json)
            print("####################################################################################")

        if int(results_json["hits"]["total"]['value']) > 0:
            pattern = None
            if cfg.filter_pattern:
                if not cfg.filter_not_re:
                    pattern = re.compile(cfg.filter_pattern)
                else:
                    pattern = cfg.filter_pattern

            fslist = []
            # get a list of returned fs, then keep only latest item of each mountpoint
            allfslist = [i['_source'] for i in results_json['hits']['hits']]
            for fs in set([i['system']['filesystem']['mount_point'] for i in allfslist]):
                item = max(
                    [i for i in allfslist if i['system']['filesystem']['mount_point'] == fs],
                    key=lambda timestamp: timestamp['@timestamp']
                )
                if pattern and not cfg.filter_not_re:
                    if pattern.match(item['system']['filesystem']['mount_point']):
                        fslist.append(_list_append(item))
                elif pattern and cfg.filter_not_re:
                    if pattern == item['system']['filesystem']['mount_point']:
                        fslist.append(_list_append(item))
                else:
                    fslist.append(_list_append(item))

            return sorted(fslist, key=_sort_fslist)
        else:
            # no fs returned
            return False

    except Exception as e:
        print("Error calling \"get_disk\"... Exception {}".format(e))
        sys.exit(3)


def build_alerting_list(cfg: disk_cfg):
    '''
    Build Alerting lists (sorted by Severity with Disk Space used %) and
    Performance Data lists (sorted by Severity with: Disk Space used %, Quantity Used (GB), and Quantity Free (GB)) :
    '''
    try:
        # Get Disk values:
        ret = []
        fslist = get_disk(cfg)

        if isinstance(fslist, list):
            for item in fslist:
                item['warn_treshold_abs'] = (int(cfg.treshold_warning) * item['total']) / 100
                item['crit_treshold_abs'] = (int(cfg.treshold_critical) * item['total']) / 100
                item['nagios_status'] = 3

                if item['used'] >= item['crit_treshold_abs']:
                    item['nagios_status'] = 2
                elif item['used'] >= item['warn_treshold_abs']:
                    item['nagios_status'] = 1
                elif item['used'] < item['warn_treshold_abs']:
                    item['nagios_status'] = 0

                ret.append(item)
            return ret
        else:
            return False

    except Exception as e:
        print("Error calling \"build_alerting_list\"... Exception {}".format(e))
        sys.exit(3)


def byte2mbyte(bytes):
    return int(bytes/(1024*1024))


def rgm_disk_output(cfg: disk_cfg):
    '''
    Display Disk space (System Information + Performance Data) in a format compliant with RGM expectations:
    '''
    try:
        nagios_status = 3
        fslist = build_alerting_list(cfg)
        outtext = []
        outperf = []
        if isinstance(fslist, list):
            nagios_status = max(fslist, key=lambda status: status['nagios_status'])['nagios_status']
            if nagios_status != 0:
                crit = [i['mount_point'] for i in fslist if i['nagios_status'] == 2]
                if len(crit) > 0:
                    outtext.append("{} mountpoints in CRITICAL state ({}%): {}".format(
                        str(len(crit)),
                        str(cfg.treshold_critical),
                        ", ".join(crit)))
                warn = [i['mount_point'] for i in fslist if i['nagios_status'] == 1]
                if len(warn) > 0:
                    outtext.append("{} mountpoints in WARNING state ({}%): {}".format(
                        str(len(warn)),
                        str(cfg.treshold_warning),
                        ", ".join(warn)))
            else:
                outtext.append("All mountpoints in OK state ({}%, {}%)".format(
                    int(cfg.treshold_warning),
                    int(cfg.treshold_critical)
                ))

            def strip_mount(mount):
                if len(mount) > 1:
                    return mount.rstrip(' /\\')
                return mount

            for item in fslist:

                if cfg.verbose_level > 0:
                    value = Unit(cfg, item['used'], item['total'])
                    text = "\n {} - {} - {}% used".format(
                        strip_mount(item['mount_point']),
                        value.get_usage(),
                        value.get_usage_percent()
                    )
                    if cfg.verbose_level > 1:
                        text += " (total: {}, free: {})".format(
                            value.get_total(),
                            value.get_free()
                        )
                    outtext.append(text)

                outperf.append("'{label}'={value}MB;{warn};{crit};0;{total}".format(
                    label=item['mount_point'],
                    value=str(byte2mbyte(item['used'])),
                    warn=str(byte2mbyte(item['warn_treshold_abs'])),
                    crit=str(byte2mbyte(item['crit_treshold_abs'])),
                    total=str(byte2mbyte(item['total']))
                ))
        else:
            print("{}: no output returned for time period ({} min)".format(NagiosRetCode[nagios_status], cfg.data_ttl))

        print("{}: {} | {}".format(
            NagiosRetCode[nagios_status],
            " ".join(outtext),
            " ".join(outperf)
        ))
        sys.exit(nagios_status)

    except Exception as e:
        print("Error calling \"rgm_disk_output\"... Exception {}".format(e))
        sys.exit(3)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        description="""
        Nagios plugin used to return machine "Disk space" from ElasticSearch.
        Disk space values are pushed from MetricBeat agent installed on the monitored machine.
        Disk resquest is handled by API REST againt ElasticSearch.
        """,
        usage="""
        Get Disk space for machine "srv3" only if monitored data is not anterior at 4 minutes
        (4: default value). Warning alert if Disk > 85%%. Critical alert if Disk > 95%%.

            disk.py -H srv3 -w 85 -c 95

        Get Disk space for machine "srv3" only if monitored data is not anterior at 2 minutes.

            disk.py -H srv3 -w 85 -c 95 -t 2

        Get Disk space for machine "srv3" with Verbose mode enabled.

            disk.py -H srv3 -w 85 -c 95 -v

        Get Disk space for machine "srv3" with Verbose mode enabled and only if monitored data
        is not anterior at 2 minutes.

            disk.py -H srv3 -w 85 -c 95 -t 2 -v

        Filter returned mountpoints (using a regexp pattern)

            disk.py -H srv3 -w 85 -c 95 -t 2 -m '^/var/.*'

        Filter returned mountpoint (using a matching pattern)

            disk.py -H srv3 -w 85 -c 95 -t 2 -r -m '^/var/.*'

        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    _help_verbose = """verbose output level:
0: single line, minimal output. Summary
1: multi line, display mountpoint basic informations
2: multi line, display mountpoint extended informations
3: ES raw output for debug purpose only"""
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger', default=85)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger', default=95)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=4)
    parser.add_argument(
        '-E', '--elastichost', type=str, help='connection URL of ElasticSearch server',
        default="http://localhost:9200"
    )
    parser.add_argument('-v', '--verbose', type=int, help=_help_verbose, choices=[0, 1, 2, 3], default=0)
    parser.add_argument(
        '-u', '--unit', help='Display in unit',
        choices=list(Unit.size_name + ('auto', '%')), default='auto'
    )
    parser.add_argument('-m', '--name', type=str, help='mountpoint filter', default=r'.*')
    parser.add_argument(
        '-r', '--noregexp', action='store_true',
        help='do not use regexp for mountpoint filtering', default=False
    )
    args = parser.parse_args()

    if validate_elastichost(args.elastichost):
        cfg = disk_cfg(
            es_api_url=args.elastichost,
            hostname=args.hostname,
            treshold_warning=args.warning,
            treshold_critical=args.critical,
            data_ttl=args.timeout,
            filter_pattern=args.name,
            filter_not_re=args.noregexp,
            verbose_level=args.verbose,
            display_units=args.unit
        )
        rgm_disk_output(cfg)
    else:
        print("can't validate elastic host")

# EOF
