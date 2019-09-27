# elasticsearch_load

### DESCRIPTION :
  * Nagios plugin used to return machine "Load Average (1 minute, 5 minutes, 15 minutes)" from ElasticSearch.
  * Load Average values are pushed from MetricBeat agent installed on the monitored machine.
  * Load Average resquest is handled by API REST againt ElasticSearch.

### USAGE:
  * Options:
    * -V: Plugin version.
    * -h: Plugin help.
    * -H: Hostname.
    * -w: Warning threshold.
    * -c: Critical threshold.
    * -t: Data validity timeout (in minutes). If Value used to calculate Load Average is older than x minutes, plugin returns Unknown state. Default value: 4 minutes.
    * -v: Verbose.

### EXAMPLES: 
  * Get Load Average for machine "srv3 only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Load > 70%. Critical alert if Load > 80 %.
    * python load.py -H srv3 -w 70 -c 80
  * Get Load Average for machine "srv3 only if monitored data is not anterior at 2 minutes. 
    * python load.py -H srv3 -w 70 -c 80 -t 2
  * Get Load Average for machine "srv3 with Verbose mode enabled.
    * python load.py -H srv3 -w 70 -c 80 -v
  * Get Load Average for machine "srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 
    * python load.py -H srv3 -w 70 -c 80 -t 2 -v

