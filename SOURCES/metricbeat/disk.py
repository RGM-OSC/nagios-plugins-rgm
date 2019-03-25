#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
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

### AUTHOR :
  * Julien Dumarchey <jdumarchey@fr.scc.com>   START DATE :    Sep 04 08:00:00 2018 
              
### CHANGES :
  * VERSION   DATE    	   WHO                  					   DETAIL
  * 0.0.1     04Sep18      Julien Dumarchey <jdumarchey@fr.scc.com>    Initial version
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
    e1a = "   -> Get Disk space for machine srv3 only if monitored data is not anterior at 4 minutes (4: default value). Warning alert if Disk > 85%. Critical alert if Disk > 95%. \n"
    e1b = "      python disk.py -H srv3 -w 85 -c 95\n\n"
    e2a = "   -> Get Disk space for machine srv3 only if monitored data is not anterior at 2 minutes.\n"
    e2b = "      python disk.py -H srv3 -w 85 -c 95 -t 2\n\n"
    e3a = "   -> Get Disk space for machine srv3 with Verbose mode enabled.\n"
    e3b = "      python disk.py -H srv3 -w 85 -c 95 -v\n\n"
    e4a = "   -> Get Disk space for machine srv3 with Verbose mode enabled and only if monitored data is not anterior at 2 minutes. \n"
    e4b = "      python disk.py -H srv3 -w 85 -c 95 -t 2 -v\n"
    help_msg = o + V + h + H + t + w + c + v + e + e1a + e1b + e2a + e2b + e3a + e3b + e4a + e4b
    return help_msg

# Build ElasticSearch URL for generic API Call:
def generic_api_call():
    try:
        # Define ElasticSearch Features:
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
        # Sort / Request the Last 100 Items (in order to be able to handle until 25 Disks by Machine):
        response_list_size = "100"
        generic_payload.update( {"version":"true","size":""+response_list_size+""} )
        generic_payload.update( {"sort":[{"@timestamp":{"order":"desc","unmapped_type":"boolean"}}]} )
        generic_payload.update( {"_source":{"excludes":[]}} )
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

# Build a custom Payload for ElasticSearch (here: HTTP Request Body for getting Disk space values for a specified hostname):
def custom_api_payload(plugin_hostname,data_validity):
    try:
        # ElasticSearch Custom Variables:
        beat_name = plugin_hostname
        field_name = "system.filesystem.device_name"
        metricset_module = "system"
        metricset_name = "filesystem"
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

# Request a custom ElasticSearch API REST Call (here: Get space for all Disks with: Percentage Used, Quantity Used (GigaBytes), and Quantity Free (GigaBytes)):
def get_disk(plugin_hostname,data_validity,verbose):
    try:
        # Get prerequisites for ElasticSearch API:
        addr, header = generic_api_call()
        payload = custom_api_payload(plugin_hostname,data_validity)
        # Request the ElasticSearch API:
        results = requests.get(url=addr, headers=header, json=payload, verify=False)
        results_json = results.json()
        # Extract the "Total Hit" from results (= check if Disk Value has been returned):
        total_hit = int(results_json["hits"]["total"])
        # If request hits: find out how many Items are required to get space for all disks:
        if (total_hit != 0) :
            disks_names_list = []
            for index in (range(total_hit)) :
                disk_name = results_json["hits"]["hits"][index]["_source"]["system"]["filesystem"]["device_name"]
                if disk_name not in disks_names_list :
                    disks_names_list.append(disk_name)
                else :
                    resp_entries_range = int(index)
                    break
        # If request hits: for each Disk, extract results (Disk Values in %) and display Verbose Mode if requested in ARGS ; otherwise return a static code (0):
        disk_values_dic = {}
        if (total_hit != 0) and (verbose == "0") :
            for position in (range(resp_entries_range)) :
                disk_values_dic.update( {"disk_"+str(position)+"": []} )
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["device_name"])
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["mount_point"])
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["pct"] * (100),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["bytes"] / (1024*1024*1024),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["free"] / (1024*1024*1024),2)))
        elif (total_hit != 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            for position in (range(resp_entries_range)) :
                disk_values_dic.update( {"disk_"+str(position)+"": []} )
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["device_name"])
                disk_values_dic["disk_"+str(position)].append(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["mount_point"])
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["pct"] * (100),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["used"]["bytes"] / (1024*1024*1024),2)))
                disk_values_dic["disk_"+str(position)].append(float(round(results_json["hits"]["hits"][position]["_source"]["system"]["filesystem"]["free"] / (1024*1024*1024),2)))
        elif (total_hit == 0) and (verbose == "0") :
            disk_values_dic.update( {"0": [0, 0, 0, 0, 0]} )
        elif (total_hit == 0) and (verbose == "1") :
            print("## VERBOSE MODE - API REST HTTP RESPONSE: ##########################################")
            print(results_json)
            print("####################################################################################")
            disk_values_dic.update( {"0": [0, 0, 0, 0, 0]} )
        return total_hit, resp_entries_range, disk_values_dic
    except:
        print("Error calling \"get_disk\"...")
        sys.exit()

# Build Alerting lists (sorted by Severity with Disk Space used %) and Performance Data lists (sorted by Severity with: Disk Space used %, Quantity Used (GB), and Quantity Free (GB)) :
def build_alerting_list(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get Disk values:
        total_hit, resp_entries_range, disk_values_dic = get_disk(plugin_hostname,data_validity,verbose)
        #print("Debug - \"disk_values_dic\" -> "+str(disk_values_dic)+"")
        # Build Alerting dic and Performance Data dic:
        alerting_dic, perfdata_dic = {}, {}
        for index in range(resp_entries_range) :
            if total_hit != 0 and (disk_values_dic["disk_"+str(index)][2] >= critical_treshold) :
                alerting_dic.update( {"CRITICAL_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )
                perfdata_dic.update( {"CRITICAL_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            elif total_hit != 0 and (disk_values_dic["disk_"+str(index)][2]  >= warning_treshold and disk_values_dic["disk_"+str(index)][2] < critical_treshold) :
                alerting_dic.update( {"WARNING_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )    
                perfdata_dic.update( {"WARNING_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            elif total_hit != 0 and (disk_values_dic["disk_"+str(index)][2] < warning_treshold) :  
                alerting_dic.update( {"OK_"+str(index)+"": ""+str(disk_values_dic["disk_"+str(index)][1])+" : "+str(disk_values_dic["disk_"+str(index)][2])+"%"} )  
                perfdata_dic.update( {"OK_"+str(index)+"": " | 'Disk ("+str(disk_values_dic["disk_"+str(index)][1])+")'="+str(disk_values_dic["disk_"+str(index)][2])+"%;"+str(warning_treshold)+";"+str(critical_treshold)+""} )
            else:     
                alerting_dic.update( {"UNKNOWN_"+str(index)+"": "NA | NA"} ) 
                perfdata_dic.update( {"UNKNOWN_"+str(index)+"": "NA | NA"} ) 
        #print("Debug - \"alerting_dic\" -> "+str(alerting_dic)+"")
        #print("Debug - \"perfdata_dic\" -> "+str(perfdata_dic)+"")
        
        # Parse Alerting dic for storing System Information sorted by Severity in relevant lists:
        rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown = [], [], [], []
        rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, rgm_perfdata_unknown = [], [], [], []
        for index in range(resp_entries_range) :
            if ("UNKNOWN_"+str(index)+"") in alerting_dic :
                rgm_info_unknown.append(alerting_dic["UNKNOWN_"+str(index)+""])
                rgm_perfdata_unknown.append(perfdata_dic["UNKNOWN_"+str(index)+""])
            if ("CRITICAL_"+str(index)+"") in alerting_dic :
                rgm_info_critical.append(alerting_dic["CRITICAL_"+str(index)+""])
                rgm_perfdata_critical.append(perfdata_dic["CRITICAL_"+str(index)+""])
            if ("WARNING_"+str(index)+"") in alerting_dic :
                rgm_info_warning.append(alerting_dic["WARNING_"+str(index)+""])
                rgm_perfdata_warning.append(perfdata_dic["WARNING_"+str(index)+""])
            if ("OK_"+str(index)+"") in alerting_dic :
                rgm_info_ok.append(alerting_dic["OK_"+str(index)+""])
                rgm_perfdata_ok.append(perfdata_dic["OK_"+str(index)+""])
            
        # Prepare Performance Data to be return in a compliant format to RGM:
        rgm_perfdata_critical = str(rgm_perfdata_critical).replace("[\"", "").replace("\"]", "").replace("\", \"", "")
        rgm_perfdata_warning = str(rgm_perfdata_warning).replace("[\"", "").replace("\"]", "").replace("\", \"", "")
        rgm_perfdata_ok = str(rgm_perfdata_ok).replace("[\"", "").replace("\"]", "").replace("\", \"", "")

        # Return RGM System Information and Performance Data ready to display:
        return rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown, rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, rgm_perfdata_unknown

    except:
        print("Error calling \"build_alerting_list\"...")
        sys.exit()

# Display Disk space (System Information + Performance Data) in a format compliant with RGM expectations:
def rgm_disk_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose):
    try:
        # Get "ready to display" System Information and Performance Data:
        rgm_info_critical, rgm_info_warning, rgm_info_ok, rgm_info_unknown, rgm_perfdata_critical, rgm_perfdata_warning, rgm_perfdata_ok, rgm_perfdata_unknown = build_alerting_list(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
        # Return System Information + Performance Data in a format compliant with RGM expectations:
        if rgm_info_unknown:
            print("UNKNOWN: Disk space value has not been returned...")
            sys.exit(3)
        elif (rgm_info_critical) and (not rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 0 0\"")
            print("CRITICAL: "+str(rgm_info_critical)+""+str(rgm_perfdata_critical))
            sys.exit(2)
        elif (not rgm_info_critical) and (rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 1 0\"")
            print("WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_warning))
            sys.exit(1)
        elif (not rgm_info_critical) and (not rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 0 1\"")
            print("OK: "+str(rgm_info_ok)+""+str(rgm_perfdata_ok))
            sys.exit(0)
        elif (not rgm_info_critical) and (not rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 0 0\"")
            print("UNKNOWN: Disk space value has not been returned...")
            sys.exit(3)
        elif (rgm_info_critical) and (rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 1 1\"")
            print("CRITICAL: "+str(rgm_info_critical)+", WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_critical)+""+str(rgm_perfdata_warning))
            sys.exit(2)
        elif (rgm_info_critical) and (rgm_info_warning) and (not rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 1 0\"")
            print("CRITICAL: "+str(rgm_info_critical)+", WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_critical)+""+str(rgm_perfdata_warning))
            sys.exit(2)
        elif (not rgm_info_critical) and (rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"0 1 1\"")
            print("WARNING: "+str(rgm_info_warning)+""+str(rgm_perfdata_warning))
            sys.exit(1)
        elif (rgm_info_critical) and (not rgm_info_warning) and (rgm_info_ok):
            #print("Debug - \"rgm_disk_output\" -> Scenario: \"1 0 1\"")
            print("CRITICAL: "+str(rgm_info_critical)+""+str(rgm_perfdata_critical))
            sys.exit(2)
    except Exception:
        print("Error calling \"rgm_disk_output\"...")
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
        rgm_disk_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity is None and verbose == "true"):
        data_validity = "4"
        verbose = "1"
        rgm_disk_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity and verbose is None):
        verbose = "0"
        rgm_disk_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)
    elif (plugin_version != "true" or plugin_help != "true") and (data_validity and verbose):
        verbose = "1"
        rgm_disk_output(plugin_hostname,warning_treshold,critical_treshold,data_validity,verbose)

if __name__ == '__main__':
    main_parse_script_command(sys.argv[1:])

## EOF ####################################################################################################################