#!/usr/bin/perl
# michael.aubertin@axians.com
# Release under GPL V2
# Check ELK Values 
#
# Thank's to http://repo.openfusion.net/centos7-x86_64/ for perl dependencies...
# http://goessner.net/articles/JsonPath/

# Released with the courtesy of Conseil Departemental de la Lozere for EyesOfNetwork OpenSource project :)
#

use strict;
use warnings;

use LWP::UserAgent;
use LWP::Debug qw(+);
use HTTP::Cookies;
use Getopt::Long;
use JSON;
use JSON::Path;
use utf8;
use Text::Unidecode;

use feature qw/ say /;
use Data::Dumper;


# # ============================================================================
# # ============================== NAGIOS VARIABLES ============================
# # ============================================================================
#
my $TIMEOUT                             = 25;   # This is the global script timeout, not the SNMP timeout
my %ERRORS                              = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @Nagios_state                        = ("UNKNOWN","OK","WARNING","CRITICAL"); # Nagios states coding
#
#
# # ============================================================================
# # ============================== GLOBAL VARIABLES ============================
# # ============================================================================
#
my $Version                     = '0.0.2';      # Version number of this script
my $Ver_date            = "26/04/2017"; 	# Version Date of this script
my $o_host                      = undef;        # Hostname
my $o_port                      = undef;        # PORT
my $o_index                     = undef;        # Index 
my $o_size                      = 10;           # Number of hits to retreive in index (default 10)
my $o_filter                    = undef;        # Query filter
my $o_query_for                  = undef;        # String to look for in retreived array of hits.
my $o_column_list               = undef;        # Comma separated column list.
my $o_column_label               = undef;        # Comma separated column list.
my $o_help                      = undef;        # Want some help ?
my $o_debug                      = undef;        # Debug mode
my $o_verb                      = undef;        # Verbose mode
my $o_version                   = undef;                # Print version
my $o_timeout                   = undef;                # Timeout (Default 15)
my $o_perf                      = undef;        # Output performance data
my $o_check_type        = "GetIndexCount";        # Default check is "GetIndexCount"
my @valid_types         = ("GetIndexCount");
my $opt_w              = undef;
my $opt_c              = undef;

my $alert_status        = 0;                       # Alert Status placeholder
my $final_status        = 0;                       # Alert Status placeholder
my $json_result          = 0;		           # JSON receiver.
my $perfdata            = undef;

my $hits;

my $GetIndexCount = -1;
my $NumberOfColumn = 0;
my @Column_List;
my @curTuple;


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
        print "check_ELK_Values version : $Version $Ver_date\n";
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] [-d] -H <host> -p <TCPport> -i <index> -T (GetIndexCount|) -s <size> -F <filter> -L <columnlist> -l <column_label> [-Q <query_for>] [-f] [-t <timeout>] [-V] -w warning -c critical\n";
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
        debugging("Set Alert Status Sub >> Final Status: ".$final_status." Alert Status:".$alert_status);
        return $final_status;
}

# Subroutine: Print complete help
sub help {
        print "\nELK plugin for Nagios\nVersion: $Version\nDate: $Ver_date\n\n";
        print_usage();
        print <<EOT;

Options:
-d, --debugging
   Print extra debugging information
-v, --verbose
   Print result information
-h, --help
   Print this help message
-H, --hostname=HOST
   Hostname !!! FQDN !!!
-p, --port=TCP PORT 
-i, --index=INDEX
-T, --type=GetIndexCount (Default)
   Health checks for ELK 
-s, --size=INTERGER
    Number of hits to retreive
-F, --filter=STRING
    JSON query filter ex: '{ "query": { "match_all": {} } }'
-Q, --query_for=STRING
    String you look for in index
-L, --column_Path=STRING
    Column wanted (WARNING: JSON::Path format)
-l, --label=STRING
    Column count label
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   Timeout in seconds (Default: 15)
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
sub debugging {
        my $t=shift;
        print $t,"\n" if defined($o_debug);
}

sub FindIndex {
    my $query_for = shift;
    my @array = @_;
    my $index = 0;
    my @Returned = ( '0','0' );
    
    debugging("Array passed: ".@array."\n");
    debugging("String to look for:".$query_for."\n");

    for($index = 0; $index < ($#array + 1); $index++) {
      debugging("Loop: ".$array[$index]."\n");
      if ( $array[$index] eq $query_for) {
          verb ("\t\tFOUND at index: ".$index." $query_for ... $array[$index]\n");
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
                'd'             => \$o_debug,            'debugging'               => \$o_debug,
                'h'             => \$o_help,            'help'                  => \$o_help,
                'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
                'p:s'   => \$o_port,           'port:s'               => \$o_port,
                'i:s'   => \$o_index,          'index:s'              => \$o_index,
                's:i'   => \$o_size,          'size:i'              => \$o_size,
                'F:s'   => \$o_filter,          'filter:s'              => \$o_filter,
                'Q:s'   => \$o_query_for,          'query_for:s'              => \$o_query_for,
                'L:s'   => \$o_column_list,          'column_list:s'              => \$o_column_list,
                'l:s'   => \$o_column_label,          'column_label:s'              => \$o_column_label,
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
        if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 600))) {
                print "Timeout must be >1 and < 600 !\n";
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
        
        if ( ! defined($o_index) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }

        if ( ! defined($o_filter) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }

        if ( ! defined($o_column_label) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }
        
        if ( ! defined($o_column_list) ) {
                print_usage();
                exit $ERRORS{"UNKNOWN"};
        }

        if ( ! defined($o_port) ) {
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

debugging("Column:".$o_column_list."\n");

# Check gobal timeout if SNMP screws up
if (defined($TIMEOUT)) {
        debugging("Alarm at ".$TIMEOUT." + ".$o_timeout);
        alarm($TIMEOUT+$o_timeout);
} else {
        debugging("no global timeout defined : ".$o_timeout." + 15");
        alarm ($o_timeout+15);
}

# Report when the script gets "stuck" in a loop or takes to long
$SIG{'ALRM'} = sub {
        print "UNKNOWN: Script timed out\n";
        exit $ERRORS{"UNKNOWN"};
};

my $User_Agent = LWP::UserAgent->new(keep_alive=>1);
$User_Agent->agent("Mozilla/5.0 (Windows NT 6.1; WOW64; rv:2.0.1) Gecko/20100101 Firefox/4.0.1");
$User_Agent->agent("EyesOfNetwork Server");

$User_Agent->cookie_jar(HTTP::Cookies->new(file => "/tmp/ELK_".$o_host."_".$o_index."_cookies.txt"));
$User_Agent->default_header('Accept-Encoding' => "gzip,defalte");
$User_Agent->default_header('Accept-Language' => "en-US,en;q=0.5");

if ( defined($o_debug) ) {
  $User_Agent->add_handler("request_send",  sub { shift->dump; return });
  $User_Agent->add_handler("response_done", sub { shift->dump; return });
}

## ============================================================================
## ============== (INTERNAL USED) GET Index search  =====================
## ============================================================================

#my $filter_json = '{ "query": { "match_all": {} } }';

# my $filter_json = '{ 
#  "query": { 
#     "bool": {
#        "must": [
#         { "match": { "_index": "prod-2017-04-26" } },
#         { "match": { "username": "ppoulet" } }
#       ]
#     }
# } }';

my $result = $User_Agent->post("http://".$o_host.":".$o_port."/_search?size=".$o_size, Content => $o_filter);

if ($result->is_success) {
    debugging("Getting index data from request");
  

    my $obj = decode_json($result->decoded_content);

    $hits = $$obj{'hits'}{'hits'};
  
    foreach my $singlehits ( @$hits ) { 

      my $curpath   = JSON::Path->new($o_column_list);
      push @curTuple, $curpath->values($singlehits);
      
      debugging(Dumper(@curTuple));
    }
}
else {
    print $result->status_line, "\n";
    exit 2
}


sub GetIndexCount {
   
  my @AlreadyPerformed;
  my @TempIndex = 0;
  
  debugging("Dumping data....\n");

  
  if (@curTuple) {
    my $currentindex=0;
    foreach (@curTuple) {
     debugging("$_\n");
     $currentindex++;
    }
  $GetIndexCount = $currentindex;
  }
}

# ============================================================================
# ================================== MAIN ====================================
# ============================================================================

if ( $o_check_type eq "GetIndexCount") {
  GetIndexCount();
  if ( $GetIndexCount < 0 ) {
    print "CRITICAL: Can't request ELK.\n";
    exit $ERRORS{"CRITICAL"};
  }
  
  $final_status = "OK";
  if ($GetIndexCount >= $opt_w) { $final_status = "WARNING"; }
  if ($GetIndexCount >= $opt_c) { $final_status = "CRITICAL"; }

$perfdata = sprintf("%s=%d;%d;%d ", $o_column_label, $GetIndexCount,$opt_w,$opt_c);
print sprintf("$final_status: (%d) results found.",$GetIndexCount);
  if ( defined($o_verb) ) {
    debugging("Verbose demande");
    print sprintf(" click for detail.\n");
    foreach ( @curTuple ){
      $_ =~ s/([^[:ascii:]]+)/unidecode($1)/ge;
    }
    foreach (@curTuple) {
      print sprintf("%s\n",$_);
    }
    print sprintf("Last was:".$curTuple[-1]."|$perfdata\n", $GetIndexCount);
  }
  else {
    print sprintf(" Last was:".$curTuple[-1]."|$perfdata\n", $GetIndexCount);
  }

exit $ERRORS{$final_status};  
}