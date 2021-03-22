# elasticsearch_disk

### DESCRIPTION :
  * Nagios plugin used to return machine "Disk space" from ElasticSearch.
  * Disk space values are pushed from MetricBeat agent installed on the monitored machine.
  * Disk resquest is handled by API REST againt ElasticSearch.

### USAGE:
  * Options:
    * -V: Plugin version.
    * -h: Plugin help.
    * -H: Hostname.
    * -w: Warning threshold (Percentage Unit).
    * -c: Critical threshold (Percentage Unit).
    * -t: Data validity timeout (in minutes). If data returned to calculate Disk space is older than x minutes, plugin returns Unknown state. Default value: 4 minutes.
    * -v: Verbose.

### EXAMPLES: 
  * Get Disk space for machine "srv3" only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Disk > 85%. Critical alert if Disk > 95 %.
    * python disk.py -H srv3 -w 85 -c 95
  * Get Disk space for machine "srv3" only if monitored data is not anterior at 2 minutes. 
    * python disk.py -H srv3 -w 85 -c 95 -t 2
  * Get Disk space for machine "srv3" with Verbose mode enabled.
    * python disk.py -H srv3 -w 85 -c 95 -v
  * Get Disk space for machine "srv3" with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. 
    * python disk.py -H srv3 -w 85 -c 95 -t 2 -v
