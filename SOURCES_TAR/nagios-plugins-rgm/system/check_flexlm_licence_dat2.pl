#! /usr/bin/perl -w
#
# usage:
#    check_flexlm_licence_dat.pl
#
# Check available flexlm licenses.
# License: GPL
# michael.aubertin@gmail.com based on check_flexlm script and Fabien Combernous informations


use POSIX qw(locale_h); 
use POSIX qw(strftime); 
use Time::Piece;
setlocale(LC_CTYPE, "en_EN");

use strict;
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_F $opt_t $host $connector $verbose $PROGNAME $critical $warning $Revision);
use utils qw(%ERRORS &print_revision &support &usage);

$PROGNAME="check_flexlm_licence_dat.pl";

sub print_help ();
sub print_usage ();

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$Revision="0.2";

sub print_usage () {
    print "Usage:
   $PROGNAME -C connector -H Hostname -w warning -c critical [-v] [-V] [-h]
   $PROGNAME --help
   $PROGNAME --version
";
}

sub print_help () {
        print "$PROGNAME Revision $Revision\n \n";
        print "Copyright (c) 2013 Michael Aubertin <michael.aubertin\@gmail.com> Licenced under GPLV2\n";
        
        print_usage();
        print "
-C, --connector
   Name of port connector to flexlm (ex: 7788)
-v, --verbose
   Print some extra debugging information (not advised for normal operation)
-H, --host
   Hostname of FlexLm licence server
-V, --version
   Show version and license information
-h, --help
   Show this help screen
-w, --warning
   Days before expiration
-c, --critical
   Days before expiration
\n";
}

Getopt::Long::Configure('bundling');
GetOptions
        ("V"     => \$opt_V,           "version"      => \$opt_V,
         "h"     => \$opt_h,           "help"         => \$opt_h,
         "v"     => \$verbose,         "verbose"      => \$verbose,
         "C=s"   => \$connector,       "connector=s"  => \$connector,
         "H=s"   => \$host,            "host=s"       => \$host,
         "w=i"   => \$warning,         "warning=i"    => \$warning,
         "c=i"   => \$critical,        "critical=i"   => \$critical);

if ($opt_V) {
        print "$PROGNAME Revision: $Revision\n";
        exit $ERRORS{'OK'};
}

$opt_t = $utils::TIMEOUT ;      # default timeout


if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

my $lmutil = "/srv/eyesofnetwork/nagios/plugins/lmutil" ;
unless (-x $lmutil ) {
        print "Cannot find \"lmutil\"\n";
        exit $ERRORS{'UNKNOWN'};
}

my $getlicence = "/srv/eyesofnetwork/nagios/plugins/get_flex_lic.sh" ;

unless (-x $getlicence ) {
        print "Cannot find \"$getlicence\"\n";
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $host) {
        print "Missing hostname access\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $warning) {
        print "Missing WARNING in days before licence expiration\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $critical) {
        print "Missing CRITICAL in days before licence expiration\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

if ( $warning < $critical ) {
        print "Critical cannot be greater than Warning\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $connector) {
        print "Missing connector access\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}
# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
        print "Timeout: No Answer from Client\n";
        exit $ERRORS{'UNKNOWN'};
};
alarm($opt_t);

my $getlicenceAndArgs = "$getlicence $connector\@$host";


my $server = 0;
my @upsrv;
my @downsrv;  # list of servers up and down
my $Licence = "";
my $date = "";
my @line;

my $sec_today=lc(strftime "%s", gmtime);
my $lic_date="";
my $sec_lic_date;
my $sec_diff;
my $expire_days;

my $WarningState=0;
my $CriticalState=0;

print "Debug: $getlicenceAndArgs" if $verbose;

if ( ! open(CMD,"$getlicenceAndArgs |") ) {
        print "CRITICAL: Cannot run $getlicenceAndArgs\n";
        exit $ERRORS{'UNKNOWN'};
}


my $t = Time::Piece->strptime("20111121", "%Y%m%d");

while ( <CMD> ) {
        $server = 1;
        print "Debug2: $_" if $verbose;
        @line = split(' ', $_);
        $Licence = $line[0];
        $date = $line[1];

        print "Debug2: $Licence\n" if $verbose;
        print "Debug2: $date\n" if $verbose;
        
        if ( "$date" eq "0-jan-0" ) { 
             print "Debug2: $date set to infinity at least until January 19th 2038 :P \n" if $verbose;
             $date = "19-jan-2038";
        } 
        
        if ( "$date" eq "expiration" ) { 
             print "Debug2: $date set to infinity at least until January 19th 2038 :P \n" if $verbose;
             $date = "19-jan-2038";
        } 
        
        $lic_date = Time::Piece->strptime($date, "%d-%b-%Y");
        $sec_lic_date = $lic_date->strftime("%s\n"); 
        $sec_diff = $sec_lic_date - $sec_today;
        $expire_days = $sec_diff / 86400;
        $expire_days = sprintf "%d", $expire_days;
 
        print "Debug3:  Date Today in sec: $sec_today\n" if $verbose;
        print "Debug3:  Date Lic in sec: $sec_lic_date\n" if $verbose;
        print "Debug4:   Licence $Licence expire in $expire_days\n" if $verbose;
        
          if ( $expire_days < $warning ) {
                                if ( $expire_days < $critical) 
                                {
                                      $CriticalState = $CriticalState + 1;
                                      push(@downsrv, "$Licence expires in $expire_days days  ---> CRITICAL\n");                                                     
                                      print "Debug: CRITICAL:$Licence expires in $expire_days days \n" if $verbose;
                                }
                                else
                                {     
                                      $WarningState = $WarningState + 1;
                                      push(@downsrv, "$Licence expires in $expire_days days ---> WARNING\n");
                                      print "Debug: WARNING:$Licence expires in $expire_days days\n" if $verbose;
                                }                          
          } else {
                                push(@upsrv, "$Licence expires in $expire_days days ---> OK\n" );
                                print "Debug: OK: $Licence expires in $expire_days days\n" if $verbose;
          }

}

close CMD;

if ( $server == 0 ) {
        print "CRITICAL: Cannot contact licence server using $connector\@$host\n";
        exit $ERRORS{'CRITICAL'};
}

if ( $CriticalState > 0 ) { 
    print "CRITICAL: Some licences for $connector\@$host are very close to expire. Click here for detail.\n";
    foreach my $downserver (@downsrv) {
    print "$downserver";
   }
   exit $ERRORS{'CRITICAL'};
}

if ( $WarningState > 0 ) {
    print "WARNING: Some licences for $connector\@$host are close to expire. Click here for detail.\n";
    foreach my $downserver (@downsrv) {
    print "$downserver";
    }
    exit $ERRORS{'WARNING'};
}

if (scalar(@upsrv) > 0) {
   print "OK. All licences for $connector\@$host are not going to expire shortly. Click here for detail.\n";
   foreach my $upserver (@upsrv) {
      print "$upserver";
   }
}

exit $ERRORS{'OK'};