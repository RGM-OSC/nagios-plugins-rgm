#!/usr/bin/perl -w 
######################### check_snmp_chkpfw.pl #################
my $Version='1.1.1';
# Date : Mar 25 2019
# Author  : Vincent FRICOU (vincent at fricouv dot eu)
# Check for Dell Compellent.
################################################################

use POSIX qw(locale_h);
use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;
use Number::Format qw(:subs);
use Date::Parse;
#use Data::Dumper;
use List::MoreUtils qw(uniq);

my %CMP_GEN_OID = (
	'Version'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.4.0",
	'GlobStat'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.6.0",
	'Model'				=> ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.7.1"
);

my %CMP_CTLR_OID = (
	'CtlrIdx'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.2",
	'CtlrStatus'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.3",
	'CtlrName'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.4",
	'CtlrIP'            => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.5",
	'CtlrServiceTag'    => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.8",
	'CtlrLead'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.13.1.12",
);

my %CMP_DISK_OID = (
	'DiskIdx'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.2",
	'DiskStatus'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.3",
	'DiskPosition'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.4",
	'DiskHealth'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.5",
	'DiskStatusMessage' => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.6",
	'DiskSize'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.9",
	'DiskType'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.14.1.10",

);

my %CMP_ENC_OID = (
	'EncIdx'            => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.2",
	'EncStatus'         => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.3",
	'EncName'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.4",
	'EncStatusDesc'     => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.5",
	'EncType'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.6",
	'EncServiceTag'     => ".1.3.6.1.4.1.674.11000.2000.500.1.2.15.1.9",
);

my %CMP_CTLR_TEMP_OID = (
	'TempIdx'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.2",
	'TempStatus'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.3",
	'TempName'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.4",
	'TempCurrent'       => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.5",
	'TempWarn'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.6",
	'TempCrit'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.19.1.9",
);

my %CMP_ENC_POWER_OID = (
	'PowerIdx'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.21.1.2",
	'PowerStatus'       => ".1.3.6.1.4.1.674.11000.2000.500.1.2.21.1.3",
	'PowerPosition'     => ".1.3.6.1.4.1.674.11000.2000.500.1.2.21.1.4",
);

my %CMP_ENC_TEMP_OID = (
	'TempIdx'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.23.1.2",
	'TempStatus'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.23.1.3",
	'TempLocation'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.23.1.4",
	'TempCurrentC'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.23.1.5",
);

my %CMP_DISK_FOLDER_OID = (
	'FolderIdx'         => ".1.3.6.1.4.1.674.11000.2000.500.1.2.25.1.2",
	'FolderStatus'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.25.1.3",
	'FolderName'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.25.1.4",
	'FolderCapa'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.25.1.9",
);

my %CMP_VOLUME_OID = (
	'VolIdx'            => ".1.3.6.1.4.1.674.11000.2000.500.1.2.26.1.2",
	'VolStatus'         => ".1.3.6.1.4.1.674.11000.2000.500.1.2.26.1.3",
	'VolName'           => ".1.3.6.1.4.1.674.11000.2000.500.1.2.26.1.4",
);
my %CMP_SERVER_OID = (
	'ServerIdx'         => ".1.3.6.1.4.1.674.11000.2000.500.1.2.27.1.2",
	'ServerStatus'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.27.1.3",
	'ServerName'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.27.1.4",
	'ServerConn'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.27.1.5",
	'ServerPath'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.27.1.6",
);

my %CMP_CACHE_OID = (
	'CacheIdx'          => ".1.3.6.1.4.1.674.11000.2000.500.1.2.28.1.2",
	'CacheStatus'       => ".1.3.6.1.4.1.674.11000.2000.500.1.2.28.1.3",
	'CacheName'         => ".1.3.6.1.4.1.674.11000.2000.500.1.2.28.1.4",
	'CacheBattStatus'   => ".1.3.6.1.4.1.674.11000.2000.500.1.2.28.1.5",
	'CacheExpDate'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.28.1.6",
);

my %CMP_CAPA_USAGE = (
	'StorageIdx'        => ".1.3.6.1.4.1.674.11000.2000.500.1.2.32.1.2",
	'StorageTotal'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.32.1.5",
	'StorageAlloc'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.32.1.7",
	'StorageSpare'      => ".1.3.6.1.4.1.674.11000.2000.500.1.2.32.1.9",
);

my ($o_host,$o_community,$o_port,$o_help,$o_timeout,$o_warn,$o_crit,$o_type,$o_perf);
my %reverse_exit_code = (
	'Ok'        =>  0,
	'Warning'   =>  1,
	'Critical'  =>  2,
	'Unknown'   =>  3,
);

my %glob_status_code = (
	1   =>  'other',
	2   =>  'unknown',
	3   =>  'ok',
	4   =>  'noncritical',
	5   =>  'critical',
	6   =>  'nonrecoverable',
);

my %rev_glob_status_code = (
	'other'             =>  1,
	'unknown'           =>  2,
	'ok'                =>  3,
	'noncritical'       =>  4,
	'critical'          =>  5,
	'nonrecoverable'    =>  6,
);

my %status_code = (
	1   =>  'up',
	2   =>  'down',
	3   =>  'degraded',
);

my %rev_status_code = (
	'up'        =>  1,
	'down'      =>  2,
	'degraded'  =>  3,
);

my %srv_conn_code = (
	1   =>  'up',
	2   =>  'down',
	3   =>  'partial',
);

my %rev_srv_conn_code = (
	'up'        =>  1,
	'down'      =>  2,
	'partial'  =>  3,
);

my %disk_health_state = (
	1   =>  'healthly',
	2   =>  'unhealth',
);

my %rev_disk_health_state = (
	'healthly'   =>  1,
	'unhealth'   =>  2,
);

my %ctlr_battery_status_code = (
	0   =>  'noBattery',
	1   =>  'normal',
	2   =>  'expirationPending',
	3   =>  'expired',
);

my %rev_ctlr_battery_status_code = (
	'noBattery'          => 0,
	'normal'             => 1,
	'expirationPending'  => 2,
	'expired'            => 3,
);

my %ctlr_lead_status = (
	1   =>  'master',
	2   =>  'slave',
);

my %disk_type = (
	1   =>  'fibrechannel',
	2   =>  'iscsi',
	3   =>  'fibrechanneloverethernet',
	4   =>  'sas',
	5   =>  'unknown',
);

my $output='';
my $perf='';
my $outputlines;
my $countcritical=0;
my $countwarning=0;
my $countunknown=0;
my ($snmpsession,$snmperror);

sub usage {
   print '\nSNMP Dell Compellent for Nagios. Version '.$Version.'\n';
   print 'GPL Licence - Vincent FRICOU\n\n';
   print <<EOT;
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-f, --perfparse
   perfparse output
-w, --warning=<value>
   Warning value
-c, --critical=<value>
   Critical value
-T, --type=CHECK TYPE
EOT
	type_help();
   exit $reverse_exit_code{Unknown};
}

sub type_help() {
	print <<EOT;
	global : Check global Compellent health status
	controller : Check each controller global status
	disk : Check unitary disk status
	enclosure : Check unitary enclosure status
	ctlr-temp : Check temperature status on controller (Used embedeed warning and critical values)
	enc-power : Check enclosure power supply
	enc-temp : Check temperature status on enclosure (Need to provide -w and -c)
	disk-folder : Check status and capacity of each storage folders
	volumes : Check status of each data volumes
	server : Check connectivity and path number for connected servers
	cache : Check cache batteries status. Return expiration date.
	capacity : Check storage allocated capacity. (Need to provide -w and -c values for space alert)
EOT
}

sub get_options () {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'h'     =>  \$o_help,       'help'          =>  \$o_help,
		'H:s'   =>  \$o_host,       'hostname:s'    =>  \$o_host,
		'C:s'   =>  \$o_community,  'community:s'   =>  \$o_community,
		'f'     =>  \$o_perf,       'perfparse'     =>  \$o_perf,
		'w:s'   =>  \$o_warn,       'warning:s'     =>  \$o_warn,
		'c:s'   =>  \$o_crit,       'critical:s'    =>  \$o_crit,
		'T:s'   =>  \$o_type,       'type:s'        =>  \$o_type,
	);

	usage() if (defined ($o_help));
	usage() if (! defined ($o_host) && ! defined ($o_community));
	type_help() if (! defined ($o_type));
	$o_type=uc($o_type);
}

sub output_display () {
	$output =~ tr/,/\n/;
	if ($countcritical > 0){
		if ( $outputlines > 1 ) {
			print 'Critical : Click for detail\n\n'.$output;
		} else {
			print 'Critical - '.$output;
		}
		exit $reverse_exit_code{Critical};
	} elsif ($countwarning > 0){
		if ( $outputlines > 1 ) {
			print 'Warning : Click for detail\n\n'.$output;
		} else {
			print 'Warning - '.$output;
		}
		exit $reverse_exit_code{Warning};
	} elsif ($countunknown > 0){
		if ( $outputlines > 1 ) {
			print 'Unknown : Click for detail\n\n'.$output;
	 	} else {
			print 'Unknown - '.$output;
		}
		exit $reverse_exit_code{Unknown};

	} else {
		print $output;
		exit $reverse_exit_code{Ok};
	}
}

sub get_perf_data () {
	$output=$output.'|'.$perf;
}

sub init_snmp_session () {
	my %snmpparms = (
		"-hostname"       =>    $o_host,
		"-version"        =>    2,
		"-community"      =>    $o_community,
	);
	($snmpsession,$snmperror) = Net::SNMP->session(%snmpparms);
	if (!defined $snmpsession) {
		printf "SNMP: %s\n", $snmperror;
		exit $reverse_exit_code{Unknown};
	}
}

sub check_alert_value () {
	if (! defined ($o_warn)) { print 'Warning value missing, please use -w option.\n'; exit $reverse_exit_code{Unknown}; }
	if (! defined ($o_crit)) { print 'Critical value missing, please use -c option.\n'; exit $reverse_exit_code{Unknown}; }
}

get_options();

switch ($o_type) {
	case 'GLOBAL' {
		init_snmp_session ();
		my $result;
		$result					= $snmpsession->get_request(-varbindlist => [$CMP_GEN_OID{'Model'}]);
		my $SANModel			= $$result{$CMP_GEN_OID{'Model'}};
		$result                 = $snmpsession->get_request(-varbindlist => [$CMP_GEN_OID{'Version'}]);
		my $SANVersion          = $$result{$CMP_GEN_OID{'Version'}};
		$result                 = $snmpsession->get_request(-varbindlist => [$CMP_GEN_OID{'GlobStat'}]);
		my $SANGlobalStatus     = $$result{$CMP_GEN_OID{'GlobStat'}};
		$output                 = $output.'Dell Compellent '.$SANModel.' (v'.$SANVersion.') is in state '.$glob_status_code{$SANGlobalStatus}.',';

		++$countunknown if ( $SANGlobalStatus == $rev_glob_status_code{'unknown'} );
		++$countwarning if ( $SANGlobalStatus == $rev_glob_status_code{'noncritical'} );
		++$countcritical if ( $SANGlobalStatus == $rev_glob_status_code{'critical'} || $SANGlobalStatus == $rev_glob_status_code{'nonrecoverable'} );
	}
	case 'CONTROLLER' {
		init_snmp_session ();
		my $CtlrIdx = $snmpsession->get_entries(-columns => [$CMP_CTLR_OID{'CtlrIdx'}]);
		foreach my $CtlrID (values %$CtlrIdx) {
			my $CtlrStatus  = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_OID{'CtlrStatus'}.'.'.$CtlrID]);
			my $CtlrName    = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_OID{'CtlrName'}.'.'.$CtlrID]);
			my $CtlrIP      = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_OID{'CtlrIP'}.'.'.$CtlrID]);
			my $CtlrSvcTag  = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_OID{'CtlrServiceTag'}.'.'.$CtlrID]);
			my $CtlrLead    = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_OID{'CtlrLead'}.'.'.$CtlrID]);

			++$countcritical if ( $$CtlrStatus{$CMP_CTLR_OID{'CtlrStatus'}.'.'.$CtlrID} == $rev_status_code{'down'} );
			++$countwarning if ( $$CtlrStatus{$CMP_CTLR_OID{'CtlrStatus'}.'.'.$CtlrID} == $rev_status_code{'degraded'} );

			$output = $output.'Controller '.$$CtlrName{$CMP_CTLR_OID{'CtlrName'}.'.'.$CtlrID}.' (ID : '.$CtlrID.' - ServiceTag : '.$$CtlrSvcTag{$CMP_CTLR_OID{'CtlrServiceTag'}.'.'.$CtlrID}.' - IP : '.$$CtlrIP{$CMP_CTLR_OID{'CtlrIP'}.'.'.$CtlrID}.') state '.$status_code{$$CtlrStatus{$CMP_CTLR_OID{'CtlrStatus'}.'.'.$CtlrID}}.' - Lead Status : '.$ctlr_lead_status{$$CtlrLead{$CMP_CTLR_OID{'CtlrLead'}.'.'.$CtlrID}}.',';
		}
	}
	case 'DISK' {
		init_snmp_session ();
		my $DiskIdx = $snmpsession->get_entries(-columns => [$CMP_DISK_OID{'DiskIdx'}]);
		foreach my $DiskID (values %$DiskIdx) {
			my $DiskStatus          = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskStatus'}.'.'.$DiskID]);
			my $DiskPosition        = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskPosition'}.'.'.$DiskID]);
			my $DiskHealth          = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskHealth'}.'.'.$DiskID]);
			my $DiskStatusMessage   = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskStatusMessage'}.'.'.$DiskID]);
			my $DiskSize            = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskSize'}.'.'.$DiskID]);
			my $DiskType            = $snmpsession->get_request(-varbindlist => [$CMP_DISK_OID{'DiskType'}.'.'.$DiskID]);

			if ( $$DiskStatus{$CMP_DISK_OID{'DiskStatus'}.'.'.$DiskID} == $rev_status_code{'down'} ) {
				++$countcritical;
				$output = $output.'Disk '.$$DiskPosition{$CMP_DISK_OID{'DiskPosition'}.'.'.$DiskID}.' ('.$disk_type{$$DiskType{$CMP_DISK_OID{'DiskType'}.'.'.$DiskID}}.' - '.$$DiskSize{$CMP_DISK_OID{'DiskSize'}.'.'.$DiskID}.'GB) was found in down state : '.$$DiskStatusMessage{$CMP_DISK_OID{'DiskStatusMessage'}.'.'.$DiskID}.",";
			} elsif  ( $$DiskStatus{$CMP_DISK_OID{'DiskStatus'}.'.'.$DiskID} == $rev_status_code{'degraded'} || $$DiskHealth{$CMP_DISK_OID{'DiskHealth'}.'.'.$DiskID} != $rev_disk_health_state{'healthly'} ) {
				++$countwarning;
				$output = $output.'Disk '.$$DiskPosition{$CMP_DISK_OID{'DiskPosition'}.'.'.$DiskID}.' ('.$disk_type{$$DiskType{$CMP_DISK_OID{'DiskType'}.'.'.$DiskID}}.' - '.$$DiskSize{$CMP_DISK_OID{'DiskSize'}.'.'.$DiskID}.'GB) was found in unhealthly state with message : '.$$DiskStatusMessage{$CMP_DISK_OID{'DiskStatusMessage'}.'.'.$DiskID}.",";
			}
		}
		$output = $output.'All disks heatlh check OK,' if ( $countcritical == 0 && $countwarning == 0 )
	}
	case 'ENCLOSURE' {
		init_snmp_session ();
		my $EncIdx = $snmpsession->get_entries(-columns => [$CMP_ENC_OID{'EncIdx'}]);
		foreach my $EncID (values %$EncIdx) {
			my $EncStatus          = $snmpsession->get_request(-varbindlist => [$CMP_ENC_OID{'EncStatus'}.'.'.$EncID]);
			my $EncName            = $snmpsession->get_request(-varbindlist => [$CMP_ENC_OID{'EncName'}.'.'.$EncID]);
			my $EncStatusDesc      = $snmpsession->get_request(-varbindlist => [$CMP_ENC_OID{'EncStatusDesc'}.'.'.$EncID]);
			my $EncType            = $snmpsession->get_request(-varbindlist => [$CMP_ENC_OID{'EncType'}.'.'.$EncID]);
			my $EncSvcTag          = $snmpsession->get_request(-varbindlist => [$CMP_ENC_OID{'EncServiceTag'}.'.'.$EncID]);

			if ($$EncStatus{$CMP_ENC_OID{'EncStatus'}.'.'.$EncID} == $rev_status_code{'down'} ) {
				++$countcritical;
				$output = $output.'Enclosure '.$$EncName{$CMP_ENC_OID{'EncName'}.'.'.$EncID}.' (Type : '.$$EncType{$CMP_ENC_OID{'EncType'}.'.'.$EncID}.' - ServiceTag : '.$$EncSvcTag{$CMP_ENC_OID{'EncServiceTag'}.'.'.$EncID}.') is in state '.$status_code{$$EncStatus{$CMP_ENC_OID{'EncStatus'}.'.'.$EncID}}.' with message '.$$EncStatusDesc{$CMP_ENC_OID{'EncStatusDesc'.'.'.$EncID}}.',';
			} elsif ($$EncStatus{$CMP_ENC_OID{'EncStatus'}.'.'.$EncID} == $rev_status_code{'down'} ) {
				++$countcritical;
				$output = $output.'Enclosure '.$$EncName{$CMP_ENC_OID{'EncName'}.'.'.$EncID}.' (Type : '.$$EncType{$CMP_ENC_OID{'EncType'}.'.'.$EncID}.' - ServiceTag : '.$$EncSvcTag{$CMP_ENC_OID{'EncServiceTag'}.'.'.$EncID}.') is in state '.$status_code{$$EncStatus{$CMP_ENC_OID{'EncStatus'}.'.'.$EncID}}.' with message '.$$EncStatusDesc{$CMP_ENC_OID{'EncStatusDesc'.'.'.$EncID}}.',';
			} else {
				$output = $output.'Enclosure '.$$EncName{$CMP_ENC_OID{'EncName'}.'.'.$EncID}.' (Type : '.$$EncType{$CMP_ENC_OID{'EncType'}.'.'.$EncID}.' - ServiceTag : '.$$EncSvcTag{$CMP_ENC_OID{'EncServiceTag'}.'.'.$EncID}.') is in state '.$status_code{$$EncStatus{$CMP_ENC_OID{'EncStatus'}.'.'.$EncID}}.',';
			}
		}
	}
	case 'CTLR-TEMP' {
		init_snmp_session ();
		my $CtlrIdx = $snmpsession->get_entries(-columns => [$CMP_CTLR_OID{'CtlrIdx'}]);
		my $TempIdx = $snmpsession->get_entries(-columns => [$CMP_CTLR_TEMP_OID{'TempIdx'}]);
		my @TempIdx;
		for my $TID (values %$TempIdx) {
			push @TempIdx, $TID;
		}
		my @UniqTempIdx = uniq @TempIdx;

		foreach my $CtlrID (values %$CtlrIdx) {
			foreach my $TempID (@UniqTempIdx) {
				my $CtlrTempStatus     = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_TEMP_OID{'TempStatus'}.'.'.$CtlrID.'.'.$TempID]);
				my $CtlrTempName       = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_TEMP_OID{'TempName'}.'.'.$CtlrID.'.'.$TempID]);
				my $CtlrTempCurrent    = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID]);
				my $CtlrTempWarn       = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_TEMP_OID{'TempWarn'}.'.'.$CtlrID.'.'.$TempID]);
				my $CtlrTempCrit       = $snmpsession->get_request(-varbindlist => [$CMP_CTLR_TEMP_OID{'TempCrit'}.'.'.$CtlrID.'.'.$TempID]);
				
				if ($CtlrTempCurrent) {
					if ($$CtlrTempStatus{$CMP_CTLR_TEMP_OID{'TempStatus'}.'.'.$CtlrID.'.'.$TempID} == $rev_status_code{'down'} || $$CtlrTempCurrent{$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID} >= $$CtlrTempCrit{$CMP_CTLR_TEMP_OID{'TempCrit'}.'.'.$CtlrID.'.'.$TempID} ) {
						++$countcritical;
						$output = $output.'Temp on Controller '.$CtlrID.' '.$$CtlrTempName{$CMP_CTLR_TEMP_OID{'TempName'}.'.'.$CtlrID.'.'.$TempID}.' is in state '.$$CtlrTempStatus{$CMP_CTLR_TEMP_OID{'TempStatus'}.'.'.$CtlrID.'.'.$TempID}.' - Current '.$$CtlrTempCurrent{$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID}.'°C (>'.$$CtlrTempCrit{$CMP_CTLR_TEMP_OID{'TempCrit'}.'.'.$CtlrID.'.'.$TempID}.'°C),';
					} elsif ($$CtlrTempStatus{$CMP_CTLR_TEMP_OID{'TempStatus'}.'.'.$CtlrID.'.'.$TempID} == $rev_status_code{'degraded'} || $$CtlrTempCurrent{$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID} >= $$CtlrTempWarn{$CMP_CTLR_TEMP_OID{'TempWarn'}.'.'.$CtlrID.'.'.$TempID} ) {
						++$countwarning;
						$output = $output.'Temp on Controller '.$CtlrID.' '.$$CtlrTempName{$CMP_CTLR_TEMP_OID{'TempName'}.'.'.$CtlrID.'.'.$TempID}.' is in state '.$$CtlrTempStatus{$CMP_CTLR_TEMP_OID{'TempStatus'}.'.'.$CtlrID.'.'.$TempID}.' - Current '.$$CtlrTempCurrent{$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID}.'°C (>'.$$CtlrTempWarn{$CMP_CTLR_TEMP_OID{'TempWarn'}.'.'.$CtlrID.'.'.$TempID}.'°C),';
					}
					$perf = $perf.'Ctlr-'.$CtlrID.'-'.$$CtlrTempName{$CMP_CTLR_TEMP_OID{'TempName'}.'.'.$CtlrID.'.'.$TempID}.'='.$$CtlrTempCurrent{$CMP_CTLR_TEMP_OID{'TempCurrent'}.'.'.$CtlrID.'.'.$TempID}.';'.$$CtlrTempWarn{$CMP_CTLR_TEMP_OID{'TempWarn'}.'.'.$CtlrID.'.'.$TempID}.';'.$$CtlrTempCrit{$CMP_CTLR_TEMP_OID{'TempCrit'}.'.'.$CtlrID.'.'.$TempID}.',';
				}
			}
		}
		$output = $output.'All Temperature sensors are OK,' if ($countcritical == 0 || $countwarning == 0);
	}
	case 'ENC-POWER' {
		init_snmp_session ();
		my $PowerIdx = $snmpsession->get_entries(-columns => [$CMP_ENC_POWER_OID{'PowerIdx'}]);
		my $EncIdx = $snmpsession -> get_entries(-columns => [$CMP_ENC_OID{'EncIdx'}]);
		foreach my $PowerID (values %$PowerIdx) {
			foreach my $EncID (values %$EncIdx) {
				my $PowerStatus        = $snmpsession->get_request(-varbindlist => [$CMP_ENC_POWER_OID{'PowerStatus'}.'.'.$EncID.'.'.$PowerID]);
				my $PowerPosition      = $snmpsession->get_request(-varbindlist => [$CMP_ENC_POWER_OID{'PowerPosition'}.'.'.$EncID.'.'.$PowerID]);
				if ($$PowerStatus{$CMP_ENC_POWER_OID{'PowerStatus'}.'.'.$EncID.'.'.$PowerID} == $rev_status_code{'down'}) {
					++$countcritical;
				} elsif ($$PowerStatus{$CMP_ENC_POWER_OID{'PowerStatus'}.'.'.$EncID.'.'.$PowerID} == $rev_status_code{'degraded'}) {
					++$countwarning;
				}
				$output = $output.'Power supply '.$$PowerPosition{$CMP_ENC_POWER_OID{'PowerPosition'}.'.'.$EncID.'.'.$PowerID}.' ('.$PowerID.') on enclosure '.$EncID.' is in state '.$status_code{$$PowerStatus{$CMP_ENC_POWER_OID{'PowerStatus'}.'.'.$EncID.'.'.$PowerID}}.',' if ($countcritical != 0 || $countwarning != 0);
			}
		}
		$output = $output.'All PSU are OK,' if ($countcritical == 0 || $countwarning == 0);
	}
	case 'ENC-TEMP' {
		init_snmp_session ();
		my $TempIdx     = $snmpsession->get_entries(-columns => [$CMP_ENC_TEMP_OID{'TempIdx'}]);
		my $EncIdx      = $snmpsession->get_entries(-columns => [$CMP_ENC_OID{'EncIdx'}]);
		foreach my $TempID (values %$TempIdx) {
			foreach my $EncID (values %$EncIdx) {
				my $TempStatus       = $snmpsession->get_request(-varbindlist => [$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID]);
				my $TempLocation     = $snmpsession->get_request(-varbindlist => [$CMP_ENC_TEMP_OID{'TempLocation'}.'.'.$EncID.'.'.$TempID]);
				my $TempCurrentC     = $snmpsession->get_request(-varbindlist => [$CMP_ENC_TEMP_OID{'TempCurrentC'}.'.'.$EncID.'.'.$TempID]);
				if ($$TempStatus{$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID} == $rev_status_code{'down'}) {
					++$countcritical;
					$output = $output.'Temp sensor '.$$TempLocation{$CMP_ENC_TEMP_OID{'TempLocation'}.'.'.$EncID.'.'.$TempID}.' ('.$TempID.') on enclosure '.$EncID.' is in state '.$status_code{$$TempStatus{$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID}}.' with value '.$$TempCurrentC{$CMP_ENC_TEMP_OID{'TempCurrentC'}.'.'.$EncID.'.'.$TempID}.'°C,';
				} elsif ($$TempStatus{$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID} == $rev_status_code{'degraded'}) {
					++$countwarning;
					$output = $output.'Temp sensor '.$$TempLocation{$CMP_ENC_TEMP_OID{'TempLocation'}.'.'.$EncID.'.'.$TempID}.' ('.$TempID.') on enclosure '.$EncID.' is in state '.$status_code{$$TempStatus{$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID}}.' with value '.$$TempCurrentC{$CMP_ENC_TEMP_OID{'TempCurrentC'}.'.'.$EncID.'.'.$TempID}.'°C,';
				} else {
					$output = $output.'Temp sensor '.$$TempLocation{$CMP_ENC_TEMP_OID{'TempLocation'}.'.'.$EncID.'.'.$TempID}.' ('.$TempID.') on enclosure '.$EncID.' is in state '.$status_code{$$TempStatus{$CMP_ENC_TEMP_OID{'TempStatus'}.'.'.$EncID.'.'.$TempID}}.' with value '.$$TempCurrentC{$CMP_ENC_TEMP_OID{'TempCurrentC'}.'.'.$EncID.'.'.$TempID}.'°C,';
				}
				my $TempSensName = $$TempLocation{$CMP_ENC_TEMP_OID{'TempLocation'}.'.'.$EncID.'.'.$TempID} =~ s/\s/_/r ;
				$perf = $perf.'Enc-'.$EncID.'-'.$TempSensName.'='.$$TempCurrentC{$CMP_ENC_TEMP_OID{'TempCurrentC'}.'.'.$EncID.'.'.$TempID}.';;,';
			}
		}
	}
	case 'DISK-FOLDER' {
		init_snmp_session ();
		my $FolderIdx = $snmpsession->get_entries(-columns => [$CMP_DISK_FOLDER_OID{'FolderIdx'}]);
		foreach my $FolderID (values %$FolderIdx) {
			my $FolderStatus     = $snmpsession->get_request(-varbindlist => [$CMP_DISK_FOLDER_OID{'FolderStatus'}.'.'.$FolderID]);
			my $FolderName       = $snmpsession->get_request(-varbindlist => [$CMP_DISK_FOLDER_OID{'FolderName'}.'.'.$FolderID]);
			my $FolderCapaG      = $snmpsession->get_request(-varbindlist => [$CMP_DISK_FOLDER_OID{'FolderCapa'}.'.'.$FolderID]);
			my $FolderCapaT      = $$FolderCapaG{$CMP_DISK_FOLDER_OID{'FolderCapa'}.'.'.$FolderID} / 1024;
			if ($$FolderStatus{$CMP_DISK_FOLDER_OID{'FolderStatus'}.'.'.$FolderID} == $rev_status_code{'down'}) {
				++$countcritical;
			} elsif ($$FolderStatus{$CMP_DISK_FOLDER_OID{'FolderStatus'}.'.'.$FolderID} == $rev_status_code{'degraded'}) {
				++$countwarning;
			}
			$output = $output.'Folder '.$$FolderName{$CMP_DISK_FOLDER_OID{'FolderName'}.'.'.$FolderID}.' capacity '.$FolderCapaT.'TB is in state '.$status_code{$$FolderStatus{$CMP_DISK_FOLDER_OID{'FolderStatus'}.'.'.$FolderID}}.',';
		}
	}
	case 'VOLUMES' {
		init_snmp_session ();
		my $locCrit		= 0;
		my $locWarn		= 0;
		my $VolIdx      = $snmpsession->get_entries(-columns => [$CMP_VOLUME_OID{'VolIdx'}]);
		foreach my $VolID (values %$VolIdx) {
			my $VolStatus   = $snmpsession->get_request(-varbindlist => [$CMP_VOLUME_OID{'VolStatus'}.'.'.$VolID]);
			my $VolName     = $snmpsession->get_request(-varbindlist => [$CMP_VOLUME_OID{'VolName'}.'.'.$VolID]);
			if ($$VolStatus{$CMP_VOLUME_OID{'VolStatus'}.'.'.$VolID} == $rev_status_code{'down'}) {
				++$locCrit;
				++$countcritical;
			} elsif ($$VolStatus{$CMP_VOLUME_OID{'VolStatus'}.'.'.$VolID} == $rev_status_code{'degraded'}) {
				++$locWarn;
				++$countwarning;
			}
			$output = $output.'Volume '.$$VolName{$CMP_VOLUME_OID{'VolName'}.'.'.$VolID}.' (ID : '.$VolID.') is in state '.$status_code{$$VolStatus{$CMP_VOLUME_OID{'VolStatus'}.'.'.$VolID}}.',' if ($locCrit > 0 || $locWarn > 0);
			$locCrit = 0;
			$locWarn = 0;
		}
		$output = 'All volumes are OK,' if ($countwarning == 0 && $countcritical == 0);
	}
	case 'SERVER' {
		init_snmp_session ();
		my $ServerIdx      = $snmpsession->get_entries(-columns => [$CMP_SERVER_OID{'ServerIdx'}]);
		foreach my $ServerID (values %$ServerIdx) {
			my $ServerStatus   = $snmpsession->get_request(-varbindlist => [$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID]);
			my $ServerName     = $snmpsession->get_request(-varbindlist => [$CMP_SERVER_OID{'ServerName'}.'.'.$ServerID]);
			my $ServerConn     = $snmpsession->get_request(-varbindlist => [$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID]);
			my $ServerPath     = $snmpsession->get_request(-varbindlist => [$CMP_SERVER_OID{'ServerPath'}.'.'.$ServerID]);
			my $SrvCluster     = 0;
			++$SrvCluster if ($$ServerStatus{$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID} == $rev_status_code{'up'} && $$ServerConn{$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID} == 0);
			if ($$ServerStatus{$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID} == $rev_status_code{'down'} || $$ServerConn{$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID} == $rev_srv_conn_code{'down'}) {
				++$countcritical;
			} elsif ($$ServerStatus{$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID} == $rev_status_code{'degraded'} || $$ServerConn{$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID} == $rev_srv_conn_code{'partial'}) {
				++$countwarning;
			}
			$output = $output.'Server '.$$ServerName{$CMP_SERVER_OID{'ServerName'}.'.'.$ServerID}.' is in state '.$status_code{$$ServerStatus{$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID}}.'. Connection state '.$srv_conn_code{$$ServerConn{$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID}}.' with '.$$ServerPath{$CMP_SERVER_OID{'ServerPath'}.'.'.$ServerID}.' active path.,' if ($SrvCluster == 0);
			$output = $output.'Cluster '.$$ServerName{$CMP_SERVER_OID{'ServerName'}.'.'.$ServerID}.' is in state '.$status_code{$$ServerStatus{$CMP_SERVER_OID{'ServerStatus'}.'.'.$ServerID}}.'. Connection state '.$srv_conn_code{$$ServerConn{$CMP_SERVER_OID{'ServerConn'}.'.'.$ServerID}}.',' if ($SrvCluster > 0);
		}
	}
	case 'CACHE' {
		init_snmp_session ();
		my $CacheIdx            = $snmpsession->get_entries(-columns => [$CMP_CACHE_OID{'CacheIdx'}]);
		foreach my $CacheID (values %$CacheIdx) {
			my $CacheStatus     = $snmpsession->get_request(-varbindlist => [$CMP_CACHE_OID{'CacheStatus'}.'.'.$CacheID]);
			my $CacheName       = $snmpsession->get_request(-varbindlist => [$CMP_CACHE_OID{'CacheName'}.'.'.$CacheID]);
			my $CacheBattStatus = $snmpsession->get_request(-varbindlist => [$CMP_CACHE_OID{'CacheBattStatus'}.'.'.$CacheID]);
			my $CacheExpDate    = $snmpsession->get_request(-varbindlist => [$CMP_CACHE_OID{'CacheExpDate'}.'.'.$CacheID]);
			if ($$CacheStatus{$CMP_CACHE_OID{'CacheStatus'}.'.'.$CacheID} == $rev_status_code{'down'} || $$CacheBattStatus{$CMP_CACHE_OID{'CacheBattStatus'}.'.'.$CacheID} == $rev_ctlr_battery_status_code{'expired'} || $$CacheBattStatus{$CMP_CACHE_OID{'CacheBattStatus'}.'.'.$CacheID} == $rev_ctlr_battery_status_code{'noBattery'}) {
				++$countcritical;
				$output = $output.'Critical ';
			} elsif ($$CacheStatus{$CMP_CACHE_OID{'CacheStatus'}.'.'.$CacheID} == $rev_status_code{'down'} || $$CacheBattStatus{$CMP_CACHE_OID{'CacheBattStatus'}.'.'.$CacheID} == $rev_ctlr_battery_status_code{'expirationPending'}) {
				++$countwarning;
				$output = $output.'Warning ';
			} 
			$output = $output.'Battery cache '.$$CacheName{$CMP_CACHE_OID{'CacheName'}.'.'.$CacheID}.' is in state '.$status_code{$$CacheStatus{$CMP_CACHE_OID{'CacheStatus'}.'.'.$CacheID}}.'. Expiration date : '.$$CacheExpDate{$CMP_CACHE_OID{'CacheExpDate'}.'.'.$CacheID}.',';
		}
	}
	case 'CAPACITY' {
		check_alert_value ();
		init_snmp_session ();
		my $StorageIdx = $snmpsession->get_entries(-columns => [$CMP_CAPA_USAGE{'StorageIdx'}]);
		foreach my $StorageID (values %$StorageIdx) {
			my $StorageTotalGB      = $snmpsession->get_request(-varbindlist => [$CMP_CAPA_USAGE{'StorageTotal'}.'.'.$StorageID]);
			my $StorageTotalTB      = $$StorageTotalGB{$CMP_CAPA_USAGE{'StorageTotal'}.'.'.$StorageID} / 1024;
			my $StorageAllocGB      = $snmpsession->get_request(-varbindlist => [$CMP_CAPA_USAGE{'StorageAlloc'}.'.'.$StorageID]);
			my $StorageAllocTB      = $$StorageAllocGB{$CMP_CAPA_USAGE{'StorageAlloc'}.'.'.$StorageID} / 1024;
			my $StorageSpareGB      = $snmpsession->get_request(-varbindlist => [$CMP_CAPA_USAGE{'StorageSpare'}.'.'.$StorageID]);
			my $StorageSpareTB      = $$StorageSpareGB{$CMP_CAPA_USAGE{'StorageSpare'}.'.'.$StorageID} / 1024;
			if ($StorageTotalTB > 0) {
				my $PCTAllocTB          = $StorageAllocTB / $StorageTotalTB * 100;

				if ($StorageSpareTB == 0) {
					++$countwarning;
					$output = $output.'No spare space left '.$StorageID.'. ';
				}
				if ($PCTAllocTB >= $o_crit) {
					++$countcritical;
					$output = $output.'Allocated space '.$PCTAllocTB.'% ('.$StorageAllocTB.'TB) (> '.$o_crit.'%). ';
				} elsif ($PCTAllocTB >= $o_warn) {
					++$countwarning;
					$output = $output.'Allocated space '.$PCTAllocTB.'% ('.$StorageAllocTB.'TB) (> '.$o_warn.'%). ';
				} else {
					$output = $output.'Allocated space '.$PCTAllocTB.'% ('.$StorageAllocTB.'TB). ';
				}
				$output = $output.',';
				$perf = $perf.'Storage-Alloc-'.$StorageID.'='.$PCTAllocTB.';'.$o_warn.';'.$o_crit.',';
			}
		}
	} else { $output = 'Type not recognized.'; }
}
$snmpsession->close;
$output =~ tr/,/\n/;
$perf =~ tr/' '/'_'/;
$outputlines = $output =~ tr/\n//;
get_perf_data() if (defined $o_perf && $o_perf ne '');
output_display();
