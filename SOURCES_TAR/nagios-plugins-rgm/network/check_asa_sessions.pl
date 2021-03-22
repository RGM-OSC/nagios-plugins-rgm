#!/usr/bin/perl -w
#    
#  (c) 2008  Marc Patino Gómez (marcpatino at gmail dot com)
#            
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Netsaint);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
#######################################################################
# check_asa_sessions - script for checking asa stablished sessions
# on Cisco ASA clusters using SNMP
#
# Version: 0.1
# Changelog: 
# 	2008-06-09: Initial version created

use strict;
use Net::SNMP;
use Getopt::Long;
use lib '/usr/lib/nagios/plugins';
use utils qw (%ERRORS $TIMEOUT);

my $hostname;
my $community;
my $debug;
my $timeout;
my $retries;
my $help;
my $warnning;
my $critical;

Getopt::Long::Configure('bundling');
GetOptions (
	"help" 		=> \$help,
	"hostname=s" 	=> \$hostname,
	"community=s" 	=> \$community,
	"debug" 	=> \$debug,
	"timeout=i"	=> \$timeout,
	"retries=i"	=> \$retries,
	"h" 		=> \$help,
	"H=s"	 	=> \$hostname,
	"C=s"	 	=> \$community,
	"d" 		=> \$debug,
	"t=i"		=> \$timeout,
        "w=s"		=> \$warnning,
        "c=s"		=> \$critical,
	"r=i"		=> \$retries
);

unless (defined ($debug)) {
	$debug = 0;
}
unless (defined ($timeout)) {
	$timeout = $TIMEOUT;
}
unless (defined ($retries)) {
	$retries = 1;
}

###########################################
# sub: help
# Prints help information

sub help () {
	print <<USE;
Usage: check_pix_failover [options]
where options is
-h, --help		Print this text
-H, --hostname		Hostname (required)
-C, --community		SNMP Community (required)
-w, --warnning		warnning connections (required)
-c, --critical		critical connections (required)
-d, --debug		Show debug information
-t, --timeout		Timeout value in seconds (defaults to $TIMEOUT)
-r, --retries		Number of retries (defaults to 1)

Note that every retry has its own timeout value, for example,
if timeout is 15 and retries is 1, maximum timeout would be 30s.

USE
	exit ($ERRORS{OK});
};

###########################################
# sub: status_request
# The function that does the actual snmp
# requests

sub status_request () {
	my ($hostname, $community, $debug, $timeout, $retries) = @_;
	my %status;
	my %snmp_string = (
		'sessions' => '.1.3.6.1.4.1.9.9.147.1.2.2.2.1.5.40.6',
	);
	my ($sessions);
	my ($session, $error) = Net::SNMP->session (    -hostname => $hostname,
							-community => $community,
							-retries => $retries,
							-debug => $debug,
							-timeout => $timeout);

	unless ($session) {
		print "Session error: $error\n";
		exit $ERRORS{UNKNOWN};
	}
	my $result = $session->get_request ($snmp_string{sessions});
	foreach my $key (keys %snmp_string) {
		$status{$key} = $result->{$snmp_string{$key}};
	}
	unless (defined ($status{sessions})) { 
		print "Error: Check timed out\n";
		exit ($ERRORS{UNKNOWN});
	}
	$session->close;
	return ($status{sessions});
}

# Check command line arguments

&help () if ($help);
&help () unless ($hostname && $community);

# Get the status for the active and standby unit

my ($sessions) = &status_request ($hostname, $community, $debug, $timeout, $retries);

# Determine status of cluster

if ($sessions < $warnning) {
	print "OK - Cisco ASA sessions:$sessions\n";
	exit ($ERRORS{OK});
} elsif ($sessions > $warnning && $sessions < $critical) {
	print "Warning -Cisco ASA sessions:$sessions\n"; 
	exit ($ERRORS{WARNING});
} elsif ($sessions > $critical) {
	print "Critical - Cisco ASA sessions:$sessions\n"; 
	exit ($ERRORS{CRITICAL});
} else {
	print "Unknown - Cisco ASA $sessions\n";
	exit ($ERRORS{UNKNOWN});
}


