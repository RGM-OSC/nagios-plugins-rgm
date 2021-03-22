#!/usr/bin/perl -w
#
# check_adic.pl - nagios plugin for Scalar tape libraries
#
# Martin Niedworok (martin.niedworok@gmx.de)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

use strict;
use Getopt::Long;
use File::Basename;
use Net::SNMP;

my $PROGNAME = basename($0);
my $opt_H = "";
my $opt_C = "public";
my $opt_help;
my @status;

# Getting options
Getopt::Long::Configure('bundling');
GetOptions(
    "host|H=s" 			=> \$opt_H,
    "community|C=s" 	=> \$opt_C,
	"help"         		=> \$opt_help,
	"h"            		=> \$opt_help
);

if ( !$opt_H || $opt_help ) {
	print_usage();
}

# Getting SNMP output
my($session, $error) = Net::SNMP->session(
	-hostname	=>	$opt_H,
	-community	=>	$opt_C
);

my %oids = (
	Power			=> '.1.3.6.1.4.1.3764.1.10.10.12.1.0',
	Cooling			=> '.1.3.6.1.4.1.3764.1.10.10.12.2.0',
	Control			=> '.1.3.6.1.4.1.3764.1.10.10.12.3.0',
	Connectivity	=> '.1.3.6.1.4.1.3764.1.10.10.12.4.0',
	Robotics		=> '.1.3.6.1.4.1.3764.1.10.10.12.5.0',
	Media			=> '.1.3.6.1.4.1.3764.1.10.10.12.6.0',
	Drive			=> '.1.3.6.1.4.1.3764.1.10.10.12.7.0',
);

my %subsystems = (
	1	=>	'Power',
	2	=>	'Cooling',
	3	=>	'Control',
	4	=>	'Connectivity',
	5	=>	'Robotics',
	6	=>	'Media',
	7	=>	'Drive',
);

my %prio = (
	2	=>	'1',
	7	=>	'2',
	3	=>	'3',
	4	=>	'4',
	6	=>	'5',
	5	=>	'6',
	1	=>	'7',
);

my $result = $session->get_request(
	-varbindlist => [$oids{Power},
					$oids{Cooling},
					$oids{Control},
					$oids{Connectivity},
					$oids{Robotics},
					$oids{Media},
					$oids{Drive}]
);

$session->close;

my %resulthash = %$result;

my $key;
my @keys = sort keys %resulthash;

for (my $j = 0; $j < 8; $j++) {$status[$j] = ""};

# Putting the checked systems in a status array
my $i = 1;
foreach $key (@keys) {
	$_ = $resulthash{$key};
	$status[$prio{$_}] .= $i; 
	$i++;
}

# Iterating over the status array and searching the highest prio
if($status[1] ne "") {
	myexit('CRITICAL', "failed subsystems: " . build_output($status[1]));
} elsif($status[2] ne "") {
	myexit('CRITICAL', "invalid subsystems: " . build_output($status[2]));
} elsif($status[3] ne "") {
	myexit('WARNING', "degraded subsystems: " . build_output($status[3]));
} elsif($status[4] ne "") {
	myexit('WARNING', "warning subsystems: " . build_output($status[4]));
} elsif($status[5] ne "") {
	myexit('UNKNOWN', "unknown subsystems: " . build_output($status[5]));
} elsif($status[6] ne "") {
	myexit('OK', "informational subsystems: " . build_output($status[6]));
} elsif($status[7] ne "") {
	myexit('OK', "all subsystems ok.");
}

# Getting the subsystems names into an output string
sub build_output {
	my @input = split(//, $_[0]);
	my $output;
	while (@input) {
		$output .= $subsystems{shift(@input)};
		$output .= " ";
	}
	return $output;
}

sub print_usage {
	print <<EOU;
    Usage: $PROGNAME [ -H host ] [ -C SNMP-community ]

    Options:

    -H --host
        Hostname 
    -C --community
        SNMP-community
EOU

	myexit( 'UNKNOWN', $PROGNAME );
}

sub myexit {
	my $time;
	my $date;

	my ( $state, $text ) = @_;

	my %STATUS_CODE =
	  ( 'UNKNOWN' => '-1', 'OK' => '0', 'WARNING' => '1', 'CRITICAL' => '2' );

	my $out = $state;
	$out .= " - ";
	$out .=  $text;
	$out .= chr(10);

	print $out;

	exit $STATUS_CODE{$state};
}
