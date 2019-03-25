# -*- coding: utf8 -*-

'''
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

### AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 03 08:30:00 2018 
              
### CHANGES :
  * VERSION   DATE    	   WHO                  					   DETAIL
  * 0.0.1     03Sep18      Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
'''

## MODULES FEATURES #######################################################################################################

# Import the following modules:
import getopt, sys, requests, json, time

# If required, disable SSL Warning Logging for "requests" library:
#requests.packages.urllib3.disable_warnings()

## Declare Functions ######################################################################################################

# Display Plugin Version:
def display_version():
    current_version = "1.0.0"
    current_version_msg = "Version is: \"" +current_version+ "\""
    return current_version_msg

# Display Plugin Help:
def display_help():
    o = "\nOPTIONS:\n"
    V = "   -V: Plugin version.\n"
    h = "   -h: Plugin help.\n"
    H = "   -H: Hostname.\n"
    t = "   -t: Plugin timeout. Default value: 4 minutes. Expected unit: m (minute), s (second).\n"
    w = "   -w: Warning threshold (Percentage Unit).\n"
    c = "   -c: Critical threshold (Percentage Unit).\n"
    v = "   -v: Verbose.\n\n"
    e = "EXAMPLES:\n"
    e1a = "   -> Get Total CPU for machine srv3 only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Total CPU > 85%. Critical alert if Total CPU > 90 %. \n"
    e1b = "      python cpu.py -H srv3 -w 85 -c 90\n\n"
    e2a = "   -> Get Total CPU for machine srv3 only if monitored data is not anterior at 2 minutes.\n"
    e2b = "      python cpu.py -H srv3 -w 85 -c 90 -t 2\n\n"
    e3a = "   -> Get Total CPU for machine srv3 with Verbose mode enabled.\n"
    e3b = "      python cpu.py -H srv3 -w 85 -c 90 -v\n\n"
    e4a = "   -> Get Total CPU for machine srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. \n"
    e4b = "      python cpu.py -H srv3 -w 85 -c 90 -t 2 -v\n"
    help_msg = o + V + h + H + t + w + c + v + e + e1a + e1b + e2a + e2b + e3a + e3b + e4a + e4b
    return help_msg

# Build ElasticSearch URL for generic API Call:
def generic_api_call():
    try:
        # Define ElasticSearch features:
        ip = "192.168.140.50"
        proto = "http"
        port = "9200"
        # Build URL:
        addr = proto+"://"+ip+":"+port+"/_search"
        # Build HEADER:
        header = {'Content-Type': 'application/json'}
        return addr, header
    except:
        print("Error calling \"generic_api_call\"...")
        sys.exit()

# Build a generic Payload for ElasticSearch:
def generic_api_payload():
    try:
        generic_payload = {}
        # Sort / Request the Last Item:
        response_list_size = "1"
        generic_payload.update( {"version":"true","size":""+response_list_size+""} )
        generic_payload.update( {"sort":[{"@timestamp":{"order":"desc","unmapped_type":"boolean"}}]} )
        # Add Exclusion capability if needed later:
        generic_payload.update( {"_source":{"excludes":[]}} )
        return generic_payload
    except:
        print("Error calling \"generic_api_payload\"...")
        sys.exit()

# Return a range of time between 2x Epoch-Millisecond Timestamps:
def get_data_validity_range(data_validity):
    try:
        newest_valid_timestamp = int(round(time.time() * 1000))
        data_validity_ms = ( int(data_validity) * 60 * 1000 )
        oldest_valid_timestamp = ( newest_valid_timestamp - data_validity_ms )
        return newest_valid_timestamp, oldest_valid_timestamp
    except:
        print("Error calling \"get_data_validity_range\"...")
        sys.exit()

## Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting an CPU values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.cpu.total.pct"
        metricset_module = "system"
        metricset_name = "cpu"
        # Get Data Validity Epoch Timestamp:
        newest_valid_timestamp, oldest_valid_timestamp = get_data_validity_range(data_validity)
        # Build the generic part of the API Resquest Body:
        generic_payload = generic_api_payload()
        custom_payload = {}
        custom_payload.update(generic_payload)
        # Add the Query structure with ElasticSearch Variables:
        custom_payload.update( {"query":{"bool":{"must":[],"filter":[],"should":[],"must_not":[]}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_all":{}} )
        custom_payload["query"]["bool"]["must"].append( {"exists":{"field":""+field_name+""}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.module":{"query":""+metricset_module+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"metricset.name":{"query":""+metricset_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"match_phrase":{"beat.name":{"query":""+beat_name+""}}} )
        custom_payload["query"]["bool"]["must"].append( {"range":{"@timestamp":{"gte":""+str(oldest_valid_timestamp)+"","lte":""+str(newest_valid_timestamp)+"","format":"epoch_millis"}}} )
        return custom_payload
    except:
        print("Error calling \"custom_api_payload\"...")
        sys.exit()

## Request a custom ElasticSearch API REST Call (here: Get CPU in percentage):
def get_cpu(plugin_hostname,data_validity,verbose):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call()
        payload = custom_api_payload(plugin_hostname,data_validity)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        # Extract the "Total Hit" from results (= check if CPU Value has been returned):
        total_hit = int(results_json["hits"]["total"])
        # If request hits: extract results (CPU Values in %) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        if (total_hit != 0) and (verbose == "0") :
            cpu_nb = int(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["cores"])
            cpu_total = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["total"]["pct"]) * 100) / cpu_nb
            cpu_user = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["user"]["pct"]) * 100) / cpu_nb
            cpu_system = float(float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["system"]["pct"]) * 100) / cpu_nb
        elif (total_hit != 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            cpu_nb = int(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["cores"])
            cpu_total = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["total"]["pct"]) * 100
            cpu_user = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["user"]["pct"]) * 100
            cpu_system = float(results_json["hits"]["hits"][0]["_source"]["system"]["cpu"]["system"]["pct"]) * 100
        elif (total_hit == 0) and (verbose == "0") :
            cpu_total, cpu_user, cpu_system = 0, 0, 0
        elif (total_hit == 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            cpu_total, cpu_user, cpu_system = 0, 0, 0
        return total_hit, cpu_total, cpu_user, cpu_system
    except:
        print("Error calling \"get_cpu\"...")
        sys.exit()

## Display CPU (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_cpu_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get CPU values:
        total_hit, cpu_total, cpu_user, cpu_system = get_cpu(plugin_hostname,data_validity,verbose)
        # Parse value for Alerting returns:
        if total_hit != 0 and cpu_total >= critical_treshold:
            print("CRITICAL - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(2)
        elif total_hit != 0 and cpu_total >= warning_treshold and cpu_total < critical_treshold:
            print("WARNING - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(1)
        elif total_hit != 0 and cpu_total < warning_treshold:
            print("OK - Total CPU is: "+str(round(cpu_total,2))+"% (User CPU is: "+str(round(cpu_user,2))+"%, System CPU is: "+str(round(cpu_system,2))+"%) | 'Total CPU (%)'="+str(round(cpu_total,2))+";"+str(warning_treshold)+";"+str(critical_treshold)+"")
            sys.exit(0)
        else:
            print("UNKNOWN: CPU has not been returned...")
            sys.exit(3)
    except Exception:
        print("Error calling \"rgm_cpu_output\"...")
        sys.exit(3)

## Get Options/Arguments then Run Script ##################################################################################

def main_parse_script_command(argv):

    # Define Variables:
    try:
        plugin_version
        plugin_help
        data_validity
        plugin_hostname
        warning_treshold
        critical_treshold
        plugin_verbose
    except NameError:
        plugin_version = None
        plugin_help = None
        data_validity = None
        plugin_hostname = None
        warning_treshold = None
        critical_treshold = None
        verbose = None

    # Get Options and Arguments:
    try:
        options, arguments = getopt.getopt(argv,"VhH:w:c:t:v",["version","help","hostname=","warning=","critical=","timeout=","verbose"])
    except getopt.GetoptError:
        print("Options:")
        print("  -V: Plugin version.")
        print("  -h: Plugin help.")
        print("  -H: Hostname.")
        print("  -w: Warning threshold (Percentage Unit).")
        print("  -c: Critical threshold (Percentage Unit).")
        print("  -t: Plugin timeout. Default value: 4 minutes. Expected unit: m (minute), s (second).")
        print("  -v: Verbose.")
        sys.exit()

    # Parsing + Sanity tests for Options and Arguments:
    for opt, arg in options:
        if opt in ("-V", "--version"):
            plugin_version = "true"
        elif opt in ("-h", "--help"):
            plugin_help = "true"
        elif opt in ("-H", "--hostname"):
            try:
                plugin_hostname = str(arg)
            except ValueError:
                print("ERROR: Use a STRING value for option: \"" +opt+ "\"")
        elif opt in ("-w", "--warning"):
            try:
                warning_treshold = int(arg)
            except ValueError:
                print("ERROR: Use an INTEGER value for option: \"" +opt+ "\"")
        elif opt in ("-c", "--critical"):
            try:
                critical_treshold = int(arg)
            except ValueError:
                print("ERROR: Use an INTEGER value for option: \"" +opt+ "\"")
        elif opt in ("-t", "--timeout"):
            try:
                data_validity = int(arg)
            except ValueError:
                print("ERROR: Use an INTEGER value for option: \"" +opt+ "\"")
        elif opt in ("-v", "--verbose"):
            verbose = "true"

    # Run script depending Options/Arguments:
    if (len(sys.argv)) > 10:
        print("ERROR - Too much arguments/options!!")
    elif (len(sys.argv)) < 2:
        help_msg = display_help()
        print(help_msg)
    elif plugin_version == "true":
        version_msg = display_version()
        print(version_msg)
    elif plugin_help == "true":
        help_msg = display_help()
        print(help_msg)
    elif (plugin_version != "true" or plugin_help != "true") and plugin_hostname is None:
        print("ERROR: Please specify a valid Hostname...")  
    elif (plugin_version != "true" or plugin_help != "true") and warning_treshold is None:
        print("ERROR: Please specify a Warning threshold...") 
    elif (plugin_version != "true" or plugin_help != "true") and critical_treshold is None:
        print("ERROR: Please specify a Critical threshold...") 
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity is None and verbose is None):
        data_validity = "4"
        verbose = "0"
        rgm_cpu_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity is None and verbose == "true"):
        data_validity = "4"
        verbose = "1"
        rgm_cpu_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity and verbose is None):
        verbose = "0"
        rgm_cpu_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity and verbose):
        verbose = "1"
        rgm_cpu_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)

if __name__ == '__main__':
    main_parse_script_command(sys.argv[1:])

## EOF ####################################################################################################################