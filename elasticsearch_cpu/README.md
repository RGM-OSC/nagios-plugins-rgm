# elasticsearch_cpu

### DESCRIPTION :
  * Nagios plugin used to return machine "CPU (Total, User, System)" from ElasticSearch.
  * CPU values are pushed from MetricBeat agent installed on the monitored machine.
  * CPU resquest is handled by API REST againt ElasticSearch.

### USAGE:
  * Options:
    * -V: Plugin version.
    * -h: Plugin help.
    * -H: Hostname.
    * -w: Warning threshold (Percentage Unit).
    * -c: Critical threshold (Percentage Unit).
    * -t: Data validity timeout (in minutes). If Value used to calculate CPU is older than x minutes, plugin returns Unknown state. Default value: 4 minutes.
    * -v: Verbose.

### EXAMPLES: 
  * Get Total CPU for machine "srv3 only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Total CPU > 85%. Critical alert if Total CPU > 90 %.
    * python cpu.py -H srv3 -w 85 -c 90
  * Get Total CPU for machine "srv3 only if monitored data is not anterior at 2 minutes. 
    * python cpu.py -H srv3 -w 85 -c 90 -t 2
  * Get Total CPU for machine "srv3 with Verbose mode enabled.
    * python cpu.py -H srv3 -w 85 -c 90 -v
  * Get Total CPU for machine "srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 
    * python cpu.py -H srv3 -w 85 -c 90 -t 2 -v

