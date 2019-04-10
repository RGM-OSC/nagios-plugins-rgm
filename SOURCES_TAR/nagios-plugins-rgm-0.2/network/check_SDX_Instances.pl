#!/usr/bin/perl
# michael.aubertin@gmail.com
# Release under GPL V2
# Check SDX Health
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
use Net::SNMP;



# ============================================================================
# # ============================== NAGIOS VARIABLES ============================
# # ============================================================================
#
my $TIMEOUT                             = 35;   # This is the global script timeout, not the SNMP timeout
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
my $o_community                = undef;                 # Community SNMP
my $o_passwd                  = undef;                # Password
my $o_help                      = undef;                # Want some help ?
my $o_verb                      = undef;                # Verbose mode
my $o_version           = undef;                # Print version
my $o_timeout           = undef;                # Timeout (Default 5)
my $o_perf                      = undef;                # Output performance data
my $o_check_type        = "GetInstanceState";             # Default check is "GetConcurrentSessionsTrend"
my @valid_types         = ("GetInstanceState","GetInstanceList");
my $opt_w              = undef;
my $opt_c              = undef;

my $o_Instance                      = undef;                # Netscaler Virtual Instance


my $alert_status        = 0     ;                       # Alert Status placeholder
my $final_status        = 0     ;                       # Alert Status placeholder
my $final_output        = ""    ;
my $xml_result          = 0;            # XML receiver.
my $perfdata            = undef;

my @AvailableInstances = ();
my @InstanceState = ();
my $GlobalIndex = 0;
my @FoundIndex = ();

my $nsName_text_oid = ".1.3.6.1.4.1.5951.6.3.2.1.6.1.4"; # could not be finer because not understanding internal Net::SNMP issue.
my $nsInstanceState_value_oid = ".1.3.6.1.4.1.5951.6.3.2.1.15.1.4";

# ============================================================================
# ============================== TIME HANDELING ==============================
# ============================================================================


my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

$year = sprintf("%d", $year + 1900);
$mon = sprintf("%02d", $mon + 1);
$mday = sprintf("%02d", $mday);
$hour = sprintf("%02d", $hour);
my $Prevhour = sprintf("%02d", $hour - 4); # 4 because Citrix monitoring is a beat... asynchronious....
$min = sprintf("%02d", $min);

# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version {
        print "./check_SDX_Instances.pl version : $Version $Ver_date\n";
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] -H <host> -C community -S \"NetScaler Instance\" [-f] [-t <timeout>] [-V]\n";
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
        print "\nNetscaler Virtual Instance check for Nagios\nVersion: $Version\nDate: $Ver_date\n\n";
        print_usage();
        print <<EOT;

Options:
-v, --verbose
   Print extra debugging information
-h, --help
   Print this help message
-H, --hostname=HOST
   Hostname
-C, --community=Community 
-S, --Instance=Instance Name
-T, --type=GetInstanceState (Default)
   Health check for Netscaler Virtual Instance

-t, --timeout=INTEGER
   Timeout in seconds (Default: 5)
-V, --version
   Prints version number
   
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
    
    verb("Array passed: ".@array."\n");
    verb("String to look for:".$look_for."\n");

    for($index = 0; $index < ($#array + 1); $index++) {
      verb("Loop: ".$array[$index]."\n");
      if ( $array[$index] eq $look_for) {
          verb ("\t\tFOUND at index: ".$index." $look_for ... $array[$index]\n");
          @Returned = ( '1',$index );
          last;
      }
    }
    
    return (@Returned); #0 mean not found
}

sub check_snmp_result {
        my $snmp_table          = shift;
        my $snmp_error_mesg     = shift;

        # Check if table is defined and does not contain specified error message.
        # Had to do string compare it will not work with a status code
        if (!defined($snmp_table) && $snmp_error_mesg !~ /table is empty or does not exist/
) {
                printf("ERROR: ". $snmp_error_mesg . " : UNKNOWN\n");
                exit $ERRORS{"UNKNOWN"};
        }
}

# Subroutine: Check Options
sub check_options {
        Getopt::Long::Configure ("bundling");
        GetOptions(
                'v'             => \$o_verb,            'verbose'               => \$o_verb,
                'h'             => \$o_help,            'help'                  => \$o_help,
                'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
                'C:s'   => \$o_community,           'community:s'               => \$o_community,
                't:i'   => \$o_timeout,         'timeout:i'             => \$o_timeout,
                'V'             => \$o_version,         'version'               => \$o_version,
                'T:s'   => \$o_check_type,      'type:s'                => \$o_check_type,
                'w:s'   => \$opt_w,      'warning:s'                => \$opt_w,
                'c:s'   => \$opt_c,      'critical:s'                => \$opt_c,
                'S:s'   => \$o_Instance,           'Instance:s'               => \$o_Instance,

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
                $o_timeout=$TIMEOUT;
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
        if ( ! defined($o_community) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( ! defined($o_Instance) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        if ( $o_check_type eq 'NoTApplicable in This Check :P' ) {
          if ( ! defined($opt_w) ) {
                  print_usage();
                  exit $ERRORS{"UNKNOWN"};
          }
          if ( ! defined($opt_c) ) {
                  print_usage();
                  exit $ERRORS{"UNKNOWN"};
          }
        }
}

# ============================================================================
# ======================= INITIALISATION AND SUB =============================
# ============================================================================

check_options();
my ($session,$error);

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


# ============================================================================
# ======================= GET GetInstanceState  =======================
# ============================================================================
sub GetInstanceState {

  verb("SNMP v1 login");
  ($session, $error) = Net::SNMP->session(	-hostname	=> $o_host,			
                                            -community	=> $o_community,		
                                            -port		=> 161,
                                            -timeout	=> $o_timeout	);
   
  # Check if there are any problems with the session
  if (!defined($session)) {
  	printf("ERROR opening session: %s.\n", $error);
  	exit $ERRORS{"UNKNOWN"};
  }
  # Get SNMP table(s) and check the result
	verb("Get SNMP Tables");
	# See version notes about max_msg_size.
	$session->max_msg_size(5000);
  $session->translate(Net::SNMP->TRANSLATE_NONE);
	my $resultat_status 		=  $session->get_table(Baseoid => $nsName_text_oid);
 

	
	&check_snmp_result($resultat_status,$session->error);
  verb ("Status: ".$resultat_status."\n");
 	if (defined($resultat_status)){	
  	foreach my $key ( keys %$resultat_status) 
  	{
       verb ("key: ".$key." -> ".$$resultat_status{$key}."\n");
       push (@AvailableInstances, $$resultat_status{$key});
    }
   } else {
    printf("ERROR requested OID not available.\n");
  	exit $ERRORS{"UNKNOWN"};
  } 
  
  
  my $resultat_value 		=  $session->get_table(Baseoid => $nsInstanceState_value_oid);
	&check_snmp_result($resultat_value,$session->error);
 
	verb("Getting result ok."); 
 
	if (defined($resultat_value)){	
     	foreach my $key ( keys %$resultat_value) 
      	{
           verb ("key: ".$key." -> ".$$resultat_value{$key}."\n");
           push (@InstanceState, $$resultat_value{$key});
        }
  } else {
    printf("ERROR requested OID not available.\n");
  	exit $ERRORS{"UNKNOWN"};
  } 
}

# ============================================================================
# ======================= GET GetInstanceList  =======================
# ============================================================================
sub GetInstanceList {

  verb("SNMP v1 login");
  ($session, $error) = Net::SNMP->session(	-hostname	=> $o_host,			
                                            -community	=> $o_community,		
                                            -port		=> 161,
                                            -timeout	=> $o_timeout	);
   
  # Check if there are any problems with the session
  if (!defined($session)) {
  	printf("ERROR opening session: %s.\n", $error);
  	exit $ERRORS{"UNKNOWN"};
  }
  # Get SNMP table(s) and check the result
	verb("Get SNMP Tables");
	# See version notes about max_msg_size.
	$session->max_msg_size(5000);
  $session->translate(Net::SNMP->TRANSLATE_NONE);
	my $resultat_status 		=  $session->get_table(Baseoid => $nsName_text_oid);
 

	
	&check_snmp_result($resultat_status,$session->error);
  verb ("Status: ".$resultat_status."\n");
 	if (defined($resultat_status)){	
  	foreach my $key ( keys %$resultat_status) 
  	{
       verb ("key: ".$key." -> ".$$resultat_status{$key}."\n");
       push (@AvailableInstances, $$resultat_status{$key});
    }
   } else {
    printf("ERROR requested OID not available.\n");
  	exit $ERRORS{"UNKNOWN"};
  } 
  
  
  my $resultat_value 		=  $session->get_table(Baseoid => $nsInstanceState_value_oid);
	&check_snmp_result($resultat_value,$session->error);
 
	verb("Getting result ok."); 
 
	if (defined($resultat_value)){	
     	foreach my $key ( keys %$resultat_value) 
      	{
           verb ("key: ".$key." -> ".$$resultat_value{$key}."\n");
           push (@InstanceState, $$resultat_value{$key});
        }
  } else {
    printf("ERROR requested OID not available.\n");
  	exit $ERRORS{"UNKNOWN"};
  } 
}

# ============================================================================
# ================================== MAIN ====================================
# ============================================================================

#my @AvailableInstances = ();
#my @InstanceState = ();
#my $GlobalIndex = 0;

if ( $o_check_type eq "GetInstanceState") {

  GetInstanceState();
  
  if ( $#AvailableInstances < 0 ) {
      print "CRITICAL: Can't get Instances information.\n";
      exit $ERRORS{"CRITICAL"};
  }
    if ( $#InstanceState < 0 ) {
      print "CRITICAL: Can't get Instances state information.\n";
      exit $ERRORS{"CRITICAL"};
  }
  
    $final_status = "OK";   
    my $Current_State = $InstanceState[$FoundIndex[1]];
    
    @FoundIndex = FindIndex($o_Instance,@AvailableInstances);
    verb("State: ".$Current_State." ".$AvailableInstances[$FoundIndex[1]]."\n");
    
    if ( $Current_State ne "Up" ) { 
        # "CRITICAL";
        $final_status = "CRITICAL";   
    }
 
  print sprintf("$final_status: %s state is currently %s\n", $AvailableInstances[$FoundIndex[1]], $Current_State );
  exit $ERRORS{$final_status}; 
}
 
if ( $o_check_type eq "GetInstanceList") {

  GetInstanceList();
  
  if ( $#AvailableInstances < 0 ) {
      print "CRITICAL: Can't get Instances information.\n";
      exit $ERRORS{"CRITICAL"};
  }
    if ( $#InstanceState < 0 ) {
      print "CRITICAL: Can't get Instances state information.\n";
      exit $ERRORS{"CRITICAL"};
  }
  
    $final_status = "OK";   
    
    for($GlobalIndex = 0; $GlobalIndex < ($#AvailableInstances + 1); $GlobalIndex++) {
      verb("Key: ".$AvailableInstances[$GlobalIndex]." value is: ".$InstanceState[$GlobalIndex]."\n");  
      $final_output = $final_output.sprintf(" %s: %s \n", $AvailableInstances[$GlobalIndex], $InstanceState[$GlobalIndex] );
    }
   
  print sprintf("Get Instance list status: $final_status. Click for detail\n %s \n", $final_output);
  exit $ERRORS{$final_status}; 
}
 





