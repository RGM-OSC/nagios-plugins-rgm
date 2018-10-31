# elasticsearch_uptime

### DESCRIPTION :
  * Nagios plugin used to return machine "Uptime" from ElasticSearch.
  * Uptime is pushed from MetricBeat agent installed on the monitored machine.
  * Uptime resquest is handle by API REST againt ElasticSearch.

### USAGE:
  * Options:
    * -V: Plugin version.
    * -h: Plugin help.
    * -H: Hostname.
    * -w: Warning threshold.
    * -c: Critical threshold.
    * -t: Data validity timeout (in minutes). If Value used to calculate Uptime is older than x minutes, plugin returns Unknown state. Default value: 4 minutes. 
    * -v: Verbose.

### EXAMPLES: 
  * Get Uptime for machine "srv3 only if monitored data is not anterior at 4 minutes (4m: default value). Warning alert if Uptime < 10 minutes. Critical alert if Uptime < 5 minutes.
    * python uptime.py -H srv3 -w 10 -c 5
  * Get Uptime for machine "srv3 only if monitored data is not anterior at 2 minutes. 
    * python uptime.py -H srv3 -w 10 -c 5 -t 10
  * Get Uptime for machine "srv3 with Verbose mode enabled.
    * python uptime.py -H srv3 -w 10 -c 5 -v
  * Get Uptime for machine "srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 
    * python uptime.py -H srv3 -w 10 -c 5 -t 2 -v


