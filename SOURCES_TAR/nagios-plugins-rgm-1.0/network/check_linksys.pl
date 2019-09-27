#!/usr/bin/perl -

# COPYRIGHT:
#  
# This software is Copyright (c) 2008 NETWAYS GmbH, Birger Schmidt
#                                <info@netways.de>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from http://www.fsf.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.fsf.org.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to NETWAYS GmbH.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# this Software, to NETWAYS GmbH, you confirm that
# you are the copyright holder for those contributions and you grant
# NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.


#
# Some of the code used in this plugin has been taken from various open-
# source plugins for Fujitsu-Siemens servers found in the internet.
#


#
# please test your changes to this code for compliance with the syntax 
# rules of the nagios embedded perl interpreter. please run it from 
# within npi-new which you can find in the contrib dir of your nagios
# distibution.
#


=head1 NAME

check_linksys.pl - Nagios-Check Plugin for Linksys Router and Switches

=head1 SYNOPSIS

check_linksys.pl -H|--host=<host> -C|--community=<SNMP community string>
				[-e|--ethernetinterfaces]
				[-u|--uptime]
				[-d|--description]
                [-t|--timeout=<timeout in seconds>]
                [-v|--verbose=<verbosity level>]
                [-h|--help] [-V|--version]
  
Checks a Linksys Router or Switch using SNMP.

=head1 OPTIONS

=over 4

=item -H|--host=<name-or-ip>

Hostname or ip address of the server to check

=item -C|--community=<SNMP community string>

The SNMP community.

=item -e|--ethernetinterfaces

Check if RFC1213-MIB::ifType is ethernet-csmacd(6) and RFC1213-MIB::ifOperStatus is up(1) or down(2).

Counts and print the results.

=item -u|--uptime

Print DISMAN-EVENT-MIB::sysUpTimeInstance as human readable string. For example: 7 days, 0:07:13.00 up

=item -d|--description

Print RFC1213-MIB::sysDescr.0 as string. For example: [24-Port Managed 10/100 Switch w/WebView]

=item -t|--timeout=<timeout in seconds>

Time in seconds to wait before script stops.

=item -v|--verbose=<verbosity level>

Enable verbose mode (levels: 1,2).

=item -V|--version

Print version an exit.

=item -h|--help

Print help message and exit.

=cut


use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Pod::Usage;
use Net::SNMP;


sub printResultAndExit {

	# print check result and exit

	my $exitVal = shift;

	print 'check_linksys: ';

	print " @_" if (defined @_);

	print "\n";

	# stop timeout
	alarm(0);

	exit($exitVal);
}


sub getSNMPRequest {

	my $oid = shift;

	print 'Checking OID \'' . $oid . '\'... ' if ($main::verbose >= 100);

	my $result = $main::session->get_request($oid);
	printResultAndExit(3, "UNKNOWN", 'Error: get_request(): ' . $main::session->error) unless (defined $result);

	print 'result: ' . $result->{$oid} . "\n" if ($main::verbose >= 100);

	return $result->{$oid};
}


# version string
my $version = '0.1';


# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');

# define global OIDs
my $oid_sysDescr = '.1.3.6.1.2.1.1.1.0';				# RFC1213-MIB::sysDescr.0
														# STRING: "24-Port Managed 10/100 Switch w/WebView"
my $oid_commonFirmwareVer = '.1.3.6.1.4.1.3955.1.1.0';	# enterprises.linksys.common.commonFirmwareVer.0
my $oid_sysUpTime = '.1.3.6.1.2.1.1.3.0';				# DISMAN-EVENT-MIB::sysUpTimeInstance
														# Timeticks: (60523300) 7 days, 0:07:13.00
my $oid_ifType = '.1.3.6.1.2.1.2.2.1.3';				# RFC1213-MIB::ifType
														# INTEGER: ethernet-csmacd(6)
my $oid_ifOperStatus = '.1.3.6.1.2.1.2.2.1.8';			# RFC1213-MIB::ifOperStatus
														# INTEGER: up(1), down(2)


# init command-line parameters
my $argvCnt					= $#ARGV + 1;
my $host					= '';
my $community				= '';
my $timeout					= 0;
my $show_version			= undef;
my $show_etherIfaces		= undef;
my $show_upTime				= undef;
my $show_description		= undef;
my $show_firmwareversion	= undef;
our $verbose				= 0;
my $help					= undef;


# init left variables
my $globalResult			= undef;
my $result					= undef;
our $session;
my $error					= '';
my @msg						= ('');
my $exitVal					= undef;
my $etherIfacesUp			= undef;
my $etherIfacesDown			= undef;


# get command-line parameters
GetOptions(
   "H|host=s"				=> \$host,
   "C|community=s"			=> \$community,
   "t|timeout=i"			=> \$timeout,
   "v|verbose=i"			=> \$main::verbose,
   "V|version"				=> \$show_version,
   "e|ethernetinterfaces"	=> \$show_etherIfaces,
   "u|uptime"				=> \$show_upTime,
   "d|description"			=> \$show_description,
#   "f|firmwareversion"		=> \$show_firmwareversion,
   "h|help"					=> \$help,
) or pod2usage({
	-msg     => "\n" . 'Invalid argument!' . "\n",
	-verbose => 1,
	-exitval => 3
});


# check command-line parameters
pod2usage(
	-verbose => 2,
	-exitval => 3,
) if ($help || !$argvCnt);

pod2usage(
	-msg		=> "\n$0" . ' - version: ' . $version . "\n",
	-verbose	=> 1,
	-exitval	=> 3,
) if ($show_version);

pod2usage(
	-msg		=> "\n" . 'No host specified!' . "\n",
	-verbose	=> 1,
	-exitval	=> 3
) if ($host eq '');

pod2usage(
	-msg		=> "\n" . 'No community specified!' . "\n",
	-verbose	=> 1,
	-exitval	=> 3
) if ($community eq '');


# set timeout
local $SIG{ALRM} = sub {
	print 'check_linksys: UNKNOWN: Timeout' . "\n";
	exit(3);
};
alarm($timeout);

# connect to SNMP host
($main::session, $error) = Net::SNMP->session(
	Hostname	=> $host,
	Community	=> $community
);

printResultAndExit(3, "UNKNOWN", "Error: session(): $error") unless $main::session;


if ($show_description) {
	# fetch description
	push (@msg, "[" . getSNMPRequest($oid_sysDescr) . "]");
}


#if ($show_firmwareversion) {
#	# fetch Firmware Version from Linksys MIB (unfortunatly not supported on many Linksys Hardware)
#	push (@msg, "Version " . getSNMPRequest($oid_commonFirmwareVer));
#}

if ($show_upTime) {
	# fetch Uptime
	push (@msg, getSNMPRequest($oid_sysUpTime) . " up");
}

if ($show_etherIfaces) {

	my %etherIfaces;

	$result = $main::session->get_table(-baseoid => $oid_ifType);
	my %ifTypes = %{$result};
	# store all ethernet interfaces in a hash
	while (my ($key, $value) = each(%ifTypes)){
		if ($value == 6) {
			$key =~ s/.*?([^.]+)$/$1/;
			$etherIfaces{$key} = $value;
		}
	}
	undef %ifTypes;

	$etherIfacesUp = 0;
	$etherIfacesDown = 0;

	$result = $main::session->get_table(-baseoid => $oid_ifOperStatus);
	my %ifOperStatus = %{$result};
	while (my ($key, $value) = each(%ifOperStatus)){
		$key =~ s/.*?([^.]+)$/$1/;
		if (exists $etherIfaces{$key}) {
			# it's an ethernet interface
			$etherIfaces{$key} = $value;
			if ($value == 1) {
				# and it's up
				$etherIfacesUp++;

				# the plugin will report propper monitoring values from a RV042
				# for ifOperStatus as soon as linksys fixed the snmp
				# implementation on the RV042 router
			}
			elsif ($value == 2) {
				# and it's down
				$etherIfacesDown++;
			} 
			else {
				# it claims to be ethernet but it's neighter up nor down
				# this could be a vlan for example, we don't want it in our hash
				delete $etherIfaces{$key};
			}
		}
	}
	undef %ifOperStatus;


	if ($main::verbose >= 100) {
		foreach my $key (sort { $a <=> $b } keys %etherIfaces) {
			print "interface $key = $etherIfaces{$key}\n";
		} 
	}

	my $etherIfaces = $etherIfacesUp + $etherIfacesDown;

	if ($main::verbose >= 1) {
		push (@msg, "$etherIfaces Ethernet Interfaces ($etherIfacesUp Up, $etherIfacesDown Down)");
	}
	else {
		push (@msg, "ifUp: $etherIfacesUp, ifDown: $etherIfacesDown");
	}
}


# set exit value

if (not defined $etherIfacesUp) {
	$exitVal = 0; # ok (we don't have checked for Ifaces)
} elsif ($etherIfacesUp == 0) {
	# no interface up? but we got a response to our snmp request - this must be an error.
	$exitVal = 2; # critical
} elsif (1) {
	$exitVal = 0; # ok
} elsif (1) {
	$exitVal = 1; # warning
} else {
	$exitVal = 3; # unknown
}


# close SNMP session
$main::session->close;

# print check result and exit
printResultAndExit(
	$exitVal, 
	$state[$exitVal], 
	($error ne '') ? ' -' . chop($error) : '',
	($#msg > 0)    ? join(' - ', @msg)   : ''
);


# vim: ts=4 shiftwidth=4 softtabstop=4 
#backspace=indent,eol,start expandtab
