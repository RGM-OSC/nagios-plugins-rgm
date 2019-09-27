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

use vars qw(%reverse_exit_code %exit_code %fan_opercode %reverse_fan_opercode %ps_opercode %reverse_ps_opercode %isis_opercode);

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

%fan_opercode = (
	 1 => 'Unknown',
	 2 => 'Up',
	 3 => 'Down',
	 4 => 'NotPresent',
);

%reverse_fan_opercode = (
	 'Unknown' => 1,
	 'Up' => 2,
	 'Down'=> 3,
	 'NotPresent' => 4,
 );

%ps_opercode = (
	1 => 'unknown',
	2 => 'empty',
	3 => 'up',
	4 => 'down',
);

%reverse_ps_opercode = (
	'unknown' => 1,
	'empty' => 2,
	'up' => 3,
	'down' => 4,
);

%isis_opercode = (
	0 => 'unknown',
	1 => 'up',
	2 => 'down',
);

sub help {
	print "Check Avaya VSP, $Version\n";
	print "GPLv3 Licence, 2016 Vincent FRICOU\n";
	print "Help : check_avaya_vsp.pl
	-H, --hosttarget, Host Target
	-C, --community, Community
	-v, --version, SNMP Version (1 or 2)
	-t, --type, Check to perform:
		- fan : Check fan state (Need alert value),
		- power : Check power bloc state (Need alert value),
		- cpu : Check CPU usage (Need alert value),
		- memory : Check memory usage (Need alert value),
		- buffer : Check buffer and switch buffer usage (Need alert value),
		- vlan : Check current VLAN ID number,
		- mcastsession : Check current running multicast sessions,
		- iststate : Check current Virtual IST state,
		- temp : Check current temperature sensor value (Need alert value -- ONLY ON CPU TEMP),
		- isisstate : Check ISIS fabric state,
	-w, --warning, Warning value
	-c, --critical, Critical value
	-p, --perf, Display perf data
	-h, --help Display this help\n";
	exit 1;
}

my ($o_hostaddress,$o_community,$o_type,$o_warning,$o_critical,$o_help,$o_perf);

sub get_options() {
	Getopt::Long::Configure ("bundling");
	GetOptions (
		"H=s"  => \$o_hostaddress,  'hosttarget=s' => \$o_hostaddress,
		"C=s"  => \$o_community,    'community=s'  => \$o_community,
		"t=s"  => \$o_type,         'type=s'       => \$o_type,
		"w=i"  => \$o_warning,      'warning=i'    => \$o_warning,
		"c=i"  => \$o_critical,     'critical=i'   => \$o_critical,
		"v=i"  => \$o_snmpversion,  'version=i'    => \$o_snmpversion,
		"h"    => \$o_help,         'help'         => \$o_help,
		"p"    => \$o_perf,         'perf'         => \$o_perf,
	);

	help() if (defined ($o_help));
	help() if (! defined $o_hostaddress && ! defined $o_community && ! defined $o_type && ! defined $o_snmpversion);

	if (! $o_hostaddress) { print "Host target is not defined, Please use -H option.\n"; exit 3; }
	if (! $o_community) {print "Community is not defined. Please use -C option.\n"; exit 3; }
	if (! $o_snmpversion) {print "Version is not defined. Please use -v option.\n"; exit 3; }
	if (! $o_type) {print "Check to perform is not define. Please use -t option.\n"; exit 3;}
}

sub check_alert_value () {
	if (! defined $o_warning) { print "Warning value missing, please use -w option.\n"; exit 3; }
	if (! defined $o_critical) { print "Critical value missing, please use -c option.\n"; exit 3; }
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

switch ($o_type) {
	case fan {
		my $oidrcChasFanId = '.1.3.6.1.4.1.2272.1.4.7.1.1.1';
		my $oidrcChasFanOperStatus = ".1.3.6.1.4.1.2272.1.4.7.1.1.2";

		init_snmp_session ();
		check_alert_value ();
		my $resultfanid = $snmpsession->get_entries(-columns => [$oidrcChasFanId]);

		foreach my $fanid (keys %$resultfanid) {
			my $resultfanoperstate = $snmpsession->get_request(-varbindlist => [$oidrcChasFanOperStatus.'.'.$$resultfanid{$fanid}]);
			my $fanstate = $fan_opercode{$$resultfanoperstate{$oidrcChasFanOperStatus.'.'.$$resultfanid{$fanid}}};

			$countwarning++ if ($reverse_fan_opercode{$fanstate} == 1 || $reverse_fan_opercode{$fanstate} == 3 || $reverse_fan_opercode{$fanstate} == 4);
			$countcritical++ if ($reverse_fan_opercode{$fanstate} == 1 || $reverse_fan_opercode{$fanstate} ==3);
			$output=$output."Unknown - Fan ID : ".$$resultfanid{$fanid}." status ".$fanstate.","  if ($reverse_fan_opercode{$fanstate} == 1);
			$output=$output."Faulted - Fan ID : ".$$resultfanid{$fanid}." status ".$fanstate.","  if ($reverse_fan_opercode{$fanstate} == 3);
			$output=$output."Not Present - Fan ID : ".$$resultfanid{$fanid}." status ".$fanstate.","  if ($reverse_fan_opercode{$fanstate} == 4);
			$output=$output."Fan ID : ".$$resultfanid{$fanid}." status ".$fanstate."," if ($reverse_fan_opercode{$fanstate} != 1 && $reverse_fan_opercode{$fanstate} != 3 && $reverse_fan_opercode{$fanstate} != 4);
		}
		define_exitcode_count ();
	}
	case power {
		my $oidrcChasPowerSupplyId = '.1.3.6.1.4.1.2272.1.4.8.1.1.1';
		my $oidrcChasPowerSupplyOperStatus = '.1.3.6.1.4.1.2272.1.4.8.1.1.2';

		init_snmp_session ();
		check_alert_value ();
		my $resultpsid = $snmpsession->get_entries(-columns => [$oidrcChasPowerSupplyId]);

		foreach my $psid (keys %$resultpsid) {
			my $resultpsoperstatus = $snmpsession -> get_request(-varbindlist => [$oidrcChasPowerSupplyOperStatus.'.'.$$resultpsid{$psid}]);
			my $psstate = $ps_opercode{$$resultpsoperstatus{$oidrcChasPowerSupplyOperStatus.'.'.$$resultpsid{$psid}}};
			$countwarning++ if ($reverse_ps_opercode{$psstate} == 1 || $reverse_ps_opercode{$psstate} == 2 || $reverse_ps_opercode{$psstate} == 4);
			$countcritical++ if ($reverse_ps_opercode{$psstate} == 1 || $reverse_ps_opercode{$psstate} == 4);
			$output=$output."Unknown - Power Supply ID : ".$$resultpsid{$psid}." status ".$psstate."," if ($reverse_ps_opercode{$psstate} == 1);
			$output=$output."Not present - Power Supply ID : ".$$resultpsid{$psid}." status ".$psstate."," if ($reverse_ps_opercode{$psstate} == 2);
			$output=$output."Faulted - Power Supply ID : ".$$resultpsid{$psid}." status ".$psstate."," if ($reverse_ps_opercode{$psstate} == 4);
			$output=$output."Power Supply ID : ".$$resultpsid{$psid}." status ".$psstate.',' if ($reverse_ps_opercode{$psstate} != 1 && $reverse_ps_opercode{$psstate} != 2 && $reverse_ps_opercode{$psstate} != 4);
		}
		define_exitcode_count ();
	}
	case cpu {
		my $oidrcKhiSlotCpuCurrentUtil = '.1.3.6.1.4.1.2272.1.85.10.1.1.2';

		init_snmp_session ();
		check_alert_value ();
		my $cpuvalue = $snmpsession->get_next_request(-varbindlist => [$oidrcKhiSlotCpuCurrentUtil]);
		$value = $$cpuvalue{$oidrcKhiSlotCpuCurrentUtil.'.1'};
		$output="Cpu current usage : ".$value.'%';
		define_exitcode_perf ();
		$perf="|$o_type=".$value.';'.$o_warning.';'.$o_critical.',';
	}
	case memory {
		my $oidrcKhiSlotMemUtil = '.1.3.6.1.4.1.2272.1.85.10.1.1.2';

		init_snmp_session ();
		check_alert_value ();
		my $memvalue = $snmpsession->get_next_request(-varbindlist => [$oidrcKhiSlotMemUtil]);
		$value = $$memvalue{$oidrcKhiSlotMemUtil.'.1'};
		$output="Memory current usage : ".$value.'%';
		define_exitcode_perf ();
		$perf="|$o_type=".$value.';'.$o_warning.';'.$o_critical.',';
	}
	case buffer {
		$oidrcChasMgidUsageVlanCurrent = '.1.3.6.1.4.1.2272.1.1.13.0';

		init_snmp_session ();
		check_alert_value ();
		my $bufvalue = $snmpsession->get_request(-varbindlist => [$oidrcChasMgidUsageVlanCurrent]);
		$value = $$bufvalue{$oidrcChasMgidUsageVlanCurrent};
		$output="Buffer current usage : ".$value.'%';
		define_exitcode_perf ();
		$perf="|$o_type=".$value.';'.$o_warning.';'.$o_critical.',';
	}
	case vlan {
		my $oidrcChasMgidUsageVlanCurrent = '.1.3.6.1.4.1.2272.1.4.48.0';

		init_snmp_session ();
		my $mgidvlanused = $snmpsession->get_request(-varbindlist => [$oidrcChasMgidUsageVlanCurrent]);
		$vlanmgidused = $$mgidvlanused{$oidrcChasMgidUsageVlanCurrent};
		$output="VLAN mgID used including SMLT : ".$vlanmgidused.',';

	}
	case mcastsession {
		my $oidrcChasMgidUsageMulticastCurrent = '.1.3.6.1.4.1.2272.1.4.50.0';

		init_snmp_session ();
		my $mgidmcastsessused = $snmpsession->get_request(-varbindlist => [$oidrcChasMgidUsageMulticastCurrent]);
		$mcastsessmgidused = $$mgidmcastsessused{$oidrcChasMgidUsageMulticastCurrent};
		$output="Multicast session mgID used : ".$mcastsessmgidused.',';
		$perf="|$o_type=".$mcastsessmgidused.";;,";
	}
	case iststate {
		my $oidrcVirtualIstSessionStatus = '.1.3.6.1.4.1.2272.1.211.1.0';

		init_snmp_session ();
		my $reqvirtiststate = $snmpsession->get_request(-varbindlist => [$oidrcVirtualIstSessionStatus]);
		$virtiststate = $$reqvirtiststate{$oidrcVirtualIstSessionStatus};
		if ($virtiststate == 2) {
			$outcode=$exit_code{Critical};
			$output="Critical - Virtual IST functionnality is Down";
		} else {
			$outcode=$exit_code{Ok};
			$output="Virtual IST functionnality is Up";
		}
	}
	case temp {
		my $oidrcSingleCpSystemCpuTemperature = '.1.3.6.1.4.1.2272.1.212.1.0';
		my $oidrcSingleCpSystemMacTemperature = '.1.3.6.1.4.1.2272.1.212.2.0';
		my $oidrcSingleCpSystemPhy1Temperature = '.1.3.6.1.4.1.2272.1.212.3.0';
		my $oidrcSingleCpSystemPhy2Temperature = '.1.3.6.1.4.1.2272.1.212.4.0';
		my $oidrcSingleCpSystemMac2Temperature = '.1.3.6.1.4.1.2272.1.212.5.0';

		init_snmp_session ();
		check_alert_value ();
		my $reqcputemp = $snmpsession->get_request(-varbindlist => [$oidrcSingleCpSystemCpuTemperature]);
		my $cputemp = $$reqcputemp{$oidrcSingleCpSystemCpuTemperature};
		if ($cputemp != 0) {
			$value = $cputemp;
			$output = $output."CPU Temperature : ".$cputemp."°C,";
			define_exitcode_perf ();
			$perf=$perf."cpu_temp=".$cputemp.";".$o_warning.";".$o_critical."  ";
		}

		my $reqmactemp = $snmpsession->get_request(-varbindlist => [$oidrcSingleCpSystemMacTemperature]);
		my $mactemp = $$reqmactemp{$oidrcSingleCpSystemMacTemperature};
		if ($mactemp != 0) {
			$value = $mactemp;
			$output = $output."Mac Temperature : ".$mactemp."°C,";
			$perf=$perf."mac_temp=".$mactemp.";; ";
		}

		my $reqphy1temp = $snmpsession->get_request(-varbindlist => [$oidrcSingleCpSystemPhy1Temperature]);
		my $phy1temp = $$reqphy1temp{$oidrcSingleCpSystemPhy1Temperature};
		if ($phy1temp != 0) {
			$value = $phy1temp;
			$output = $output."Phy1 Temperature : ".$phy1temp."°C,";
			$perf=$perf."phy1_temp=".$phy1temp.";; ";
		}

		my $reqphy2temp = $snmpsession->get_request(-varbindlist => [$oidrcSingleCpSystemPhy2Temperature]);
		my $phy2temp = $$reqphy2temp{$oidrcSingleCpSystemPhy2Temperature};
		if ($phy2temp != 0) {
			$value = $phy2temp;
			$output = $output."Phy2 Temperature : ".$phy2temp."°C,";
			$perf=$perf."phy2_temp=".$phy2temp.";; ";
		}

		my $reqmac2temp = $snmpsession->get_request(-varbindlist =>[$oidrcSingleCpSystemMac2Temperature]);
		my $mac2temp = $$requestmac2tmp{$oidrcSingleCpSystemPhy2Temperature};
		if ($mac2temp != 0) {
			$value = $mac2temp;
			$output = $output."Mac2 Temperature : ".$mac2temp."°C,";
			$perf=$perf."mac2_temp=".$mac2temp.";; ";
		}
	}
	case isisstate {
		my $oidIsisCircuitOperState = '.1.3.6.1.4.1.2272.1.63.2.1.8';
		my $oidIsisAdjHostName = '.1.3.6.1.4.1.2272.1.63.10.1.3';
		my $oidIsisAdjIfIndex = '.1.3.6.1.4.1.2272.1.63.10.1.4';
		my $oidifNameInd = '.1.3.6.1.2.1.31.1.1.1.1';

		init_snmp_session ();
		check_alert_value ();
		my $reqisiscircuit = $snmpsession->get_entries(-columns => [$oidIsisCircuitOperState]);
		my $reqisisadjhost = $snmpsession->get_entries(-columns => [$oidIsisAdjHostName]);
		my $reqisisadjif = $snmpsession->get_entries(-columns => [$oidIsisAdjIfIndex]);
#		my $reqifname = $snmpsession->get_entries(-columns => [$oidifName]);
		foreach my $circuit (keys %$reqisiscircuit) {
			$circuitcount++;
		}
		while ($circuitcount > 0) {
			my $circuitstate = $$reqisiscircuit{$oidIsisCircuitOperState.'.'.$circuitcount};
			my $circuitinterfaceind = $$reqisisadjif{$oidIsisAdjIfIndex.'.'.$circuitcount.'.1'};
			my $oidifName = $oidifNameInd.'.'.$circuitinterfaceind;
			my $reqintname = $snmpsession->get_request(-varbindlist => [$oidifName]);
			my $ifname = $$reqintname{$oidifName};
			$ifname =~ tr/,/ /;
			$ifname = 'Index '.$circuitinterfaceind if ($ifname eq 'noSuchInstance');
			$ifname = 'Not defined' if (! defined $ifname);
			if (! $circuitstate) {
				$output=$output;
			} elsif ($circuitstate == 2) {
				$output=$output.'Faulted - Circuit (ID : '.$circuitcount.') '.$$reqisisadjhost{$oidIsisAdjHostName.'.'.$circuitcount.'.1'}.' state '.$isis_opercode{$circuitstate}.' - Int : '.$ifname.',';
				$countwarning++;
			} elsif ($circuitstate == 0) {
				$output=$output.'Unknown - Circuit (ID : '.$circuitcount.') '.$$reqisisadjhost{$oidIsisAdjHostName.'.'.$circuitcount.'.1'}.' state '.$isis_opercode{$circuitstate}.' - Int : '.$ifname.',';
				$countwarning++;
			} else {
				$output=$output.'Circuit (ID : '.$circuitcount.') '.$$reqisisadjhost{$oidIsisAdjHostName.'.'.$circuitcount.'.1'}.' state '.$isis_opercode{$circuitstate}.' - Int : '.$ifname.',';
			}
			$countcritical=$countwarning;
			$circuitcount--;
		}
		define_exitcode_count ();
	}
	else { help() }
}
$snmpsession->close;
get_perf_data () if (defined $o_perf);
outputdisplay ();
