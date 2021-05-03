#!/usr/bin/perl

##################################################################################
##################################################################################
#######################  Made by Tytus Kurek on October 2012  ####################
##################################################################################
##################################################################################
####   This is a Nagios Plugin destined to check CPU usage on Cisco devices   ####
##################################################################################
##################################################################################

use strict;
use vars qw($community $critical $IP $warning);

use Getopt::Long;
use Pod::Usage;

# Subroutines execution

getParameters ();
checkCPUUsage ();

# Subroutines definition

sub checkCPUUsage ()	# Checks CPU usage via SNMP
{
	my $OID = '.1.3.6.1.4.1.9.9.109.1.1.1.1';
	my $OID1m = '.7.1';
	my $OID5m = '.8.1';
	my $OID5s = '.6.1';
	my $version = '2c';

	my $command = "/usr/bin/snmpwalk -v $version -c $community $IP $OID 2>&1";
	my $result = `$command`;

	if ($result =~ m/^Timeout.*$/)
	{
		my $output = "UNKNOWN! No SNMP response from $IP.";
		my $code = 3;
		exitScript ($output, $code);
	}

	my $extendedOID = $OID . $OID5s;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.109\.1\.1\.1\.1\.6\.1\s=\sGauge32:\s(\d+)$/;
	my $load5s = $1;

	my $extendedOID = $OID . $OID1m;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.109\.1\.1\.1\.1\.7\.1\s=\sGauge32:\s(\d+)$/;
	my $load1m = $1;

	my $extendedOID = $OID . $OID5m;
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/^SNMPv2-SMI::enterprises\.9\.9\.109\.1\.1\.1\.1\.8\.1\s=\sGauge32:\s(\d+)$/;
	my $load5m = $1;

	$warning =~ m/^(\d+),(\d+),(\d+)$/;
	my $warning5s = $1;
	my $warning1m = $2;
	my $warning5m = $3;
	$critical =~ m/^(\d+),(\d+),(\d+)$/;
	my $critical5s = $1;
	my $critical1m = $2;
	my $critical5m = $3;

	my ($output5s, $code5s) = countCPUUsage ($load5s, $warning5s, $critical5s, '5s');
	my ($output1m, $code1m) = countCPUUsage ($load1m, $warning1m, $critical1m, '1m');
	my ($output5m, $code5m) = countCPUUsage ($load5m, $warning5m, $critical5m, '5m');

	if (($code5s == 2) || ($code1m == 2) || ($code5m == 2))
	{
		my $output = "CRITICAL! CPU usage: $output5s, $output1m, $output5m. | 'CPU 5s'=$load5s%, 'CPU 1m'=$load1m%, 'CPU 5m=$load5m%";
		my $code = 2;
		exitScript ($output, $code);
	}

	if (($code5s == 1) || ($code1m == 1) || ($code5m == 1))
	{
		my $output = "WARNING! CPU usage: $output5s, $output1m, $output5m. | 'CPU 5s'=$load5s%, 'CPU 1m'=$load1m%, 'CPU 5m=$load5m%";
		my $code = 1;
		exitScript ($output, $code);
	}

	else
	{
		my $output = "OK! CPU usage: $output5s, $output1m, $output5m. | 'CPU 5s'=$load5s%, 'CPU 1m'=$load1m%, 'CPU 5m=$load5m%";
		my $code = 0;
		exitScript ($output, $code);
	}
}

sub countCPUUsage
{
	my $output;
	my $code; 

	if ($_[0] < $_[1])
	{
		$output = "$_[3] - $_[0]%";
		$code = 0;
	}

	elsif (($_[0] >= $_[1]) && ($_[0] < $_[2]))
	{
		$output = "$_[3] - $_[0]% exceeds threshold of $_[1]%";
		$code = 1;
	}

	else
	{
		$output = "$_[3] - $_[0]% exceeds threshold of $_[2]%";
		$code = 2;
	}

	return ($output, $code);
}

sub exitScript ()	# Exits the script with an appropriate message and code
{
	print "$_[0]\n";
	exit $_[1];
}

sub getParameters ()	# Obtains script parameters and prints help if needed
{
	my $help = '';

	GetOptions ('help|?' => \$help,
		    'C=s' => \$community,
		    'H=s' => \$IP,
		    'crit=s' => \$critical,
		    'warn=s' => \$warning)

	or pod2usage (1);
	pod2usage (1) if $help;
	pod2usage (1) if (($community eq '') || ($critical eq '') || ($IP eq '') || ($warning eq ''));
	pod2usage (1) if (($IP !~ m/^\d+\.\d+\.\d+\.\d+$/) || ($critical !~ m/^\d{1,3},\d{1,3},\d{1,3}$/) || ($warning !~ m/^\d{1,3},\d{1,3},\d{1,3}$/));

=head1 SYNOPSIS

check_asa_cpu.pl [options] (-help || -?)

=head1 OPTIONS

Mandatory:

-H	IP address of monitored Cisco ASA device

-C	SNMP community

-warn	Warning threshold in % for 5s, 1m and 5m CPU usage separated by commas

-crit	Critical threshold in % for 5s, 1m and 5m CPU usage separated by commas

=cut
}
