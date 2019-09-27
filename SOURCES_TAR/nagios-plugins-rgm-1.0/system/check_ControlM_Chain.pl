#!/usr/bin/perl
## 
## License: GPL
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

use strict;
use POSIX qw(locale_h);	
use POSIX qw(strftime);
use DateTime;
use File::Basename;
use XML::Simple;
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_F $opt_t $host $connector $verbose $PROGNAME $critical $warning $Revision);

use utils qw(%ERRORS &print_revision &support &usage);


$PROGNAME="check_ControlM_Chain.pl";
sub print_help ();
sub print_usage ();


setlocale(LC_CTYPE, "en_EN");
$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$Revision="0.1";

my $dtnow = DateTime->now;

my $debug;
my $chain;
my @LastCheck;

Getopt::Long::Configure('bundling');
GetOptions
        ("V"     => \$opt_V,           "version"      => \$opt_V,
         "h"     => \$opt_h,           "help"         => \$opt_h,
         "v"     => \$verbose,         "verbose"      => \$verbose,
         "d"     => \$debug,           "debug"        => \$debug,
         "C=s"   => \$chain,           "chain=s"      => \$chain,
         "w=i"   => \$warning,         "warning=i"    => \$warning,
         "c=i"   => \$critical,        "critical=i"   => \$critical);

if ($opt_V) {
        print "$PROGNAME Revision: $Revision\n";
        exit $ERRORS{'OK'};
}

$opt_t = $utils::TIMEOUT ;      # default timeout


if ($opt_h) {print_help(); exit $ERRORS{'OK'};}


my $ChainFile = "/tmp/tmp-internal-" . $chain . "/Last_State.txt";
print "ChainFile: $ChainFile \n" if $debug;

unless (-f $ChainFile ) {
        print "Cannot find \"$ChainFile\"\n";
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $chain) {
        print "Missing Chain\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $warning) {
        print "Missing WARNING in seconds\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $critical) {
        print "Missing CRITICAL in seconds\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

if ( $warning > $critical ) {
        print "Warning cannot be greater than Critical\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

open (MYFILE, $ChainFile);
 while (<MYFILE>) {
 	chomp;
 	@LastCheck= split ( /\s/, $_ );
 }
 close (MYFILE);
print "Warning: $warning    Critical: $critical\n" if $debug;

my @LastTupleDate = split ( '-', @LastCheck[0] );
my @LastTupleTime = split ( ':', @LastCheck[1] );

print "LastCheck: @LastCheck \n" if $debug;
print "Date: @LastTupleDate \n" if $debug;
print "Time: @LastTupleTime \n" if $debug;

my $dtlastcheck =  DateTime->new(
      year       => $LastTupleDate[0],
      month      => $LastTupleDate[1],
      day        => $LastTupleDate[2],
      hour       => $LastTupleTime[0],
      minute     => $LastTupleTime[1],
      second     => $LastTupleTime[2],
      time_zone   => 'Europe/Paris',
      );

my $epoch_dtnow = $dtnow->epoch();
my $epoch_dtlastcheck = $dtlastcheck->epoch();

print "Now: " if $debug;
print $epoch_dtnow if $debug;
print " \n" if $debug;

print "Last Check: " if $debug;
print $epoch_dtlastcheck if $debug;
print " \n" if $debug;

print "GAP Time in seconde: " if $debug;
my $gap = $epoch_dtnow - $epoch_dtlastcheck;
print $gap if $debug;
print " \n" if $debug;

if ( $gap == 0  || not defined ($gap) ){
        print "CRITICAL: Cannot get last execution time for the chain $chain | lastcheck=0\n";
        exit $ERRORS{'CRITICAL'};
}

if ( $critical < $gap ) {
   print "CRITICAL: Too much time enlapse since the last execution of $chain. | lastcheck=$gap \n";
   exit $ERRORS{'CRITICAL'};
}

if ( $warning < $gap ) {
    print "WARNING: Time enlapse since the last execution of $chain is too high. | lastcheck=$gap\n";
    exit $ERRORS{'WARNING'};
}

   print "OK: The chain $chain was check $gap seconds ago. | lastcheck=$gap\n";

exit $ERRORS{'OK'};

#
# Additional functions
#

sub print_usage () {
    print "Usage:
   $PROGNAME -C Chain -w warning -c critical [-d] [-h]
   $PROGNAME --help
   $PROGNAME --version
";
}

sub print_help () {
        print "$PROGNAME Revision $Revision\n \n";
        print "Copyright (c) 2013 Michael Aubertin <michael.aubertin\@gmail.com> Licenced
under GPLV2\n";

        print_usage();
        print "
-C, --Chain
   The chain specified in ControlM execution script
-d, --verbose
   Print some extra debugging information (not advised for normal operation)
-w, --warning
   Seconds before expiration
-c, --critical
   Seconds before expiration
\n";
}
