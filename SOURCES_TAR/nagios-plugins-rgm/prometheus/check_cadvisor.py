#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION :
  Nagios plugin for cAdvisor through Prometheus

AUTHOR :
  Eric Belhomme <ebelhomme@fr.scc.com>

CHANGES :
  0.0.1       2022-12-20  Eric Belhomme <ebelhomme@fr.scc.com>        Initial version
'''

__author__ = "Eric Belhomme"
__copyright__ = "2022, SCC"
__credits__ = [__author__]
__license__ = "GPL"
__version__ = "0.0.1"
__maintainer__ = __author__


# Import the following modules:
import sys, re, sre_parse
#if sys.version_info.minor <= 6:
#    from sre_parse import Pattern as rePattern
#else:
#    from re import Pattern as rePattern
import argparse
import requests
import urllib
import time, datetime
import enum
#from ast import literal_eval
import logging
import pprint
pp = pprint.PrettyPrinter()

logger = logging


def bytes_human_readable(num: int) -> str:
    suffix="B"
    for unit in ["", "Ki", "Mi", "Gi"]:
        if abs(num) < 1024.0:
            return f"{num:3.1f}{unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f}Ti{suffix}"

def time_human_readable(seconds: int) -> str:
    return str(datetime.timedelta(seconds=seconds))

def percent_human_readable(value: str) -> str:
    return "{}%".format(round(value,2))


class NagiosAdditionStrategies(enum.Enum):
    ADD = 1
    MIN = 2
    MAX = 3


class NagiosItem():
    _objects_ = list()
    _perf_suffix = None

    @classmethod
    def instances(cls):
        return cls._objects_

    @classmethod
    def __iter__(cls) -> any:
        cls._iterator = 0
        return cls._objects_[cls._iterator]

    @classmethod
    def __next__(cls) -> any:
        if cls._iterator < len(cls._objects_):
            cls._iterator += 1
            return cls._objects_[cls._iterator]
        else:
            raise StopIteration

    @classmethod
    def get(cls, podname):
        for item in cls._objects_:
            if item.podname == podname:
                return item
        return None

    def __init__(self, podname, addition_strategy=NagiosAdditionStrategies.ADD) -> None:
        self.podname = podname
        self.value = 0.0
        self.perf_prefix = ''
        self.addition_strategy = addition_strategy
        NagiosItem._objects_.append(self)

    def addValue(self, value: float):
        if self.addition_strategy == NagiosAdditionStrategies.ADD:
            self.value += value
        elif self.addition_strategy == NagiosAdditionStrategies.MIN and self.value > value:
            self.value = value
        elif self.addition_strategy == NagiosAdditionStrategies.MAX and self.value < value:
            self.value = value

    def setPerfName(self, label):
        self.perf_prefix = label

    @classmethod
    def clGetPerfName(cls, prefix) -> str:
        name = prefix
        if NagiosItem._perf_suffix:
            name += '_' + NagiosItem._perf_suffix
        return name

    def getPerfName(self) -> str:
        return NagiosItem.clGetPerfName(self.perf_prefix)

class NagiosPerf():

    def __init__(self) -> None:
        pass

    def getLabel(self, **kwargs):
        return ''


class NagiosPerfStr(NagiosPerf):

    def __init__(self, label) -> None:
        super().__init__()
        if label is not None:
            self.label = label
        else:
            self.label = PrometheusLabel.get(
                'container_label_io_kubernetes_pod_namespace'
            ).value

    def getLabel(self, **kwargs):
        return self.label


class NagiosPerfRE(NagiosPerf):

    def __init__(self, pod_pattern, perf_pattern) -> None:
        super().__init__()
        defpattern = r'^([a-z-]+)-.*'
        if perf_pattern is None:
            logger.info("no perf pattern provided, applying default pattern '{}'".format(defpattern))
            reperf = re.compile(defpattern)
        else:
            reperf = re.compile(perf_pattern)
            if reperf.groups < 1:
                logger.error("Nagios perf regexp pattern (--perf) '{}' does *not* contains any capture group !".format(perf_pattern))
                sys.exit(Nagios.NAGIOS_UNKNOWN)
        repod = re.compile(pod_pattern)
        self.pattern = reperf
        if perf_pattern is None:
            if repod.groups >=1:
                self.pattern = repod
            else:
                logger.warning('unable to extrapolate a RE match group from pod pattern')

    def getLabel(self, **kwargs):
        if 'pod' not in kwargs.keys():
            logger.error('pod key not found !')
            return 'unknown'
        rmatch = self.pattern.match(kwargs['pod'])
        if rmatch:
            return rmatch.group(1)
        else:
            logger.error('no perf pattern provided, and was not able to extrapolate one from pod pattern')
            sys.exit(Nagios.NAGIOS_UNKNOWN)


class Nagios():
    NAGIOS_OK = 0
    NAGIOS_WARNING = 1
    NAGIOS_CRITICAL = 2
    NAGIOS_UNKNOWN = 3
    _status_code = (NAGIOS_OK, NAGIOS_WARNING, NAGIOS_CRITICAL, NAGIOS_UNKNOWN)
    _status_text = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')
    aggregators = ['none', 'sum', 'avg']

    @classmethod
    def helpAggregators(cls) -> str:
        return (
            'none: no aggregator. All pods will return nagios perfs each\n'
            'sum: all pods are summarized in a unique perf value\n'
            'avg: all pods are averaged in a unique perf value'
        )

    @classmethod
    def getStatusCode(cls, text):
        if text not in cls._status_text:
            return cls.NAGIOS_UNKNOWN
        return cls._status_code[cls._status_text.index(text)]

    @classmethod
    def getStatusText(cls, code):
        if code not in cls._status_code:
            code = cls.NAGIOS_UNKNOWN
        return cls._status_text[code]

    @classmethod
    def noFormatter(cls, text):
        return text

    def __init__(self, aggregate, perf) -> None:
        self.aggregate = aggregate
        if aggregate == 'none':
            self.perf = NagiosPerfRE(
                pod_pattern=PrometheusLabel.get('container_label_io_kubernetes_pod_name').value,
                perf_pattern=perf
            )
        else:
            self.perf = NagiosPerfStr(perf)
        self.statusCode = Nagios.NAGIOS_UNKNOWN
        self.header = ''
        self.header_title = ''
        self.value = ''
        self.revert_status = False

    def setStatus(self, status):
        if status == Nagios.NAGIOS_CRITICAL:
            self.statusCode = Nagios.NAGIOS_CRITICAL
        elif status == Nagios.NAGIOS_WARNING and (self.statusCode == Nagios.NAGIOS_UNKNOWN or self.statusCode < Nagios.NAGIOS_CRITICAL):
            self.statusCode = Nagios.NAGIOS_WARNING
        elif status == Nagios.NAGIOS_OK and (self.statusCode == Nagios.NAGIOS_UNKNOWN or self.statusCode < Nagios.NAGIOS_WARNING):
            self.statusCode = Nagios.NAGIOS_OK

    def checkStatus(self, value):
        if self.revert_status:
            if value <= self.critical:
                self.setStatus(Nagios.NAGIOS_CRITICAL)
            elif value <= self.warning:
                self.setStatus(Nagios.NAGIOS_WARNING)
            elif value > self.warning:
                self.setStatus(Nagios.NAGIOS_OK)
        else:
            if value >= self.critical:
                self.setStatus(Nagios.NAGIOS_CRITICAL)
            elif value >= self.warning:
                self.setStatus(Nagios.NAGIOS_WARNING)
            elif value < self.warning:
                self.setStatus(Nagios.NAGIOS_OK)

    def setHeaders(self, title, callback_value_formatter=noFormatter):
        self.header_title = title
        self.header_callback_value_formatter = callback_value_formatter

    def getHeaders(self):
        if self.value is None:
            return self.header_title
        else:
            value = self.header_callback_value_formatter(self.value)
        return "{title} {value}".format(
            title=self.header_title,
            value=value,
        )

    def setThresolds(self, warning, critical, min, max):
        self.warning = warning
        self.critical = critical
        self.perf_min = min
        self.perf_max = max

    def aggregator_none(self):
        perf = []
        self.value = None
        for item in NagiosItem.instances():
            self.checkStatus(item.value)
            item.setPerfName(self.perf.getLabel(pod=item.podname))
            perf.append(
                "{kp};{va};{wa};{cr};{mi};{ma}".format(
                    kp = item.getPerfName(),
                    va = round(float(item.value),2),
                    wa = self.warning,
                    cr = self.critical,
                    mi = self.perf_min,
                    ma = self.perf_max,
                )
            )
        if len(perf):
            return '|' + '\n'.join(perf)

    def aggregator_sum(self):
        perf = ''
        self.value = 0.0
        if len(NagiosItem.instances()) > 0:
            for item in NagiosItem.instances():
                self.value += item.value
            self.checkStatus(self.value)
            perf = "|{kp};{va};{wa};{cr};{mi};{ma}".format(
                kp = NagiosItem.clGetPerfName(self.perf.getLabel()),
                va = round(float(item.value),2),
                wa = self.warning,
                cr = self.critical,
                mi = self.perf_min,
                ma = self.perf_max,
            )
        return perf

    def aggregator_avg(self):
        perf = ''
        self.value = 0.0
        if len(NagiosItem.instances()) > 0:
            for item in NagiosItem.instances():
                self.value += item.value
            self.value = self.value/len(NagiosItem.instances())
            self.checkStatus(self.value)
            perf = "|{kp};{va};{wa};{cr};{mi};{ma}".format(
                kp = NagiosItem.clGetPerfName(self.perf.getLabel()),
                va = round(float(item.value),2),
                wa = self.warning,
                cr = self.critical,
                mi = self.perf_min,
                ma = self.perf_max,
            )
        return perf

    def __str__(self) -> str:
        perf = None
        output = ''
        if self.aggregate == 'none':
            perf = self.aggregator_none()
        elif self.aggregate == 'sum':
            perf = self.aggregator_sum()
        elif self.aggregate == 'avg':
            perf = self.aggregator_avg()
        if len(NagiosItem.instances()):
            output = "{status} - {header} in {pods} pods".format(
                status=Nagios.getStatusText(self.statusCode),
                header=self.getHeaders(),
                pods= len(NagiosItem.instances())
            )
            output += '\n'
            output += '\n'.join(
                [
                    "pod '{}': {}".format(i.podname, self.header_callback_value_formatter(i.value))
                    for i in NagiosItem.instances()
                ]
            )
            if perf:
                output += '\n' + perf
        else:
            output = "{status} - {header} returned empty results...".format(
                status=Nagios.getStatusText(self.statusCode),
                header=self.getHeaders(),
            )
        return output


class PrometheusLabel():
    _objects_ = list()

    def __init__(self, key: str, value: str, operator: str) -> None:
        self.key = key
        self.value = value
        self.operator = operator
        PrometheusLabel._objects_.append(self)

    def __str__(self) -> str:
        return '{}{}"{}"'.format(
            self.key,
            self.operator,
            self.value,
        )

    def isValueDefined(self) -> bool:
        if len(self.value):
            return True
        return False

    @classmethod
    def instances(cls):
        return cls._objects_

    @classmethod
    def get(cls, label):
        for item in cls._objects_:
            if label == item.key:
                return item
        return None

    @classmethod
    def getLabels(cls):
        return ",".join(['{}'.format(i) for i in cls.instances() if i.isValueDefined()])

    @classmethod
    def __iter__(cls) -> any:
        cls._iterator = 0
        return cls._objects_[cls._iterator]

    @classmethod
    def __next__(cls) -> any:
        if cls._iterator < len(cls._objects_):
            cls._iterator += 1
            return cls._objects_[cls._iterator]
        else:
            raise StopIteration


class Prometheus():

    def __init__(self, apiurl, interval) -> None:
        self.result_values = 'value'
        self.apiURL = apiurl
        self.interval_step = interval
        self.interval_end = int(time.time())
        self.interval_start = self.interval_end - self.interval_step

    def start(self) -> str:
        return str(self.interval_start)

    def end(self) -> str:
        return str(self.interval_end)

    def step(self) -> str:
        return str(self.interval_step)

    def buildURL(self, api_endpoint: str, query: str, args='') -> str:
        '''
        The `query` string shall contain `{}`, which will be replaced by PrometheusLabel class instances
        eg.: 'sum(rate(container_cpu_usage_seconds_total{}))'
        will be expanded to, for example:
          'sum(rate(container_cpu_usage_seconds_total{container_label_io_kubernetes_pod_name=~"harbor-.*"}))'
        '''
        if api_endpoint.startswith('/query_range'):
            self.result_values = 'values'

        if query.find('{}') > -1:
            query = query.replace('{}', '{' + PrometheusLabel.getLabels() + '}')
        ret = "{h}{e}{q}{a}".format(
            h = self.apiURL,
            e = api_endpoint,
            q = urllib.parse.quote(query),
            a = args
        )
        logger.debug("request URI: {}".format(ret))
        return ret

    def request(self, url: str, retdef=-1.0) -> float:
        try:
            # Request the Prometheus API
            response = requests.get(url=url)
            if response.status_code >= 300:
                logger.error('API failure: HTTP status code {}'.format(response.status_code))
                logger.debug('error was: {}'.format(response.text))
                sys.exit(Nagios.NAGIOS_UNKNOWN)
            response_json = response.json()
            logger.debug("JSON output: {}".format(response_json))
            if response_json['data']['result']:
                # Get the last metric available
                return response_json['data']['result'] 
#                return float(response_json['data']['result'][-1][self.result_values][-1][1])
            else:
                return []
        except Exception as e:
            print("Error calling request... Exception {}".format(e))
            sys.exit(Nagios.NAGIOS_UNKNOWN)


def sanitize_thresold_percent(thresold: any, defaults: float, name: str):
    if thresold is None:
        logger.warning("no value for thresold {}. Returning defaults '{}'".format(name, defaults))
        return defaults
    elif thresold < 0.0 or thresold > 100.0:
        logger.error("thresold for {} is out of bounds (0..100)".format(name))
        sys.exit(Nagios.NAGIOS_UNKNOWN)
    return float(thresold)


def sanitize_thresold_float(thresold: any, defaults: float, name: str):
    if thresold is None:
        logger.warning("no value for thresold {}. Returning defaults '{}'".format(name, defaults))
        return defaults
    return float(thresold)


def sanitize_thresold_bytes(thresold: str or None, defaults: int, name: str):
    regex = re.compile(r'^\d+[bBkKmMgGtT]$')
    if thresold is None:
        logger.warning("no value for thresold {}. Returning defaults '{}'".format(name, defaults))
        return defaults
    elif regex.match(thresold):
        thresold = thresold.upper()
        if thresold.endswith('B'):
            return int(thresold[:-1])
        elif thresold.endswith('K'):
            return int(thresold[:-1]) * 1024
        elif thresold.endswith('M'):
            return int(thresold[:-1]) * 1024 * 1024
        elif thresold.endswith('G'):
            return int(thresold[:-1]) * 1024 * 1024 * 1024
        elif thresold.endswith('T'):
            return int(thresold[:-1]) * 1024 * 1024 * 1024 * 1024
    elif int(thresold) > 0:
        return int(thresold)
    else:
        logger.warning("unknown value for thresold {}. Returning defaults '{}'".format(name, defaults))
        return defaults


def container_cpu_usage_seconds_total(nagios: Nagios, prom: Prometheus, warning: any, critical: any):
    # cpu
    NagiosItem._perf_suffix = 'cpu'
    warning = sanitize_thresold_percent(float(warning), 80.0, 'warning')
    critical = sanitize_thresold_percent(float(critical), 95.0, 'critical')
    nagios.setHeaders('CPU usage', percent_human_readable)
    nagios.setThresolds(warning, critical, 0, 100)
    uri = prom.buildURL(
        api_endpoint='/query_range?query=',
        query='rate(container_cpu_usage_seconds_total{{}}[{}s])'.format(prom.step()),
        args="&start=" + prom.start() + "&end=" + prom.end() + "&step=" + prom.step(),
    )
    results = prom.request(uri)
    if len(results) == 0:
        logger.error('prometheus request return empty results')
        return

    for metric in results:
        nagiositem = NagiosItem.get(metric['metric']['container_label_io_kubernetes_pod_name'])
        if not nagiositem:
            nagiositem = NagiosItem(metric['metric']['container_label_io_kubernetes_pod_name'])
        nagiositem.addValue(float(metric['values'][-1][1]))


def container_memory_usage_bytes(nagios: Nagios, prom: Prometheus, warning: any, critical: any):
    # memoire
    NagiosItem._perf_suffix = 'memory'
    warning = sanitize_thresold_bytes(warning, 104857600, 'warning')
    critical = sanitize_thresold_bytes(critical, 209715200, 'critical')
    nagios.setHeaders('Memory usage', bytes_human_readable)
    nagios.setThresolds(warning, critical, 0, 0)
    uri = prom.buildURL(
        api_endpoint='/query_range?query=',
        query='container_memory_usage_bytes{}',
        args="&start=" + prom.start() + "&end=" + prom.end() + "&step=" + prom.step(),
    )
    results = prom.request(uri)
    if len(results) == 0:
        logger.error('prometheus request return empty results')
        return

    for metric in results:
        nagiositem = NagiosItem.get(metric['metric']['container_label_io_kubernetes_pod_name'])
        if not nagiositem:
            nagiositem = NagiosItem(metric['metric']['container_label_io_kubernetes_pod_name'])
        nagiositem.addValue(float(metric['values'][-1][1]))


def container_fs_io_time_seconds_total(nagios: Nagios, prom: Prometheus, warning: any, critical: any):
    '''
    This measures the cumulative count of seconds spent doing I/Os.
    It can be used as a baseline to judge the speed of the processes
    running on your container, and help advise future optimization efforts.‍
    '''
    NagiosItem._perf_suffix = 'io'
    warning = sanitize_thresold_bytes(warning, 104857600, 'warning')
    critical = sanitize_thresold_bytes(critical, 209715200, 'critical')
    nagios.setHeaders('IO usage', time_human_readable)
    nagios.setThresolds(warning, critical, 0, 0)
    uri = prom.buildURL(
        api_endpoint='/query_range?query=',
        query='rate(container_fs_io_time_seconds_total{{}}[{}s])'.format(prom.step()),
        args="&start=" + prom.start() + "&end=" + prom.end() + "&step=" + prom.step(),
    )
    results = prom.request(uri)
    if len(results) == 0:
        logger.error('prometheus request return empty results')
        return

    for metric in results:
        nagiositem = NagiosItem.get(metric['metric']['container_label_io_kubernetes_pod_name'])
        if not nagiositem:
            nagiositem = NagiosItem(metric['metric']['container_label_io_kubernetes_pod_name'])
        nagiositem.addValue(float(metric['values'][-1][1]))


def container_start_time_seconds(nagios: Nagios, prom: Prometheus, warning: any, critical: any):
    # uptime
    NagiosItem._perf_suffix = 'uptime'
    warning = sanitize_thresold_bytes(warning, 300, 'warning')
    critical = sanitize_thresold_bytes(critical, 30, 'critical')
    nagios.setHeaders('Uptime', time_human_readable)
    nagios.setThresolds(warning, critical, 0, 0)
    nagios.revert_status = True
    epoch_now = int(time.time())
    uri = prom.buildURL(
        api_endpoint='/query_range?query=',
        query='container_start_time_seconds{}',
        args="&start=" + prom.start() + "&end=" + prom.end() + "&step=" + prom.step(),
    )
    results = prom.request(uri)
    if len(results) == 0:
        logger.error('prometheus request return empty results')
        return

    for metric in results:
        nagiositem = NagiosItem.get(metric['metric']['container_label_io_kubernetes_pod_name'])
        if not nagiositem:
            nagiositem = NagiosItem(metric['metric']['container_label_io_kubernetes_pod_name'], NagiosAdditionStrategies.MAX)
        nagiositem.addValue(float(epoch_now - int(metric['values'][-1][1])))


if __name__ == '__main__':

    logging.basicConfig()
    logger = logging.getLogger(__name__)
    logger.setLevel(level=logging.INFO)

    parser = argparse.ArgumentParser(
        description="Nagios plugin for cAdvisor through Prometheus",
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__),
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument('-H', '--prometheus', type=str, help='connection URL to Prometheus server', default="http://localhost:9090")
    parser.add_argument(
        '-m', '--mode', nargs='?', type=lambda s: s.lower(),
        choices=['throttle', 'cpu', 'load', 'io', 'memory', 'process', 'uptime'], default='WARNING',
        help='cAdvisor metric check\n'
            '* throttle (container_cpu_cfs_throttled_seconds_total)\n'
            ' - This measures the total amount of time a certain container has been throttled. Generally,\n'
            '   container CPU usage can be throttled to prevent a single busy container from essentially\n'
            '   choking other containers by taking away all the available CPU resources.\n'
            '   Throttling is usually a good way to ensure a minimum processing power is available for\n'
            '   essential services on all running containers. This metric measures the total time that\n'
            '   a container’s CPU usage was throttled, and observing this provides the information one\n'
            '   needs to properly reallocate resources to specific containers. This can be done, for example,\n'
            '   by adjusting the setting for CPU shares in Docker.\n'
            ' - throttles: warning & critical throttles are exprimed as...\n'
            '* cpu (container_cpu_usage_seconds_total)\n'
            ' - throttles: warning & critical throttles are exprimed as percentage\n'
            '* load (container_cpu_load_average_10s)\n'
            '  This measures the value of the container CPU load average over the last 10 seconds.\n'
            '  Monitoring CPU usage is vital for ensuring it is being used effectively. It would also give\n'
            '  insight into what container processes are compute-intensive, and as such, help advise\n'
            '  future CPU allocation.\n'
            '* io (container_fs_io_time_seconds_total)\n'
            '  This measures the cumulative count of seconds spent doing I/Os. It can be used as\n'
            '  a baseline to judge the speed of the processes running on your container,\n'
            '  and help advise future optimization efforts\n'
            '* memory (container_memory_usage_bytes)\n'
            ' - This measures the current memory usage, including all memory regardless of when it was accessed.\n'
            '   Tracking this on a per-container basis keeps you informed of the memory footprint of the processes\n'
            '   on each container while aiding future optimization or resource allocation efforts.\n'
            ' - throttles: warning & critical throttles are exprimed as bytes.\n'
            '* process (container_processes)\n'
            '  This metric keeps track of the number of processes currently running inside the container.\n'
            '  Knowing the exact state of our containers at all times is essential in keeping them up and running.\n'
            '  As such, knowing how many processes are currently running in a specific container would provide\n'
            '  insight into whether things are functioning normally, or whether there’s something wrong.\n'
            '* uptime (container_start_time_seconds)\n'
    )
    parser.add_argument('-p', '--pod', type=str, help='k8s pod name (regexp)', required=True)
    parser.add_argument('-n', '--namespace', type=str, help='k8s namespace', default='')
    parser.add_argument('-l', '--label', type=str, help='k8s label (regexp)', default='')
    parser.add_argument(
        '-r', '--perf', type=str, default=None,
        help='pattern for Nagios perf labelling\n'
            "* if 'none' aggregator selected, it is a regexp applied on pod name.\n"
            '  The RE *MUST* contain a RE capture group\n'
            '  see https://docs.python.org/3/howto/regex.html#grouping\n'
            "* if *any aggregator* selected, the pattern is applied as is, or defaults\n"
            '  to --pod value (expunged from RE patterns)'
    )
    parser.add_argument(
        '-a', '--aggregate', nargs='?', type=lambda s: s.lower(),
        choices=Nagios.aggregators, default=Nagios.aggregators[0],
        help="aggregates Nagios perfs with aggregator function (defaults to '{}'):\n".format(
            Nagios.aggregators[0]
        ) + Nagios.helpAggregators()
    )
    parser.add_argument('-w', '--warning', type=str, nargs='?', help='warning trigger threshold (defaults depends of mode)', default=None)
    parser.add_argument('-c', '--critical', type=str, nargs='?', help='critical trigger threshold (defaults depends of mode)', default=None)
    parser.add_argument('-i', '--interval', type=int, help='time interval (in seconds) to start check - default to 1min', default=60)
    parser.add_argument(
        '-v', '--verbose', nargs='?', help='log level verbosity', type=lambda s: s.upper(),
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], default='WARNING'
    )
    args = parser.parse_args()
    logger.setLevel(level=getattr(logging, args.verbose, None))

    PrometheusLabel('container_label_io_kubernetes_pod_name', args.pod, '=~')
    PrometheusLabel('container_label_io_kubernetes_pod_namespace', args.namespace, '=')
    PrometheusLabel('container_label_name', args.label, '=~')
    nagios = Nagios(args.aggregate, args.perf)
    prom = Prometheus("{}/prometheus/api/v1".format(args.prometheus), args.interval)

    if args.mode == 'throttle':
        pass
    elif args.mode == 'cpu':
        container_cpu_usage_seconds_total(nagios, prom, args.warning, args.critical)
    elif args.mode == 'load':
        pass
    elif args.mode == 'io':
        container_fs_io_time_seconds_total(nagios, prom, args.warning, args.critical)
    elif args.mode == 'memory':
        container_memory_usage_bytes(nagios, prom, args.warning, args.critical)
    elif args.mode == 'process':
        pass
    elif args.mode == 'uptime':
        container_start_time_seconds(nagios, prom, args.warning, args.critical)
    else:
        logger.error("unknown mode: {}".format(args.mode))

    print(nagios)
    sys.exit(nagios.statusCode)
#EOF
