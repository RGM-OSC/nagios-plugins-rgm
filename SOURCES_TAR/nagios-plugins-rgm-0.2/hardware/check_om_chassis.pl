#!/usr/bin/perl -wT
#
# Nagios Plugin to check the chassis components of
# Dell server systems using "omreport" from Dell OpenManage.
#
# Requires Dell OpenManage
#
# (C) 2005 - 2009 Riege Software International GmbH
# Mollsfeld 10
# 40670 Meerbusch
# Germany
#
# Published under the Genral Public License, Version 2.
# 
# Author: Gunther Schlegel <schlegel@riege.com>
#
# V0.0.1  20050824 gs	new script, reused some parts from
#						check_om_storage.pl
# V0.1.0  20060516 gs	added /usr/lib/nagios/plugins to default plugin search path
# V0.1.1  20060609 gs	fix help message inconsistency
# V0.2.0  20081022 gs	added sudo mode
# V0.2.1  20090109 gs	fix: only use sudo if requested
# 						credits to: Gianluca Cecchi
#
# $Id: check_om_chassis.pl,v 1.4 2009/01/09 17:19:54 schlegel Exp $

# Modules
use strict;
use Getopt::Long;
use File::Basename;
use lib qw(/usr/local/nagios/libexec /usr/lib/nagios/plugins);
use utils qw (%ERRORS);

# untaint Environment
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$ENV{'PATH'}='/bin:/usr/bin';

# variables
my ($debug,$help,$sudo)='1';
my $om='/opt/dell/srvadmin/sbin/omreport';
my $omcmd="$om chassis";
my $omfmt='-fmt cdv';
my $result=$ERRORS{'UNKNOWN'};
my @checks=qw(fans intrusion memory processors pwrsupplies temps volts);

my @messages;
my $I;
my $J;
my $check;
my @results;
my %result;

# Process command line
GetOptions ('VERBOSE+' => \$debug,'HELP|?' => \$help, 'SUDO' => \$sudo);
$help and usage();
$sudo and $omcmd="/usr/bin/sudo $omcmd";

# Main
if ( -x $om ) {
	foreach $check (@checks) {
		print "Checking $check\n" if $debug;
		@results=`$omcmd $check $omfmt`;
		print @results if $debug > 1;
		chomp @results;

		foreach $I (@results) {
			undef (%result);
			if (($result{'id'},$result{'status'},$result{'name'},$result{'value'}) = ($I =~ /^(\d+);(\w+);(.+?);(.+?);.*/)) {
				print "$result{'name'} is $result{'status'} ($result{'value'})\n" if $debug;
				next if ( $check eq 'processors' and $result{'value'} eq '[Not Occupied]' );

				if ( $result{'status'} ne 'Ok' ) {
					if ( $result{'status'} eq 'Noncritical' ) {
						$result=addresult($result,$ERRORS{'WARNING'});
					} else {	
						$result=addresult($result,$ERRORS{'CRITICAL'});
					}
					push @messages, "$result{'name'} is $result{'status'} ($result{'value'})";
				} else {
					$result=addresult($result,$ERRORS{'OK'});
				}
			}
		}	
	}
} else {
	push @messages,"Error: $om not found\n\n";
	usage();
}


# Script end
print "\nResult: $result\n" if $debug;
writemessages(@messages);
exit $result;

# Subs

sub addresult {
	my $oldresult=shift @_;
	my $newresult=shift @_;

	if ( $oldresult eq $ERRORS{'UNKNOWN'} or $newresult gt $oldresult ) {
		return $newresult;
	}

	return $oldresult;
}	

sub writemessages {
	my @messages = @_;

	unshift @messages, '[' if $#messages >= 0;

	foreach (keys %ERRORS) {
		unshift @messages, "$_" if $ERRORS{$_} == $result;
	}	

	push @messages, ']' if $#messages > 0;

	print 'CHASSIS: ',substr ((join " ",@messages),0,71),"\n";
}

sub usage {
	writemessages(@messages);
	print (basename $0." (C) 2005 - 2008 Riege Software International GmbH\n\n");
	print "This script analyzes the state of DELL chassis using the omreport command\nfrom the DELL OpenManage 4.3 or later distribution. As omreport requires root\nprivileges, please add the following line to /etc/sudoers (\"nagios\" is the user\nrunning the script and may be a different user on your system depending on your\nNagios Plugins and nrpe setup):\n\nnagios      ALL= NOPASSWD: /usr/bin/omreport *\n\nUsage:\n";
	print (basename $0." [--verbose] [--help] [--sudo]\n");
	print "  --help:    Display exactly this text.\n";
	print "  --sudo:    Use sudo to run omreport.\n";
	print "  --verbose: run script in debug mode.\n";
	exit $ERRORS{'UNKNOWN'};
}
	
sub exitmessage {
	my $result=shift @_;

	print join ' ',@messages."\n";
	exit $result; 
}	

# vim: autoindent number ts=4
