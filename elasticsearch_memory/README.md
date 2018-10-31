# elasticsearch_memory

### DESCRIPTION :
  * Nagios plugin used to return machine "Memory (1 minute, 5 minutes, 15 minutes)" from ElasticSearch.
  * Memory values are pushed from MetricBeat agent installed on the monitored machine.
  * Memory resquest is handled by API REST againt ElasticSearch.

### USAGE:
  * Options:
    * -V: Plugin version.
    * -h: Plugin help.
    * -H: Hostname.
    * -w: Warning threshold (Percentage Unit).
    * -c: Critical threshold (Percentage Unit).
    * -t: Data validity timeout (in minutes). If Value used to calculate Memory is older than x minutes, plugin returns Unknown state. Default value: 4 minutes.
    * -v: Verbose.

### EXAMPLES: 
  * Get Memory for machine "srv3 only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Memory > 85%. Critical alert if Memory > 95 %.
    * python memory.py -H srv3 -w 85 -c 95
  * Get Memory for machine "srv3 only if monitored data is not anterior at 2 minutes. 
    * python memory.py -H srv3 -w 85 -c 95 -t 2
  * Get Memory for machine "srv3 with Verbose mode enabled.
    * python memory.py -H srv3 -w 85 -c 95 -v
  * Get Memory for machine "srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 
    * python memory.py -H srv3 -w 85 -c 95 -t 2 -v


