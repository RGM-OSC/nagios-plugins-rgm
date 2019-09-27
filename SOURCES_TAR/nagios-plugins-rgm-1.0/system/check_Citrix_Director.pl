#!/usr/bin/perl
# michael.aubertin@gmail.com
# Release under GPL V2
# Check Citrix Director
#
# Released with the courtesy of Airbus Group and Vinci Group for EyesOfNetwork OpenSource project :)
#
use strict;
use warnings;

use LWP::UserAgent;
use LWP::Authen::Ntlm;
use LWP::Debug qw(+);
use HTTP::Cookies;
use XML::XPath;
use XML::XPath::XMLParser;
use Getopt::Long;
use URI::Escape;

# To comment after debug
use Data::Dumper;

use DateTime;
use DateTime::Format::Strptime;
my $dt=DateTime->now();

# ============================================================================
# # ============================== NAGIOS VARIABLES ============================
# # ============================================================================
#
my $TIMEOUT                             = 45;   # This is the global script timeout, not the SNMP timeout
my %ERRORS                              = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @Nagios_state                        = ("UNKNOWN","OK","WARNING","CRITICAL"); # Nagios states coding
#
#

# ============================================================================
# # ============================== GLOBAL VARIABLES ============================
# # ============================================================================
#
my $Version                     = '0.0.1';              # Version number of this script
my $Ver_date            = "11/09/2015";   # Version Date of this script
my $o_host                      = undef;                # Hostname
my $o_domain                    = undef;                # Domain
my $o_login                     = undef;                # Account 
my $o_passwd                  = undef;                # Password
my $o_help                      = undef;                # Want some help ?
my $o_verb                      = undef;                # Verbose mode
my $o_version           = undef;                # Print version
my $o_timeout           = undef;                # Timeout (Default 5)
my $o_perf                      = undef;                # Output performance data
my $o_check_type        = "GetConcurrentSessionsTrend";             # Default check is "GetConcurrentSessionsTrend"
my @valid_types         = ("GetConcurrentSessionsTrend","GetConnectionFailureTrend","GetConnectedUsersTrend","GetLoadIndexSummaries","GetUsers" );
my $opt_w              = undef;
my $opt_c              = undef;

my $alert_status        = 0     ;                       # Alert Status placeholder
my $final_status        = 0     ;                       # Alert Status placeholder
my $xml_result          = 0;            # XML receiver.
my $perfdata            = undef;


my @ArrayLine = (); #Line sorter tool.
my @Guid = ();
my @GroupDeliveryName = ();
my @idUser = ();
my @UserName = ();
my @DomainUser = ();
my @MachineName = ();
my @MachineSids = ();
my @MachineGDN = ();
my @ByMachineEffectiveLoadIndex = ();
my @ByMachineSessionCount = ();
my $NumberOfDeliveryGroup = 0;
my $NumberOfMachines = 0;
my $NumberOfUsers = 0;
my @FoundIndex; # USED to get index in array $FoundIndex[0]=0 mean not found, 1 mean found. $FoundIndex[1]=Value of the Index

my @MachineLoadSummary; # Machine;EffectiveLoadIndex;SessionCount;Date
my $ConcurrentSessionsTrend = -1;
my $ConnectedUsersTrend = -1;
my $ConnectionFailureTrend =-1;
my $AverageLoadIndex = 0;
my $CurrentNumberOfServer = 0;
my $TotalIndexLoad = 0;

# ============================================================================
# ============================== TIME HANDELING ==============================
# ============================================================================


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $LoadSummariesHour;
my $LoadSummariesDay;


$year = sprintf("%d", $year + 1900);
$mon = sprintf("%02d", $mon + 1);
$mday = sprintf("%02d", $mday);
$hour = sprintf("%02d", $hour);


# Dealing with the fact Citrix Directory refreshing of oData is a beat... asynchronious....
my $AsyncPeriod = 18;
if ( $hour < $AsyncPeriod ) {
  #print "plus petit que huit\n";
  my $RewindTime = sprintf("%02d", $hour - $AsyncPeriod);
  $LoadSummariesHour = sprintf("%02d", $RewindTime + 24);
  $LoadSummariesDay = sprintf("%02d", $mday - 1);
  #print "Day: ".$LoadSummariesDay." Rewing hour: ".$RewindTime." Yesterday: ".$LoadSummariesHour."\n";
  $dt->set_time_zone( 'Europe/Paris' );
  my $dformat = new DateTime::Format::Strptime(pattern=>'%d/%m/%Y %H:%M:%S');
  $dt->set_formatter($dformat);

  $dt->set(year=> $year,month=>$mon,day=> $mday,hour=> $hour,minute=> $min,second=>$sec);
  $dt->subtract(days=>1);
  $year=$dt->strftime('%Y'); 
  $mon=$dt->strftime('%m'); 
  $mday=$dt->strftime('%d'); 
  $LoadSummariesDay=$dt->strftime('%d');

} else {
  $LoadSummariesHour = sprintf("%02d", $hour - 8);
  $LoadSummariesDay = sprintf("%02d", $mday);
}

my $Prevhour = sprintf("%02d", $hour - 1);
$min = sprintf("%02d", $min);

# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version {
        print "check_netscaler_health version : $Version $Ver_date\n";
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] -H <host> -l login -p passwd -T (GetConcurrentSessionsTrend|GetConnectionFailureTrend|GetConnectedUsersTrend|GetLoadIndexSummaries|GetUsers) [-f] [-t <timeout>] [-V] -w warning -c critical\n";
}

# Subroutine: Check number
sub isnnum { # Return true if arg is not a number
        my $num = shift;
        if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
        return 1;
}

# Subroutine: Set Alert Status
sub set_status { # Return worst status with this order : OK, unknown, warning, critical
        if ($final_status == 1 && $alert_status != 2) {$alert_status = $final_status;};
        if ($final_status == 2) {$alert_status = $final_status;};
        if ($final_status == 3 && $alert_status == 0) {$alert_status = $final_status;};
        verb("Set Alert Status Sub >> Final Status: ".$final_status." Alert Status:".$alert_status);
        return $final_status;
}

# Subroutine: Print complete help
sub help {
        print "\nCitrix Directory plugin for Nagios\nVersion: $Version\nDate: $Ver_date\n\n";
        print_usage();
        print <<EOT;

Options:
-v, --verbose
   Print extra debugging information
-h, --help
   Print this help message
-H, --hostname=HOST
   Hostname !!! FQDN !!!
-l, --login=LOGIN 
-p, --passwd=PASSWD
-d, --domain=DOMAIN

-T, --type=Summary (Default)
   Health checks for Citrix Director : TBD
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   Timeout in seconds (Default: 5)
-V, --version
   Prints version number
-w, --warning
   Warning Maximum number
-c, --critical
   Critical Maximum number
   
   
Notes:
- For questions, problems and patches send me an e-mail (michael.aubertin\@gmail.com).

EOT
}

# Subroutine: Verbose output
sub verb {
        my $t=shift;
        print $t,"\n" if defined($o_verb);
}

sub FindIndex {
    my $look_for = shift;
    my @array = @_;
    my $index = 0;
    my @Returned = ( '0','0' );
    
    #verb("Array passed: ".@array."\n");
    #verb("String to look for:".$look_for."\n");

    for($index = 0; $index < ($#array + 1); $index++) {
     # verb("Loop: ".$array[$index]."\n");
      if ( $array[$index] eq $look_for) {
      #    verb ("\t\tFOUND at index: ".$index." $look_for ... $array[$index]\n");
          @Returned = ( '1',$index );
          last;
      }
    }
    
    return (@Returned); #0 mean not found
}


# Subroutine: Check Options
sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'v'             => \$o_verb,            'verbose'               => \$o_verb,
                'h'             => \$o_help,            'help'                  => \$o_help,
                'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
                'l:s'   => \$o_login,           'login:s'               => \$o_login,
                'p:s'   => \$o_passwd,          'passwd:s'              => \$o_passwd,
                'd:s'   => \$o_domain,          'domain:s'              => \$o_domain,
                't:i'   => \$o_timeout,         'timeout:i'             => \$o_timeout,
                'V'             => \$o_version,         'version'               => \$o_version,
                'f'             => \$o_perf,            'perfparse'             => \$o_perf,
                'T:s'   => \$o_check_type,      'type:s'                => \$o_check_type,
                'w:s'   => \$opt_w,      'warning:s'                => \$opt_w,
                'c:s'   => \$opt_c,      'critical:s'                => \$opt_c
        );

        # Check the -T option
        my $T_option_valid=0;
        foreach (@valid_types) {
                if ($_ eq $o_check_type) {
                        $T_option_valid=1;
                }
        }
        if ( $T_option_valid == 0 ) {
                print "Invalid check type (-T)!\n";
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        # Basic checks
        if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) {
                print "Timeout must be >1 and <60 !\n";
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if (!defined($o_timeout)) {
                $o_timeout=5;
        }
        if (defined ($o_help) ) {
                help();
                exit $ERRORS{"UNKNOWN"};
        }
        if (defined($o_version)) {
                p_version();
                exit $ERRORS{"UNKNOWN"};
        }
        # check host and filter
        if ( ! defined($o_host) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        
        if ( ! defined($o_login) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( ! defined($o_passwd) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( ! defined($o_domain) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( ! defined($opt_w) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( ! defined($opt_c) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
}

# ============================================================================
# ======================= INITIALISATION AND SUB =============================
# ============================================================================

check_options();


# Check gobal timeout if SNMP screws up
if (defined($TIMEOUT)) {
        verb("Alarm at ".$TIMEOUT." + ".$o_timeout);
        alarm($TIMEOUT+$o_timeout);
} else {
        verb("no global timeout defined : ".$o_timeout." + 15");
        alarm ($o_timeout+15);
}

# Report when the script gets "stuck" in a loop or takes to long
$SIG{'ALRM'} = sub {
        print "UNKNOWN: Script timed out\n";
        exit $ERRORS{"UNKNOWN"};
};

my $User_Agent = LWP::UserAgent->new(keep_alive=>1);
$User_Agent->agent("Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0.1) Gecko/20100101 Firefox/4.0.1");
$User_Agent->agent("EyesOfNetwork Airbus Helicopters Server");

$User_Agent->cookie_jar(HTTP::Cookies->new(file => "/tmp/CitrixDirector_cookies.txt"));
$User_Agent->default_header('Accept-Encoding' => "gzip,defalte");
$User_Agent->default_header('Accept-Language' => "en-US,en;q=0.5");

if ( defined($o_verb) ) {
  $User_Agent->add_handler("request_send",  sub { shift->dump; return });
  $User_Agent->add_handler("response_done", sub { shift->dump; return });
}

$User_Agent->credentials($o_host.':80', '', $o_domain."\\".$o_login, $o_passwd);


## ============================================================================
## ============== (INTERNAL USED) GET Delivery Group GUID =====================
## ============================================================================

my $result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Data/DesktopGroups");

if ($result->is_success) {
    verb ("Getting DesktopGroups data from request");
    $xml_result = XML::XPath->new($result->content);
    verb ("Dumping data to disk ok.");
}
else {
    print $result->status_line, "\n";
    exit 2
}
    
my $nodeset = $xml_result->find('/feed/entry/content/m:properties'); # WARNING: DEPENDANT of Connection !!!!! !!!! !!!!
 
my $i=0;   
verb ("\n");
foreach my $node ($nodeset->get_nodelist) {
     push (@GroupDeliveryName, $node->find('d:Name')->string_value);
     push (@Guid, $node->find('d:Id')->string_value);
     verb ($GroupDeliveryName[$i]." -- ".$Guid[$i]);
     $i++;
     $NumberOfDeliveryGroup++;
}

verb ("\n");
## ============================================================================
## ============== (INTERNAL USED) GET User =====================
## ============================================================================

$result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Data/Users");

if ($result->is_success) {
    verb ("Getting Users data from request");
    $xml_result = XML::XPath->new($result->content);
    verb ("Dumping data to disk ok.");
}
else {
    print $result->status_line, "\n";
    exit 2
}
    
$nodeset = $xml_result->find('/feed/entry/content/m:properties'); # WARNING: DEPENDANT of Connection !!!!! !!!! !!!!
 
$i=0;   
verb ("\n");

foreach my $node ($nodeset->get_nodelist) {
     push (@idUser, $node->find('d:Id')->string_value);
     push (@UserName, $node->find('d:UserName')->string_value);
     push (@DomainUser, $node->find('d:Domain')->string_value);
     verb ($idUser[$i]." -- ".$DomainUser[$i]."\\".$UserName[$i]);
     $i++;
     $NumberOfUsers++;
}

verb ("\n");

## ============================================================================
## ================ (INTERNAL USED) GET Machine Sids ==========================
## ============================================================================

$result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Data/Machines");

if ($result->is_success) {
    verb ("Getting Machine data from request");
    $xml_result = XML::XPath->new($result->content);
}
else {
    print $result->status_line, "\n";
    exit 2
}
    
$nodeset = $xml_result->find('/feed/entry/content/m:properties'); # WARNING: DEPENDANT of Connection !!!!! !!!! !!!!
 
$i=0;   
verb ("\n");
foreach my $node ($nodeset->get_nodelist) {
     push (@MachineName, $node->find('d:Name')->string_value);
     push (@MachineSids, $node->find('d:Id')->string_value);
     push (@MachineGDN, $node->find('d:DesktopGroupId')->string_value);
     verb ($MachineName[$i]." -- ".$MachineSids[$i]." -- G: ". $MachineGDN[$i]);
     $i++;
     $NumberOfMachines++;
}


sub GetLoadIndexSumByMachine {
  # ============================================================================
  # ================== GET LoadIndexSummaries By Machine =======================
  # ============================================================================
     #<m:properties>
     #   <d:Id m:type="Edm.Int64">56245</d:Id>
     #   <d:EffectiveLoadIndex m:type="Edm.Int32">40</d:EffectiveLoadIndex>
     #   <d:Cpu m:type="Edm.Int32" m:null="true" />
     #   <d:Memory m:type="Edm.Int32" m:null="true" />
     #   <d:Disk m:type="Edm.Int32" m:null="true" />
     #   <d:Network m:type="Edm.Int32" m:null="true" />
     #   <d:SessionCount m:type="Edm.Int32">40</d:SessionCount>
     #   <d:MachineId m:type="Edm.Guid">cf92a0f2-e1b5-4251-8373-e0b2264e328c</d:MachineId>
     #   <d:CreatedDate m:type="Edm.DateTime">2015-09-15T09:41:03.72</d:CreatedDate>
     #</m:properties> --- 562454040cf92a0f2-e1b5-4251-8373-e0b2264e328c2015-09-15T09:41:03.72
    
  $result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Data/LoadIndexes?\$filter=CreatedDate gt datetime'".$year."-".$mon."-".$LoadSummariesDay."T".$LoadSummariesHour.":".$min.":00'&\$orderby=CreatedDate desc");
    
  my $BasedString="http://".$o_host."/Citrix/Monitor/OData/v2/Data/LoadIndexes?\$filter=";
  my $CurrentString="CreatedDate gt datetime'".$year."-".$mon."-".$LoadSummariesDay."T".$LoadSummariesHour.":".$min.":00'&\$orderby=CreatedDate desc";
  my $encodedString=uri_escape($CurrentString);
  verb("DEBUG URL:".$BasedString.$encodedString."\n");

  # NOTE: This function will be very simplified the day where Citrix make Edm.Guid working whith eq comparator.
  
  my @AlreadyPerformed;
  my @TempIndex = 0;
  
  if ($result->is_success) {
      verb ("Getting Summary data from request");
      $xml_result = XML::XPath->new($result->content);
      $nodeset = $xml_result->find('/feed/entry/content/m:properties');
      verb ("Dumping data ok.");
         
        foreach my $node ($nodeset->get_nodelist) {
        
          my $MachineId=$node->find('d:MachineId')->string_value;
          @FoundIndex = FindIndex($MachineId,@MachineSids);
          
          @TempIndex = FindIndex($MachineName[$FoundIndex[1]],@AlreadyPerformed);
          #verb ("Handeling machine id:".$MachineId);
              
          if ( $TempIndex[0] gt 0 ) {
            verb ("Machine id (".$MachineId.") already performed\n");
          } else {
              my $EffectiveLoadIndex=$node->find('d:EffectiveLoadIndex')->string_value;
              my $SessionCount=$node->find('d:SessionCount')->string_value;
              my $Date=$node->find('d:CreatedDate')->string_value;
              verb ("For Machine: ".$MachineName[$FoundIndex[1]]." \n\t- MachineId: ".$MachineId." \n\t- EffectiveLoadIndex: ".$EffectiveLoadIndex."\n\t- SessionCount:".$SessionCount."\n\t- Date:".$Date."\n");
              push (@MachineLoadSummary, $MachineName[$FoundIndex[1]].";".$EffectiveLoadIndex.";".$SessionCount.";".$Date);
              push (@AlreadyPerformed, $MachineName[$FoundIndex[1]] );
              #verb ("Fin: ".$MachineId."\n");
           }
        }
  }
  else {
      verb("Error".$result->status_line." KO \n");
  }
  
  verb("Machine;EffectiveLoadIndex;SessionCount;Date\n");
  foreach (@MachineLoadSummary) {
    verb("$_\n");
  }
}


sub GetConcurrentSessionsTrend {
# ============================================================================
# ======================= GET ConcurrentSessionsTrend  =======================
# ============================================================================

my $result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Methods/GetConcurrentSessionsTrend?startDate=datetime'".$year."-".$mon."-".$mday."T".$Prevhour.":".$min.":00'&endDate=datetime'".$year."-".$mon."-".$mday."T".$hour.":".$min.":00'&intervalLength=5&\$orderby=Date desc&\$top=1");
    
  if ($result->is_success) {
      verb ("Getting GetLogonDurationTrend data from request");
      $xml_result = XML::XPath->new($result->content);
      verb ("Dumping data ok.");
      
      
      $nodeset = $xml_result->find('/feed/entry/content/m:properties');
      my $CurrentConcurrentSessionsTrend = "vide";  
      
      foreach my $node ($nodeset->get_nodelist) {
           $CurrentConcurrentSessionsTrend=$node->find('d:Value')->string_value;
           my $outputLine = XML::XPath::XMLParser::as_string($node); 
           $outputLine =~ s/></\>\n</g;
           $outputLine =~ s/<d:/   <d:/g;
           verb ("$outputLine\n");
           verb ("CurrentConcurrentSessionsTrend = ".$CurrentConcurrentSessionsTrend."\n");
      }  
      
      if ( $CurrentConcurrentSessionsTrend eq "vide" ) {
        $ConcurrentSessionsTrend = -1;
        verb ("CurrentConcurrentSessionsTrend seems 'vide'. Setting ConcurrentSessionsTrend to 0\n");
      } else {
        $ConcurrentSessionsTrend = $CurrentConcurrentSessionsTrend;
      }
      
  }
  else {
      verb("Error".$result->status_line." KO ConcurrentSessionsTrend \n");
  }
}

sub GetConnectionFailureTrend {
# ============================================================================
# ======================= GET GetConnectionFailureTrend  =======================
# ============================================================================

my $result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Methods/GetConnectionFailureTrend?startDate=datetime'".$year."-".$mon."-".$mday."T".$Prevhour.":".$min.":00'&endDate=datetime'".$year."-".$mon."-".$mday."T".$hour.":".$min.":00'&intervalLength=5&\$orderby=Date desc&\$top=1");
    
  if ($result->is_success) {
      verb ("Getting ConnectionFailureTrend data from request");
      $xml_result = XML::XPath->new($result->content);
      verb ("Dumping data ok.");
      
      
      $nodeset = $xml_result->find('/feed/entry/content/m:properties');
      my $CurrentConnectionFailureTrend = "vide";  
      
      foreach my $node ($nodeset->get_nodelist) {
           $CurrentConnectionFailureTrend=$node->find('d:Value')->string_value;
           my $outputLine = XML::XPath::XMLParser::as_string($node); 
           $outputLine =~ s/></\>\n</g;
           $outputLine =~ s/<d:/   <d:/g;
           verb ("$outputLine\n");
           verb ("CurrentConnectionFailureTrend = ".$CurrentConnectionFailureTrend."\n");
      }  
      
      if ( $CurrentConnectionFailureTrend eq "vide" ) {
        $ConnectionFailureTrend = -1;
        verb ("CurrentConnectionFailureTrend seems 'vide'. Setting ConnectionFailureTrend to 0\n");
      } else {
        $ConnectionFailureTrend = $CurrentConnectionFailureTrend;
      }
      
  }
  else {
      verb("Error".$result->status_line." KO ConnectionFailureTrend \n");
  }
}

sub GetConnectedUsersTrend {
# ============================================================================
# ======================= GET GetConnectedUsersTrend  =======================
# ============================================================================

my $result = $User_Agent->get("http://".$o_host."/Citrix/Monitor/OData/v2/Methods/GetConnectedUsersTrend?startDate=datetime'".$year."-".$mon."-".$mday."T".$Prevhour.":".$min.":00'&endDate=datetime'".$year."-".$mon."-".$mday."T".$hour.":".$min.":00'&intervalLength=5&\$orderby=Date desc&\$top=1");
    
  if ($result->is_success) {
      verb ("Getting ConnectedUsersTrend data from request");
      $xml_result = XML::XPath->new($result->content);
      verb ("Dumping data ok.");
      
      
      $nodeset = $xml_result->find('/feed/entry/content/m:properties');
      my $CurrentConnectedUsersTrend = "vide";  
      
      #$o_verb = 1;
      foreach my $node ($nodeset->get_nodelist) {
           my $outputLine = XML::XPath::XMLParser::as_string($node); 
           $outputLine =~ s/></\>\n</g;
           $outputLine =~ s/<d:/   <d:/g;
           verb ("$outputLine\n");
           $CurrentConnectedUsersTrend=$node->find('d:Value')->string_value;    
      }  
      #$o_verb= 0;
      verb ("   CurrentConnectedUsersTrend = ".$CurrentConnectedUsersTrend."\n");
      
      if ( $CurrentConnectedUsersTrend eq "vide" ) {
        $ConnectedUsersTrend = -1;
        verb ("CurrentConnectedUsersTrend seems 'vide'. Setting ConnectedUsersTrend to 0\n");
      } else {
        $ConnectedUsersTrend = $CurrentConnectedUsersTrend;
      }
      
  }
  else {
      verb("Error".$result->status_line." KO ConnectedUsersTrend \n");
  }
}


# ============================================================================
# ================================== MAIN ====================================
# ============================================================================


if ( $o_check_type eq "GetConcurrentSessionsTrend") {
  GetConcurrentSessionsTrend();
  if ( $ConcurrentSessionsTrend < 0 ) {
    print "CRITICAL: Can't get ConcurrentSessionsTrend information.\n";
    exit $ERRORS{"CRITICAL"};
  }
  
  $final_status = "OK";
  if ($ConcurrentSessionsTrend >= $opt_w) { $final_status = "WARNING"; }
  if ($ConcurrentSessionsTrend >= $opt_c) { $final_status = "CRITICAL"; }

$perfdata = sprintf("ConcurrentSessionsTrend=%d;%d;%d ", $ConcurrentSessionsTrend,$opt_w,$opt_c);
print sprintf("$final_status: %d ConcurrentSessionsTrend Running.|$perfdata\n", $ConcurrentSessionsTrend);

exit $ERRORS{$final_status};  
}

if ( $o_check_type eq "GetConnectionFailureTrend") {
  GetConnectionFailureTrend();
  if ( $ConnectionFailureTrend < 0 ) {
    print "CRITICAL: Can't get ConnectionFailureTrend information.\n";
    exit $ERRORS{"CRITICAL"};
  }  
  $final_status = "OK";
  if ($ConnectionFailureTrend >= $opt_w) { $final_status = "WARNING"; }
  if ($ConnectionFailureTrend >= $opt_c) { $final_status = "CRITICAL"; }

$perfdata = sprintf("ConnectionFailureTrend=%d;%d;%d ", $ConnectionFailureTrend,$opt_w,$opt_c);
print sprintf("$final_status: %d ConnectionFailureTrend Running.|$perfdata\n", $ConnectionFailureTrend);

exit $ERRORS{$final_status}; 
}

if ( $o_check_type eq "GetConnectedUsersTrend") {
  GetConnectedUsersTrend();
  if ( $ConnectedUsersTrend < 0 ) {
    print "CRITICAL: Can't get ConnectedUsersTrend information.\n";
    exit $ERRORS{"CRITICAL"};
  }  
  $final_status = "OK";
  if ($ConnectedUsersTrend >= $opt_w) { $final_status = "WARNING"; }
  if ($ConnectedUsersTrend >= $opt_c) { $final_status = "CRITICAL"; }

$perfdata = sprintf("ConnectedUsersTrend=%d;%d;%d ", $ConnectedUsersTrend,$opt_w,$opt_c);
print sprintf("$final_status: %d ConnectedUsersTrend Running.|$perfdata\n", $ConnectedUsersTrend);

exit $ERRORS{$final_status};  
}

if ( $o_check_type eq "GetUsers") {
  
  if ( $NumberOfUsers eq 0 ) {
    print "CRITICAL: Can't get DeclaredUsers information.\n";
    exit $ERRORS{"CRITICAL"};
  }  
  $final_status = "OK";
  if ($NumberOfUsers >= $opt_w) { $final_status = "WARNING"; }
  if ($NumberOfUsers >= $opt_c) { $final_status = "CRITICAL"; }

$perfdata = sprintf("NumberOfUsers=%d;%d;%d ", $NumberOfUsers,$opt_w,$opt_c);
print sprintf("$final_status: %d NumberOfUsers Running.|$perfdata\n", $NumberOfUsers);

exit $ERRORS{$final_status};  
}


if ( $o_check_type eq "GetLoadIndexSummaries") {
  GetLoadIndexSumByMachine();
  
  if ( $#MachineLoadSummary < 0 ) {
      print "CRITICAL: Can't get Summary information.\n";
      exit $ERRORS{"CRITICAL"};
  }
  
  $final_status = "OK";
  
  $CurrentNumberOfServer = ($#MachineLoadSummary + 1);
  
  $perfdata = sprintf(" ");
  
  foreach my $MachineLine (@MachineLoadSummary) {
    @ArrayLine = split(';', $MachineLine);
    
    my @MachineNetbiosName = split(/\\/, $ArrayLine[0]);
    
    verb ("Date: ".$ArrayLine[3]."\n");
    verb ("Machine: ".$ArrayLine[0]."\n");
    verb ("EffectiveLoadIndex: ".$ArrayLine[1]."\n");
    verb ("SessionCount: ".$ArrayLine[2]."\n\n");
    verb ("Current Status: ".$final_status."\n");
    
    if ($final_status eq "OK" ) { if ($ArrayLine[1] >= $opt_w) { $final_status = "WARNING"; } }
    if (($final_status eq "OK" )|($final_status eq "WARNING")) { if ($ArrayLine[1] >= $opt_c) { $final_status = "CRITICAL"; } }
    if ($final_status eq "OK" ) { if ($ArrayLine[2] >= $opt_w) { $final_status = "WARNING"; } }
    if (($final_status eq "OK" )|($final_status eq "WARNING")) { if ($ArrayLine[2] >= $opt_c) { $final_status = "CRITICAL"; } }
    verb ("New Status: ".$final_status."\n");
    
    $perfdata = $perfdata.sprintf("%s-EffectiveLoadIndex=%d;%d;%d ", $MachineNetbiosName[1], $ArrayLine[1],$opt_w,$opt_c);
    $perfdata = $perfdata.sprintf("%s-SessionCount=%d;%d;%d ", $MachineNetbiosName[1], $ArrayLine[2],$opt_w,$opt_c);
    $TotalIndexLoad = $TotalIndexLoad + $ArrayLine[1];
  }
  
  $AverageLoadIndex = $TotalIndexLoad / $CurrentNumberOfServer;
  
  
  print sprintf("$final_status: %d servers in the farms.| AverageLoadIndex=%d CurrentNumberOfServer=%d  $perfdata ", $CurrentNumberOfServer, $AverageLoadIndex,$CurrentNumberOfServer);

  exit $ERRORS{$final_status};  
}




