#!/usr/bin/perl -w
#
# check_cisco_aironet_clients - A simple plugin to check connected clients to an Aironet device
#
# Copyright (c) 2012 Jonathan Petersson <jpetersson@op5.com>
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


use Net::Telnet::Cisco;
use Getopt::Std;
use File::Basename qw(basename);
use Net::MAC;

my %options=();
getopts("H:U:P:I:hCc:w:", \%options);

my $hostname = $options{H};
my $username = $options{U};
my $password = $options{P};
my $interface = $options{I};
my $sclients = $options{C};
my $warning = $options{w};
my $critical = $options{c};

if ($hostname eq "" || $username eq "" || $password eq "" || defined($options{h})) {
    print "Usage: ".basename($0)." -H <hostname> -U <username> -P <password> [ -I <interface> ] [ -w <warning> -c <critical> ]\n";
    exit 1;
}

my $session = new Net::Telnet::Cisco->new(Host => $hostname);
$session->login($username, $password);
my $command = "sh dot11 statistics client-traffic";
if (defined($interface)) {
    $command = $command . " interface $interface";
}
my @lines = $session->cmd("$command");
my $line;
my $clients="";
if (defined($sclients)){$clients = "\nClients:\n";}
my $counter = 0;
foreach (@lines) {
    if ($_ =~ /([a-z0-9]+\.[a-z0-9]+\.[a-z0-9]+)\s+[0-9]{1,2}\s+[0-9]+.*/) {
	my $mac = Net::MAC->new('mac' => $1);
	my $dec_mac = $mac->convert(
	        'base' => 16,         # convert from base 16 to base 10
	        'bit_group' => 8,     # octet grouping
	        'delimiter' => ':'    # dot-delimited
	    ); 
	
	if (defined($sclients)){
	    $clients = $clients . "$dec_mac\n";
	}

	$counter = $counter+1;
    }
}

my $exit=0;
my $message="OK";
if (defined($critical) && defined($warning)) {
    if ($critical ne "" && $warning ne "") {
	if ($critical < $counter) {
	    $message = "CRITICAL";
	    $exit=1;
	} elsif ($warning < $counter) {
	    $message = "WARNING";
	    $exit=2;
	}
    }
}

print "Status: $message, Connected clients: $counter $clients|Clients=$counter;\n";
exit $exit;