#!/usr/bin/env perl
#
# Nagios plugin for functional sharepoint monitoring
#
# License: GPL v3
# Author: Michael van den Berg
#
# Copyright (c) 2012 PCS-IT Services B.V. (www.pcs-it.nl)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use Getopt::Long qw(:config no_ignore_case_always auto_version);
use Switch;
use WWW::Curl::Easy;
use strict 'vars';

our $VERSION = 1.2;
(my $script_name = $0) =~ s/.\///;

# Help message
my $help_info = <<END;
\n$script_name v$VERSION
Copyright (c) 2012 PCS-IT Services B.V. (www.pcs-it.nl)

Usage: $script_name -H <hostname> -u <username> -p <password>
            -w [warn time] -c [crit time] -t [timeout]
            -s [search string] -l [path] -v -form -http
END

# Extra option information
my $help_extra = <<END;

Nagios script for checking of SharePoint web services

Options:
-H      Address or hostname of SharePoint site (required)
-u      Username (required)
-p      Password (required)
-w      Warning threshold in seconds
-c      Critical threshold in seconds
-t      Connection timeout in seconds (default is 60 seconds)
-s      Search for custom string on page
-l      Specific location or path instead of site root
-v      Verbose. HTTP headers in output. 2x (-v -v) includes HTML. 3x both
-form   Use forms based authentication (default is ntlm)
-http   Connect via standard http (default is https)

Examples:
Check site behind a TMG server using forms based authentication with warning and critital times
  $script_name -H portal.hostname.com -u username -p password -form -w 5 -c 10

Check site with integtrated authentication at a specific location within the site
  $script_name -H portal.hostname.com -u username -p password -l '/Sites/Wiki%20Pages/default.aspx'

Check site with integtrated authentication that contins the string 'random string'
  $script_name -H portal.hostname.com -u username -p password -s 'random string'

Notes:
- If you use special characters in your usernames and/or passwords, authentication will  
  have a better chance of working if you enclose them in quotes.
- If a URL path is included using the -l option it is must be encoded (e.g. - /Wiki%20Pages/default.aspx)
- Connections are always assumed to be https unless the -http option is used
- Forms authentication is always assumed to be via a ISA/TMG server.
- libcurl must have NTML listed in its features in order for integrated (NTML) authentication 
  to work. Runing 'curl-config --features' will show if this is present. 

END

# Nagios exit codes
my $OKAY = 0;
my $WARNING = 1;
my $CRITICAL = 2;
my $UNKNOWN = 3;

# Default values
my $result = $UNKNOWN;              # Default exit code 
my $message = "Status UNKNOWN";     # Default output to nagios

my $timeout = 60;
my $address;
my $encoded_path;
my $verbose_level = 0;

# The meta tag 'GENERATOR' is used to determine a successful Shrepoint page loaded. (IIS header field is not used - it shows even on failures)
my $search_string = "<meta name=\"GENERATOR\" content=\"Microsoft SharePoint\" \/>"; 

# Command arguments
GetOptions ('H=s'    => \my $host,         # required
            'u=s'    => \my $username,     # required
            'p=s'    => \my $password,     # required
            'w:i'    => \my $warn,
            'c:i'    => \my $crit,
            's:s'    => \$search_string,
            'l:s'    => \my $site_path,    # Assume that the supplied path is already URI encoded (e.g. - space = %20, etc)
            't:i'    => \$timeout,
            'version|V' => \my $show_version,
            'v+'      => \$verbose_level,
            'form'   => \my $forms_auth,
            'http'   => \my $http,
            'help|?' => \my $help_message);

# If we don't have the required command line arguments, exit with UNKNOWN.
if(defined $show_version){
    print STDOUT "$script_name $VERSION\n";
    exit $UNKNOWN;
}elsif((!defined $host || !defined $username || !defined $password) && !defined $help_message){
    print STDOUT "$script_name: Not all required options were supplied.\n$help_info\ntry: '$script_name -help' for more information\n";
    exit $UNKNOWN;
}elsif(defined $help_message){
    print STDOUT "$help_info \n $help_extra";
    exit $UNKNOWN
}

# Check that libcurl has ntlm support - if it isn't and forms is not use, quit with UNKNOWN
my $curl_features = `curl-config --features`;
my $ntlm_present = ($curl_features =~ m/NTLM/) ? 1 : 0;

if (!defined $forms_auth && !$ntlm_present){
    print STDOUT "UNKNOWN: libcurl lacks ntlm support\n";
    exit $UNKNOWN;
}

my $proto = (!defined $http) ? "https" : "http";     # https is the default protocol

# Build up curl
my $curl = WWW::Curl::Easy->new;
$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
$curl->setopt(CURLOPT_USERAGENT, 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0)'); # MS is funny about supported browsers sometimes..
$curl->setopt(CURLOPT_SSL_VERIFYPEER, 0);   # Don't do any SSL checking, just keep going (even on bad certs)
$curl->setopt(CURLOPT_CONNECTTIMEOUT, $timeout);
$curl->setopt(CURLOPT_TIMEOUT, $timeout);

# Auth type is ntlm by default
if(!defined $forms_auth){ 
    $address = (defined $site_path) ? $host . $site_path : $host;
    $curl->setopt(CURLOPT_URL, $proto.'://'.$address);
    $curl->setopt(CURLOPT_HTTPAUTH, CURLAUTH_NTLM);
    $curl->setopt(CURLOPT_USERNAME, $username);
    $curl->setopt(CURLOPT_PASSWORD, $password);
}else{
    # Form authentication assumes a reverse proxy via ISA/TMG server. Submission will be using post method, with 
    # the 'from public computer' option, and '/' for the target page after logon if no location is supplied.
    $address = $host . $site_path;
    if(defined $site_path){
        ($encoded_path = $site_path) =~ s/([^A-Za-z0-9.])/sprintf("Z%02X", ord($1))/seg;  # Encode the location for redirect after logon (in special MS format)
    }else{
        $encoded_path = "Z2F";   # Default to site root if no custom location supplied
    }
    $curl->setopt(CURLOPT_URL, $proto.'://'.$host.'/CookieAuth.dll?Logon');
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_POSTFIELDS, 'curl='.$encoded_path.'&flags=0&forcedownlevel=0&trusted=0&username='.$username.'&password='.$password.'&SubmitCreds=Log+On');
    $curl->setopt(CURLOPT_COOKIEJAR, '/dev/null');
}


# returned html body for parsing (libcurl returns a file reference..)
my $response_body = '';
open(my $file_body, ">", \$response_body);
$curl->setopt(CURLOPT_WRITEDATA,$file_body);

# Now we execute the actual loading of the sharepoint website
my $retcode = $curl->perform;
my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
my $total_time = $curl->getinfo(CURLINFO_TOTAL_TIME);

# Perfdata will have page load times in seconds
my $perfdata = "|'Response Time'=$total_time"."s;$warn;$crit;0"; 

if ($retcode == 0) {
    # Parse return data on http success since 200 doesn't always mean it everything went well
    if ($response_code == 200){
        switch($response_body){
            case m/id=\"password\" onfocus=\"g_fFcs=0\"/ {  # Forms auth will return 200 and the form again on a failure
                $message = "CRITICAL: Authentication failed for account '$username'\n";
                $result = $CRITICAL;   
            }
            case m/$search_string/{  # We look for the default sharepoint search string (or supplied custom one) to gauge if the site loaded
                if($response_body =~ m/Error: Access Denied/){  
                    # Logon was successful but the user account supplied doesn't rights within sharepoint to view the site page
                    $message = "CRITICAL: Access denied for user '$username' (no site permissions).\n";
                    $result = $CRITICAL;                    
                }elsif((defined $warn && $total_time >= $warn && $total_time < $crit) || (defined $warn && !defined $crit && $total_time >= $warn)){ 
                    # Page load was successful but load time exceeded warning threshold
                    $message = "WARNING: '$proto://$address' polled in $total_time seconds$perfdata\n";
                    $result = $WARNING;
                }elsif(defined $crit && $total_time >= $crit){
                    # Page load was successful but load time exceeded crititcal threshold
                    $message = "CRITICAL: $proto://$address' polled in $total_time seconds$perfdata\n";
                    $result = $CRITICAL;
                }else{
                    # Page load was successful and within required load times
                    $message = "OK: '$proto://$address' polled in $total_time seconds$perfdata\n";
                    $result = $OKAY;
                }
            }
            else{
                # The site loaded but the identifying search string (or sharepoint default content meta data tag) was not found.
                $message = "CRITICAL: Identifying search string '$search_string' not found!\n";
                $result = $CRITICAL;   
            }
        }
    }else{
        # Standard http response codes made to nagios friendly output. If something isn't in the list then spit out a generic error
        switch($response_code){
            case 400{
                $message = "CRITICAL: HTTP 400 Error - Bad request at '$proto://$address'\n";
                $result = $CRITICAL;    
            }
            case 401{
                # Usually an NTML authentication failure, but not always (ntlm could be missing from libcurl)
                $message = "CRITICAL: Authentication failed for account '$username'\n";
                $result = $CRITICAL;
            }
            case 403{
                $message = "CRITICAL: HTTP 403 Error - forbidden at '$proto://$address'\n";
                $result = $CRITICAL ;           
            }
            case 404{
                $message = "CRITICAL: HTTP 404 Error - Page not found '$proto://$address'\n";
                $result = $CRITICAL;
            }
            case 500{
                $message = "CRITICAL: HTTP 500 Error - Internal server error at '$proto://$address'\n";
                $result = $CRITICAL ;           
            }
            else{
                $message = "CRITICAL: Unknown error connecting to '$proto://$address'\n";
                $result = $CRITICAL;
            }
        }
    }

} else { 
    # Curl failures (DNS lookup failure, timeout, etc. These will always crit
    $message = "CRITICAL: ".$curl->strerror($retcode)." for '$proto://$address'\n";
    $result = $CRITICAL;
    if($verbose_level > 0){ # verbose
        $message = $message . $curl->strerror($retcode)." (".$curl->errbuf.")\n";
    }
}

## Verbose ##

if($verbose_level > 0 && $retcode == 0){
    # Get the body + header and split them
    $response_body =~ /<!DOCTYPE/;   # Really hope everyone has that <!DOCTYPE at the top so we know where the header ends and the HTML starts
    my $header_end_pos = $+[0];
    my $http_headers = substr $response_body,9,($header_end_pos - 19);
    my $html_body = substr $response_body, ($header_end_pos - 2);
    
    # Tack the html and/or header on depended on the verbose level
    if($verbose_level == 1){$message = $message . "\n***** Begin HTTP Headers *****\n" . $http_headers . "***** End HTTP Headers *****\n\n";} 
    if($verbose_level == 2){$message = $message . "\n***** Begin HTML *****\n" . $html_body . "\n***** End HTML Body *****\n\n";}
    if($verbose_level == 3){
        $message = $message . "\n***** Begin HTTP Headers *****\n" . $http_headers . "***** End HTTP Headers *****" .
                              "\n***** Begin HTML *****\n" . $html_body . "\n***** End HTML Body *****\n\n";
    }
    
}

# Cleanup
undef $curl;

#Exit with output and Nagios exit code
print STDOUT $message;
exit $result;

#EOF