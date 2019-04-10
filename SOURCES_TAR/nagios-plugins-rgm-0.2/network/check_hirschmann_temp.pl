#!/usr/bin/perl
#
# Author : Vincent FRICOU (vincent@fricouv.eu)
#
# This script is writed under GPLv3 licence
#
# Name : check_avaya_vsp.pl
# Version 1.0-build
#
# This script is created to run as nagios plugin to check Avaya VSP switch.
# It run only with SNMP checks.
#

use POSIX qw(locale_h);
#use strict;
use Net::SNMP;
#use Getopt::Std;
use Getopt::Long;
use Data::Dumper;
use Switch;

my $Version="1.0-1";
setlocale(LC_CTYPE, "en_US");

my $countwarning=0;
my $countcritical=0;
my $output='';
my $perf='';
my $snmpsession='';
my $snmperror='';
my $output='';
my $outcode;
my $value;

use vars qw(%reverse_exit_code %exit_code);

%reverse_exit_code = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN',
);

%exit_code = (
	'Ok' => 0,
	'Warning' => 1,
	'Critical' => 2,
	'Unknown' => 3,
);

sub help {
	print "Check Hirschmann Temperature, $Version\n";
	print "GPLv3 Licence, 2017 Vincent FRICOU\n";
	print "Help : check_hirschmann_temp.pl
	-H, --hosttarget, Host Target
	-C, --community, Community
	-v, --version, SNMP Version (1 or 2)
	-w, --warning, Warning value
	-c, --critical, Critical value
	-p, --perf, Display perf data
	-h, --help Display this help\n";
	exit 1;
}

my ($o_hostaddress,$o_community,$o_warning,$o_critical,$o_help,$o_perf);

sub get_options() {
	Getopt::Long::Configure ("bundling");
	GetOptions (
		"H=s"  => \$o_hostaddress,  'hosttarget=s' => \$o_hostaddress,
		"C=s"  => \$o_community,    'community=s'  => \$o_community,
		"w=i"  => \$o_warning,      'warning=i'    => \$o_warning,
		"c=i"  => \$o_critical,     'critical=i'   => \$o_critical,
		"v=i"  => \$o_snmpversion,  'version=i'    => \$o_snmpversion,
		"h"    => \$o_help,         'help'         => \$o_help,
		"p"    => \$o_perf,         'perf'         => \$o_perf,
	);

	help() if (defined ($o_help));
	help() if (! defined $o_hostaddress && ! defined $o_community && ! defined $o_snmpversion);

	if (! $o_hostaddress) { print "Host target is not defined, Please use -H option.\n"; exit 3; }
	if (! $o_community) {print "Community is not defined. Please use -C option.\n"; exit 3; }
	if (! $o_snmpversion) {print "Version is not defined. Please use -v option.\n"; exit 3; }
}

sub init_snmp_session () {
	my %snmpparms = (
		"-hostname" => $o_hostaddress,
		"-version" => $o_snmpversion,
		"-community"	 => $o_community,
	);
	($snmpsession,$snmperror) = Net::SNMP->session(%snmpparms);
	if (!defined $snmpsession) {
		printf "SNMP: %s\n", $snmperror;
		exit 3;
	}
	return;
}

sub define_exitcode_count () {
	if ($countwarning >= $o_warning) {
		if ($countcritical >= $o_critical) {
			$outcode = $exit_code{Critical};
		} else {
			$outcode = $exit_code{Warning};
		}
	} else {
		$outcode = $exit_code{Ok};
	}
}

sub define_exitcode_perf () {
	if ($value >= $o_warning) {
		if ($value >= $o_critical) {
			$countcritical++;
			$outcode = $exit_code{Critical};
		} else {
			$countwarning++;
			$outcode = $exit_code{Warning};
		}
	} else {
		$outcode = $exit_code{Ok};
	}
}

sub outputdisplay () {
	$output =~ tr/,/\n/;
	print $output;
	exit $outcode;

}

sub get_perf_data () {
	$output=$output.'|'.$perf;
}

get_options();

my $oidAmbientTemperature = '.1.3.6.1.4.1.248.14.2.5.1.0';
my $oidHigherSetTemperature = '.1.3.6.1.4.1.248.14.2.5.2.0';
my $oidLowerSetTemperature = '.1.3.6.1.4.1.248.14.2.5.3.0';

init_snmp_session ();
my $reqambianttemp = $snmpsession->get_request(-varbindlist => [$oidAmbientTemperature]);
my $ambianttemp = $$reqambianttemp{$oidAmbientTemperature};
if ( ! $o_critical ) {
	my $reqhighalarmtemp = $snmpsession->get_request(-varbindlist => [$oidHigherSetTemperature]);
	my $reqloweralarmtemp = $snmpsession->get_request(-varbindlist => [$oidLowerSetTemperature]);
	my $highalarmtemp = $$reqhighalarmtemp{$oidHigherSetTemperature};
	my $lowalarmtemp = $$reqloweralarmtemp{$oidLowerSetTemperature};
	$o_critical = $highalarmtemp;
}
$o_warning = $o_critical - 10 if ( ! $o_warning && $o_critical );
if ($ambianttemp) {
	$value = $ambianttemp;
	$output = $output."Ambiant Temperature : ".$ambianttemp."°C,";
	define_exitcode_perf ();
	$perf=$perf."cpu_temp=".$ambianttemp.";".$o_warning.";".$o_critical."  ";
}
$snmpsession->close;
get_perf_data () if (defined $o_perf);
outputdisplay ();
