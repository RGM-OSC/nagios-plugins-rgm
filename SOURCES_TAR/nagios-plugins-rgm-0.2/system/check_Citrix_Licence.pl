#!/usr/bin/perl
# michael.aubertin@gmail.com
# Release under GPL V2
# Check Citrix Licence
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



# ============================================================================
# # ============================== NAGIOS VARIABLES ============================
# # ============================================================================
#
my $TIMEOUT                             = 25;   # This is the global script timeout, not the SNMP timeout
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
my $o_check_type        = "GetLicenceUsed";             # Default check is "GetConcurrentSessionsTrend"
my @valid_types         = ("GetLicenceTotal","GetLicenceAvailable","GetLicenceUsed");
my $opt_w              = undef;
my $opt_c              = undef;

my $alert_status        = 0     ;                       # Alert Status placeholder
my $final_status        = 0     ;                       # Alert Status placeholder
my $xml_result          = 0;            # XML receiver.
my $perfdata            = undef;

my @FoundIndex; # USED to get index in array $FoundIndex[0]=0 mean not found, 1 mean found. $FoundIndex[1]=Value of the Index
my @ArrayLine = (); #Line sorter tool.


my $LicenceTotal = -1;
my $LicenceAvailable = -1;
my $LicenceUsed = -1;


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
        print "check_netscaler_health version : $Version $Ver_date\n";
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] -H <host> -l login -p passwd -T (GetLicenceTotal|GetLicenceAvailable|GetLicenceUsed) [-f] [-t <timeout>] [-V] -w warning -c critical\n";
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
        print "\nCitrix Licence plugin for Nagios\nVersion: $Version\nDate: $Ver_date\n\n";
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

        if ( $o_check_type eq 'GetLicenceAvailable' ) {
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



sub GetLicenceTotal {
  # ============================================================================
  # ======================= GET GetLicenceTotal  =======================
  # ============================================================================

  my $result = `/bin/wmic -U $o_domain/$o_login%$o_passwd  //$o_host --namespace=root/CitrixLicensing "Select * From Citrix_GT_License_Pool" 2> /dev/null`;
      
  my @resultlines = split (/\n/, $result);

  foreach my $currentline (@resultlines) {
      verb ("Line: ".$currentline."\n");
      my @rows = split (/\|/, $currentline); 
      #Count DUP_GROUP FLOAT_OK  HOST_BASED  HOSTID  InUseCount  LicenseType Overdraft PLATFORMS PLD PLDFullName PooledAvailable SubscriptionDate  USER_BASED  VendorString
      if ( defined($rows[9])) {
        if ( $rows[9] eq 'XDT_PLT_CCS' ) {
          $LicenceTotal += $rows[5]; #Currently in use
          $LicenceTotal += $rows[11]; #Currently in use
          verb ("Adding: ".$rows[11]."and ".$rows[5]." license counter (comming from: ".$rows[9].")\n");
        }
      }
  }
    
  if ($LicenceTotal > 0) { $LicenceTotal++ } #Add offset if licence exist.
  verb ("Number of Licence found: ".$LicenceTotal.".\n");
}


sub GetLicenceAvailable {
  # ============================================================================
  # ======================= GET GetLicenceAvailable  =======================
  # ============================================================================

  my $result = `/bin/wmic -U $o_domain/$o_login%$o_passwd  //$o_host --namespace=root/CitrixLicensing "Select * From Citrix_GT_License_Pool" 2> /dev/null`;
      
  my @resultlines = split (/\n/, $result);
  foreach my $currentline (@resultlines) {
      verb ("Line: ".$currentline."\n");
      my @rows = split (/\|/, $currentline); 
      #Count DUP_GROUP FLOAT_OK  HOST_BASED  HOSTID  InUseCount  LicenseType Overdraft PLATFORMS PLD PLDFullName PooledAvailable SubscriptionDate  USER_BASED  VendorString
      if ( defined($rows[9])) {
        if ( $rows[9] eq "XDT_PLT_CCS") {
          verb ("Adding: ".$rows[11]." license in available counter (".$LicenceAvailable.").\n");
          $LicenceAvailable += $rows[11]; 
        }
      }
  }
    
  if ($LicenceAvailable > 0) { $LicenceAvailable++ } #Add offset if licence exist.
   verb ("Number of Licence available found: ".$LicenceAvailable.".\n");
}

sub GetLicenceUsed {
  # ============================================================================
  # ======================= GET GetLicenceUsed  =======================
  # ============================================================================
  my $result = `/bin/wmic -U $o_domain/$o_login%$o_passwd  //$o_host --namespace=root/CitrixLicensing "Select * From Citrix_GT_License_Pool" 2> /dev/null`;
      
  my @resultlines = split (/\n/, $result);
  foreach my $currentline (@resultlines) {
      verb ("Line: ".$currentline."\n");
      my @rows = split (/\|/, $currentline); 
      #Count DUP_GROUP FLOAT_OK  HOST_BASED  HOSTID  InUseCount  LicenseType Overdraft PLATFORMS PLD PLDFullName PooledAvailable SubscriptionDate  USER_BASED  VendorString
      if ( defined($rows[9])) {
        if ( $rows[9] eq "XDT_PLT_CCS") {
          $LicenceUsed += $rows[5]; #Currently in use
          if ($LicenceUsed < 0) { $LicenceUsed++ }
          verb ("Adding: ".$rows[5]." license in used counter.\n");
        }
      }
  }
    if ($LicenceUsed > 0) { $LicenceUsed++ } #Add offset if licence exist.
    verb ("Number of Licence used found: ".$LicenceUsed.".\n");
}


# ============================================================================
# ================================== MAIN ====================================
# ============================================================================


if ( $o_check_type eq "GetLicenceTotal") {

  GetLicenceTotal();

  if ( $LicenceTotal < 0 ) {
    print "CRITICAL: Can't get LicenceTotal information.\n";
    exit $ERRORS{"CRITICAL"};
  }
  
  $final_status = "OK";
  if ($LicenceTotal <= 1) { $final_status = "CRITICAL"; }

$perfdata = sprintf("LicenceTotal=%d ", $LicenceTotal);
print sprintf("$final_status: %d LicenceTotal Running.|$perfdata\n", $LicenceTotal);

exit $ERRORS{$final_status};  


}

if ( $o_check_type eq "GetLicenceAvailable") {

  GetLicenceAvailable();

  if ( $LicenceAvailable < 0 ) {
    print "CRITICAL: Can't get LicenceAvailable information.\n";
    exit $ERRORS{"CRITICAL"};
  }
  
    $final_status = "OK";

  if ($LicenceAvailable <= $opt_w) { $final_status = "WARNING"; }
  if ($LicenceAvailable <= $opt_c) { $final_status = "CRITICAL"; }

  $perfdata = sprintf("LicenceAvailable=%d;%d;%d ", $LicenceAvailable,$opt_w,$opt_c);
  print sprintf("$final_status: %d LicenceAvailable Running.|$perfdata\n", $LicenceAvailable);

  exit $ERRORS{$final_status}; 
}



if ( $o_check_type eq "GetLicenceUsed") {

  GetLicenceUsed();

  if ( $LicenceUsed < 0 ) {
    print "CRITICAL: Can't get LicenceUsed information.\n";
    exit $ERRORS{"CRITICAL"};
  }  
  
  $final_status = "OK";
  # 
  # THERE IS NO ALARM ON USED (May a % of global should be develop ?)
  #if ($LicenceUsed <= 1) { $final_status = "CRITICAL"; }

  $perfdata = sprintf("LicenceUsed=%d ", $LicenceUsed);
  print sprintf("$final_status: %d LicenceUsed Running.|$perfdata\n", $LicenceUsed);

  exit $ERRORS{$final_status}; 

}





