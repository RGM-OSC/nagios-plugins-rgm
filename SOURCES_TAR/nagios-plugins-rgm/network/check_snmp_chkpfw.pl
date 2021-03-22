#!/usr/bin/perl -w 
######################### check_snmp_chkpfw.pl #################
my $Version='1.2';
# Date : Jun 21 2017
# Author  : Vincent FRICOU (vincent at fricouv dot eu)
# Check for checkpoint Gateway and SMS.
# Designed for R80.10, tested and fully functionnal from R77.30.
################################################################

use POSIX qw(locale_h);
use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;
use Number::Format qw(:subs);
use Date::Parse;
use Data::Dumper;

my %FWOID = (
	'FWPolicyInstallState'	=> "1.3.6.1.4.1.2620.1.1.1.0",
	'FWPolicyInstalledName'	=> "1.3.6.1.4.1.2620.1.1.2.0",
	'FWInstantConnections'	=> "1.3.6.1.4.1.2620.1.1.25.3.0",
	'FWAcceptedPackets'		=> "1.3.6.1.4.1.2620.1.1.25.6.0",
	'FWAcceptedBytes'		=> "1.3.6.1.4.1.2620.1.1.25.8.0",
	'FWRejectedPackets'		=> "1.3.6.1.4.1.2620.1.1.25.14.0",
	'FWRejectedBytes'		=> "1.3.6.1.4.1.2620.1.1.25.15.0",
	'FWDroppedPackets'		=> "1.3.6.1.4.1.2620.1.1.25.16.0",
	'FWDroppedBytes'		=> "1.3.6.1.4.1.2620.1.1.25.9.0",
	'FWLoggedPackets'		=> "1.3.6.1.4.1.2620.1.1.25.13.0",
	'FWIfTableIndex'		=> "1.3.6.1.4.1.2620.1.1.25.25.1.1",
	'FWIfTableName'			=> "1.3.6.1.4.1.2620.1.1.25.25.1.2",
	'FWIfStatAccptPktsIn'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.5",
	'FWIfStatAccptPktsOut'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.6",
	'FWIfStatAccptBytesIn'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.7",
	'FWIfStatAccptBytesOut'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.8",
	'FWIfStatDropPktsIn'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.9",
	'FWIfStatDropPktsOut'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.10",
	'FWIfStatRjctPktsIn'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.11",
	'FWIfStatRjctPktsOut'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.12",
	'FWIfStatLogPktsIn'		=> "1.3.6.1.4.1.2620.1.1.25.25.1.13",
	'FWIfStatLogPktsOut'	=> "1.3.6.1.4.1.2620.1.1.25.25.1.14",
	'FWLogServConn'			=> "1.3.6.1.4.1.2620.1.1.30.1.0",
	'FWLogServer'			=> "1.3.6.1.4.1.2620.1.1.30.3.1.2.1.0",
	'FWLoggingStat'			=> "1.3.6.1.4.1.2620.1.1.30.5.0",
);
my %HAOID = (
	'HAStarted'				=> '.1.3.6.1.4.1.2620.1.5.5.0',
	'HAState'				=> '.1.3.6.1.4.1.2620.1.5.6.0',
	'HABlockState'			=> '.1.3.6.1.4.1.2620.1.5.7.0',
	'HAIdentifier'			=> '.1.3.6.1.4.1.2620.1.5.8.0',
	'HAProblemIDTable'		=> '.1.3.6.1.4.1.2620.1.5.13.1.1',
	'HAProblemNameTable'	=> '.1.3.6.1.4.1.2620.1.5.13.1.2',
	'HAProblemStateTable'	=> '.1.3.6.1.4.1.2620.1.5.13.1.3',
);
my %SVNOID = (
	'SVNTempSensorsID'		=> '.1.3.6.1.4.1.2620.1.6.7.8.1.1.1',
	'SVNTempSensorsName'	=> '.1.3.6.1.4.1.2620.1.6.7.8.1.1.2',
	'SVNTempSensorsValue'	=> '.1.3.6.1.4.1.2620.1.6.7.8.1.1.3',
	'SVNTempSensorsUnit'	=> '.1.3.6.1.4.1.2620.1.6.7.8.1.1.4',
	'SVNTempSensorsStatus'	=> '.1.3.6.1.4.1.2620.1.6.7.8.1.1.6',
	'SVNFanSpeedsID'		=> '.1.3.6.1.4.1.2620.1.6.7.8.2.1.1',
	'SVNFanSpeedsName'		=> '.1.3.6.1.4.1.2620.1.6.7.8.2.1.2',
	'SVNFanSpeedsValue'		=> '.1.3.6.1.4.1.2620.1.6.7.8.2.1.3',
	'SVNFanSpeedsUnit'		=> '.1.3.6.1.4.1.2620.1.6.7.8.2.1.4',
	'SVNFanSpeedsStatus'	=> '.1.3.6.1.4.1.2620.1.6.7.8.2.1.6',
	'SVNPSUID'				=> '.1.3.6.1.4.1.2620.1.6.7.9.1.1.1',
	'SVNPSUStatus'			=> '.1.3.6.1.4.1.2620.1.6.7.9.1.1.2',
	'SVNStatus'				=> '.1.3.6.1.4.1.2620.1.6.101.0',
);
my %MGMTOID = (
	'MGMTActiveStatus'			=> '.1.3.6.1.4.1.2620.1.7.5.0',
	'MGMTAlive'					=> '.1.3.6.1.4.1.2620.1.7.6.0',
	'MGMTLicenceViolation'		=> '.1.3.6.1.4.1.2620.1.7.10.0',
	'MGMTLicenceViolationMsg'	=> '.1.3.6.1.4.1.2620.1.7.11.0',
	'MGMTStatus'				=> '.1.3.6.1.4.1.2620.1.7.101.0',
);
my %AVIROID = (
	'AVIStatus'				=> '.1.3.6.1.4.1.2620.1.24.101.0',
	'AVISubsStatus'			=> '.1.3.6.1.4.1.2620.1.46.3.1.0',
	'AVISubsExpDate'		=> '.1.3.6.1.4.1.2620.1.46.3.2.0',
	'AVISubsDesc'			=> '.1.3.6.1.4.1.2620.1.46.3.3.0',
	'AVIUpdateStatus'		=> '.1.3.6.1.4.1.2620.1.46.5.1.0',
	'AVIUpdateDesc'			=> '.1.3.6.1.4.1.2620.1.46.5.2.0',
);
my %MSOID =(
	'MSScannedMail'			=> '.1.3.6.1.4.1.2620.1.30.6.1.0',
	'MSSpamMail'			=> '.1.3.6.1.4.1.2620.1.30.6.2.0',
	'MSSpamHandled'			=> '.1.3.6.1.4.1.2620.1.30.6.3.0',
	'MSControlSpamEngine'	=> '.1.3.6.1.4.1.2620.1.30.6.4.1.0',
	'MSControlIPRep'		=> '.1.3.6.1.4.1.2620.1.30.6.4.2.0',
	'MSControlSPF'			=> '.1.3.6.1.4.1.2620.1.30.6.4.3.0',
	'MSControlDomainKeys'	=> '.1.3.6.1.4.1.2620.1.30.6.4.4.0',
	'MSControlRDNS'			=> '.1.3.6.1.4.1.2620.1.30.6.4.5.0',
	'MSControlRBL'			=> '.1.3.6.1.4.1.2620.1.30.6.4.6.0',
	'MSStatusState'			=> '.1.3.6.1.4.1.2620.1.30.101.0',
	'MSStatusMsg'			=> '.1.3.6.1.4.1.2620.1.30.102.0',
	'MSStatusLongMsg'		=> '.1.3.6.1.4.1.2620.1.30.103.0',
	'MSSubsStatus'			=> '.1.3.6.1.4.1.2620.1.46.4.1.0',
	'MSSubsExpDate'			=> '.1.3.6.1.4.1.2620.1.46.4.2.0',
	'MSSubsDesc'			=> '.1.3.6.1.4.1.2620.1.46.4.3.0',
);
my %IAOID = (
	'IAAuthUsr'					=>	'.1.3.6.1.4.1.2620.1.38.2.0',
	'IAUnAuthUsr'				=>	'.1.3.6.1.4.1.2620.1.38.3.0',
	'IAAuthUsrKrb'				=>	'.1.3.6.1.4.1.2620.1.38.4.0',
	'IAAuthHstKrb'				=>	'.1.3.6.1.4.1.2620.1.38.5.0',
	'IAAuthUsrPass'				=>	'.1.3.6.1.4.1.2620.1.38.6.0',
	'IAAuthUsrAD'				=>	'.1.3.6.1.4.1.2620.1.38.7.0',
	'IAAuthHstAD'				=>	'.1.3.6.1.4.1.2620.1.38.8.0',
	'IAAuthInAgt'				=>	'.1.3.6.1.4.1.2620.1.38.9.0',
	'IAAuthInPortal'			=>	'.1.3.6.1.4.1.2620.1.38.10.0',
	'IAAuthInAD'				=>	'.1.3.6.1.4.1.2620.1.38.11.0',
	'IAADQueryStatusTableID'	=>	'.1.3.6.1.4.1.2620.1.38.25.1.1',
	'IAADQueryStatusCurr'		=>	'.1.3.6.1.4.1.2620.1.38.25.1.2',
	'IAADQueryStatusDomainName'	=>	'.1.3.6.1.4.1.2620.1.38.25.1.3',
	'IAADQueryStatusDomainIP'	=>	'.1.3.6.1.4.1.2620.1.38.25.1.4',
	'IAStatus'					=>	'.1.3.6.1.4.1.2620.1.38.101.0',
	'IAStatusMsg'				=>	'.1.3.6.1.4.1.2620.1.38.103.0',
);
my %APPCTRLOID = (
	'ACStatusCode'				=> '.1.3.6.1.4.1.2620.1.39.101.0',
	'ACStatusMsg'				=> '.1.3.6.1.4.1.2620.1.39.102.0',
	'ACStatusLongMsg'			=> '.1.3.6.1.4.1.2620.1.39.103.0',
	'ACSubsStatus'				=> '.1.3.6.1.4.1.2620.1.39.1.1.0',
	'ACSubsExpDate'				=> '.1.3.6.1.4.1.2620.1.39.1.2.0',
	'ACSubsDesc'				=> '.1.3.6.1.4.1.2620.1.39.1.3.0',
	'ACUpdateStatus'			=> '.1.3.6.1.4.1.2620.1.39.2.1.0',
	'ACUpdateDesc'				=> '.1.3.6.1.4.1.2620.1.39.2.2.0',
);
my %ADVFOID = (
	'ADVFStatusCode'			=> '.1.3.6.1.4.1.2620.1.43.101.0',
	'ADVFStatusMsg'				=> '.1.3.6.1.4.1.2620.1.43.102.0',
	'ADVFStatusLongMsg'			=> '.1.3.6.1.4.1.2620.1.43.103.0',
	'ADVFSubsStatus'			=> '.1.3.6.1.4.1.2620.1.43.1.1.0',
	'ADVFSubsExpDate'			=> '.1.3.6.1.4.1.2620.1.43.1.2.0',
	'ADVFSubsDesc'				=> '.1.3.6.1.4.1.2620.1.43.1.3.0',
	'ADVFUpdateStatus'			=> '.1.3.6.1.4.1.2620.1.43.2.1.0',
	'ADVFUpdateDesc'			=> '.1.3.6.1.4.1.2620.1.43.2.2.0',
	'ADVFRADStatus'				=> '.1.3.6.1.4.1.2620.1.43.3.1.0',
	'ADVFRADDesc'				=> '.1.3.6.1.4.1.2620.1.43.3.2.0',
);
my %ABOID = (
	'ABUpdateStatus'			=> '.1.3.6.1.4.1.2620.1.46.1.1.0',
	'ABUpdateDesc'				=> '.1.3.6.1.4.1.2620.1.46.1.2.0',
	'ABSubsStatus'				=> '.1.3.6.1.4.1.2620.1.46.2.1.0',
	'ABSubsExpDate'				=> '.1.3.6.1.4.1.2620.1.46.2.2.0',
	'ABSubsDesc'				=> '.1.3.6.1.4.1.2620.1.46.2.3.0',
	'ABStatusCode'				=> '.1.3.6.1.4.1.2620.1.46.101.0',
	'ABStatusMsg'				=> '.1.3.6.1.4.1.2620.1.46.102.0',
	'ABStatusLongMsg'			=> '.1.3.6.1.4.1.2620.1.46.103.0',
);
my %TUNOID = (
	'TUNTable'					=> '.1.3.6.1.4.1.2620.500.9003.1.1',
	'TUNName'					=> '.1.3.6.1.4.1.2620.500.9003.1.2',
	'TUNState'					=> '.1.3.6.1.4.1.2620.500.9003.1.3',
	'TUNCommunity'				=> '.1.3.6.1.4.1.2620.500.9003.1.4',
	'TUNIFace'					=> '.1.3.6.1.4.1.2620.500.9003.1.6',
	'TUNSrcIP'					=> '.1.3.6.1.4.1.2620.500.9003.1.7',
	'TUNLnkPrio'				=> '.1.3.6.1.4.1.2620.500.9003.1.8',
	'TUNProbState'				=> '.1.3.6.1.4.1.2620.500.9003.1.9',
	'TUNPeerType'				=> '.1.3.6.1.4.1.2620.500.9003.1.10',
);
my ($o_host,$o_community,$o_port,$o_help,$o_timeout,$o_warn,$o_crit,$o_type,$o_perf,$o_expect,$o_subtype,$o_iface);
my %reverse_exit_code = (
	'Ok'=>0,
	'Warning'=>1,
	'Critical'=>2,
	'Unknown'=>3,
);
my %log_serv_conn_state = (
	'Ok'		=>	0,
	'Warning'	=>	1,
	'Error'		=>	2,
);
my %rev_log_serv_conn_state = (
	0	=>	'Ok',
	1	=>	'Warning',
	2	=>	'Error',
);
my %expct_log_loc = (
	'remote'	=> 0,
	'local'		=> 1,
);
my %log_loc = (
	0	=> "remote",
	1	=> "local",
	2	=> "local due to error",
);
my %ref_ratio_position = (
	'ACCEPTED'	=>	0,
	'REJECTED'	=>	1,
	'DROPPED'	=>	2,
	'LOGGED'	=>	3,
);
my %ref_ratio_if_position = (
	'NAME'			=>	0,
	'ACCEPTED-IN'	=>	1,
	'ACCEPTED-OUT'	=>	2,
	'DROPPED-IN'	=>	3,
	'DROPPED-OUT'	=>	4,
	'REJECTED-IN'	=>	5,
	'REJECTED-OUT'	=>	6,
	'LOGGED-IN'		=>	7,
	'LOGGED-OUT'	=>	8,
);
my %alert_mark = (
	'Min' => 0,
	'Max' => 1
);
my %temp_sense_status = (
	'Ok'			=>	0,
	'Fail'			=>	1,
	'Read error'	=>	2,
);
my %rev_temp_sense_status = (
	0	=>	'Ok',
	1	=>	'Fail',
	2	=>	'Read error',
);
my %licence_violation_status = (
	'No'	=>	0,
	'Yes'	=>	1,
);
my %ia_curr_status = (
	0	=>	'Ok',
	1	=>	'Bad credentials',
	2	=>	'Connectivity error',
	3	=>	'Internal error',
	4	=>	'Connection timeout',
);
my %rev_ia_curr_status = (
	'Ok'					=>	0,
	'Bad credentials'		=>	1,
	'Connectivity error'	=>	2,
	'Internal error'		=>	3,
	'Connection timeout'	=>	4,
);
my %tun_state = (
	3							=> 'active',
	4							=> 'destroy',
	129							=> 'idle',
	130							=> 'phase1',
	131							=> 'down',
	132							=> 'init',
);
my %rev_tun_state = (
	'active'					=> 3,
	'destroy'					=> 4,
	'idle'						=> 129,
	'phase1'					=> 130,
	'down'						=> 131,
	'init'						=> 132,
);
my %tun_priority = (
	0							=> 'primary',
	1							=> 'backup',
	2							=> 'on-demand',
);
my %tun_probing = (
	0							=> 'unknown',
	1							=> 'alive',
	2							=> 'dead',
);
my %tun_peer_type = (
	0							=> 'Regular',
	1							=> 'Dynamically Assigned IP',
	2							=> 'ROBO',
);
my $output='';
my $perf='';
my $outputlines;
my $countcritical=0;
my $countwarning=0;
my ($snmpsession,$snmperror);

sub usage {
   print "\nSNMP Checkpoint Firewalls for Nagios. Version ",$Version,"\n";
   print "GPL Licence - Vincent FRICOU\n\n";
   print <<EOT;
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-f, --perfparse
   perfparse output (only works with -c)
-w, --warning=<value>
   Warning value
-c, --critical=<value>
   Critical value
-e, --expect=EXPECTED VALUE
   Specify expected value
-i, --iface=STRING
-T, --type=CHECK TYPE
EOT
   type_help();
   exit $reverse_exit_code{Unknown};
}

sub type_help {
print "If you no select subtype in case of type who need, you’ll display global status of type.
(First list level matched by -T, second level matched by -s and third level matched by -e)
  - firewall        : Check firewall state policies install state. You could provide -e value to name of policy expected on gateway
    * logging       : Check if Check Point Gateway correctly contact his logging server.
    * logstate      : Check if Check Point Gateway log in local, remote or local on error. You must specify -e value with one of following value :
                    -> remote : If you expect that the gateway log on remote server.
                    -> local  : If you expect that the gateway log locally.
    * connections   : Check active connections throught gateway. You must provide alert values.
    * pkts-ratio
      - accepted    : Display ratio accepted on total packets. (Could provide alert values)
      - dropped     : Display ratio dropped on total packets. (Could provide alert values)
      - rejected    : Display ratio rejected on total packets. (Could provide alert values)
      - logged      : Display ratio logged on total packets. (Could provide alert values)
    * bytes-ratio
      - accepted    : Display ratio accepted on total bytes. (Could provide alert values)
      - dropped     : Display ratio dropped on total bytes. (Could provide alert values)
      - rejected    : Display ratio rejected on total bytes. (Could provide alert values)
    * iface
      - accepted    : Display accepted packets ratio on specified interface.
      - dropped     : Display dropped packets ratio on specified interaface.
      - rejected    : Display rejected packets ratio on specified interface.
      - logged      : Display logged packets ratio on specified interface.
  - ha              : Check HA status
    * problems      : Display detailled units HA status.
  - temperature     : Check temperature sensors. You must specify alert values same as <CPU>,<Intake>,<Outlet> for twices
  - fan             : Check fan unit status. Perf data send fan speed. Go to critical if fan status have only one running. Warning from one faulted.
  - psu             : Check power supply units. Go to critical if power supply status have only one running. Warning from one faulted.
  - svn             : Check SVN status.
  - mgmt            : Check management status
    * licence       : Check licence violation.
    * active        : Check active and alive management blade.
  - anti-virus      : Check Anti-Virus status
    * subscription  : Check subscription status and expiration date.
    * updates       : Check Application Control update status.
  - anti-spam       : Check Anti-Spam status
    * stats         : Check anti-spam statistics ratio. You must provide alert values
    * detailed      : Check anti-spam detailed spam analysis.
    * subscription  : Check subscription status and expiration date.
  - identity-awareness : Check Identity Awareness global status.
    * connections
      - kerberos    : Return number of users and hosts connected throught kerberos. (Could provide alert values)
      - usrpass     : Return number of users authenticated with simple user/password scheme.
      - ad          : Return number of users and hosts authenticated throught Active Directory (Could provide alert values)
      - agent       : Return number of users authenticated with Check Point Agent.
      - portal      : Return number of users authenticated throught web portal.
      - at-login    : Return total of entities autenticated throught AD.
    * auth-server   : Check authentication servers status. (Threshold automated thought check returns).
  - application-control : Check Application Control global status.
    * subscription  : Check subscription status and expiration date.
    * updates       : Check Application Control update status.
  - urlfiltering    : Check URL Filtering global status.
    * subscription  : Check subscription status and expiration date.
    * updates       : Check URL Filtering update status.
    * radstatus     : Check RAD Status update status.
  - anti-bot        : Check Anti-Bot/Anti-Malware status
    * subscription  : Check subscription status and expiration date.
    * updates       : Check Application Control update status.
  - tunnel          : Check status of all declared VPN tunnels
";
	exit $reverse_exit_code{Unknown};
}

sub expect_help {
	print "Missing expected value.
	Please provide value by the option -e (or --expect=) report to type of check you run.\n";
	exit $reverse_exit_code{Unknown};
}
sub multi_threshold_usage {
	print "You must specify two threshold for alert values in this usecase.
	To do this, please, use -w and -c options with comma separated values.\n";
}
sub get_options () {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'h'		=>	\$o_help,		'help'			=>	\$o_help,
		'H:s'	=>	\$o_host,		'hostname:s'	=>	\$o_host,
		'C:s'	=>	\$o_community,	'community:s'	=>	\$o_community,
		'f'		=>	\$o_perf,		'perfparse'		=>	\$o_perf,
		'w:s'	=>	\$o_warn,		'warning:s'		=>	\$o_warn,
		'c:s'	=>	\$o_crit,		'critical:s'	=>	\$o_crit,
		'T:s'	=>	\$o_type,		'type:s'		=>	\$o_type,
		's:s'	=>	\$o_subtype,	'subtype:s'		=>	\$o_subtype,
		'e:s'	=>	\$o_expect,		'expect:s'		=>	\$o_expect,
		'i:s'	=>	\$o_iface,		'iface:s'		=>	\$o_iface,
	);

	usage() if (defined ($o_help));
	usage() if (! defined ($o_host) && ! defined ($o_community) && ! defined ($o_type));
	type_help() if (! defined ($o_type));
	$o_type=uc($o_type);
	$o_subtype=uc($o_subtype) if (defined $o_subtype);
	$o_expect=lc($o_expect) if (defined ($o_expect));
}

sub output_display () {
	$output =~ tr/,/\n/;
	if ($countcritical > 0){
		if ( $outputlines > 1 ) {
			print "Critical : Click for detail\n\n$output";
		} else {
			print "Critical - ".$output;
		}
		exit $reverse_exit_code{Critical};
	} elsif ($countwarning > 0){
		if ( $outputlines > 1 ) {
			print "Warning : Click for detail\n\n$output";
		} else {
			print "Warning - ".$output;
		}
		exit $reverse_exit_code{Warning};
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
		"-hostname"		=>	$o_host,
		"-version"		=>	2,
		"-community"	=>	$o_community,
	);
	($snmpsession,$snmperror) = Net::SNMP->session(%snmpparms);
	if (!defined $snmpsession) {
		printf "SNMP: %s\n", $snmperror;
		exit $reverse_exit_code{Unknown};
	}
}

sub check_alert_value () {
	if (! defined ($o_warn)) { print "Warning value missing, please use -w option.\n"; exit $reverse_exit_code{Unknown}; }
	if (! defined ($o_crit)) { print "Critical value missing, please use -c option.\n"; exit $reverse_exit_code{Unknown}; }
}
sub check_subtype () {
	if (! defined ($o_subtype)) { print "No subtype defined, please use -s option.\n"; exit $reverse_exit_code{Unknown}; }
}

get_options();

switch ($o_type) {
	case 'FIREWALL' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case "LOGGING" {
					init_snmp_session ();
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWLogServConn'}]);
					my $LogServConn = $$result{$FWOID{'FWLogServConn'}};
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWLogServer'}]);
					my $LogServer = $$result{$FWOID{'FWLogServer'}};
					$output='Connection to log server '.$LogServer." is in state ".$rev_log_serv_conn_state{$LogServConn}.",";
					++$countwarning if ($LogServConn == $log_serv_conn_state{Warning});
					++$countcritical if ($LogServConn == $log_serv_conn_state{Error});
				}
				case "LOGSTATE" {
					expect_help() if (! defined ($o_expect));
					init_snmp_session ();
					my $result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWLoggingStat'}]);
					my $LogStat = $$result{$FWOID{'FWLoggingStat'}};
					if ($LogStat != $expct_log_loc{$o_expect}){
						$output="The gateway not log on expected location,Expected : ".$o_expect." - On gateway : ".$log_loc{$LogStat} if ($log_loc{$LogStat});
						$output="The gateway not log on expected location,Expected : ".$o_expect." - On gateway : ";
						++$countcritical;
					} else {
						$output="The gateway log to expected ".$o_expect.",";
					}
				}
				case "CONNECTIONS" {
					check_alert_value ();
					init_snmp_session ();
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWInstantConnections'}]);
					my $Connections = $$result{$FWOID{'FWInstantConnections'}};
					++$countwarning if ( $Connections >= $o_warn ) && ( $Connections < $o_crit );
					++$countcritical if ( $Connections >= $o_crit );
					$output = "Actually ".$Connections." active connections on gateway";
					$perf = "Connections=".$Connections.";".$o_warn.";".$o_crit;
				}
				case "PKTS-RATIO" {
					$o_expect = uc($o_expect);
					init_snmp_session ();
					my $result;
					my @PktsCounts;
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWAcceptedPackets'}]);
					push (@PktsCounts, $$result{$FWOID{'FWAcceptedPackets'}});
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWRejectedPackets'}]);
					push (@PktsCounts, $$result{$FWOID{'FWRejectedPackets'}});
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWDroppedPackets'}]);
					push (@PktsCounts, $$result{$FWOID{'FWDroppedPackets'}});
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWLoggedPackets'}]);
					push (@PktsCounts, $$result{$FWOID{'FWLoggedPackets'}});

					my $TlPkts = $PktsCounts[$ref_ratio_position{ACCEPTED}] + $PktsCounts[$ref_ratio_position{REJECTED}] + $PktsCounts[$ref_ratio_position{DROPPED}];
					if ( $TlPkts == 0 ) {
						$output = "No data to report.";
						$perf = "Ratio=0;;;;,";
					} elsif ( $PktsCounts[$ref_ratio_position{$o_expect}] == 0 ) { 
						$output = 'No '.$o_subtype.' packets.'; 
						$perf = "Ratio=0;;;;,";
					} else {
						my $RAAcc = $PktsCounts[$ref_ratio_position{$o_expect}] / $TlPkts;
						my $RAAccPct = $RAAcc * 100;
						if (defined ($o_warn) || defined ($o_crit)) {
							my @warning= split (',', $o_warn);
							my @critical= split (',', $o_crit);
							if (scalar(@warning) <= 1){ print "Missing value to warning. Please check help :\n"; usage(); }
							if (scalar(@critical) <= 1){ print "Missing value to critical. Please check help:\n"; usage(); }
							if ( $RAAccPct <= $warning[$alert_mark{Min}] || $RAAccPct >= $warning[$alert_mark{Max}] ){
								if ($RAAccPct <= $critical[$alert_mark{Min}] || $RAAccPct >= $critical[$alert_mark{Max}] ){
									++$countcritical;
								} else {
									++$countwarning;
								}
							}
							$perf='Ratio='.$RAAccPct.';'.$warning[$alert_mark{Max}].';'.$critical[$alert_mark{Max}].';'.$critical[$alert_mark{Min}].';'.$critical[$alert_mark{Max}].',';
						}
						$output='Actual ratio : '.$RAAccPct.',';
						$output=$output.'Accepted : '.$PktsCounts[$ref_ratio_position{ACCEPTED}].',' if ( $o_subtype eq 'ACCEPTED' );
						$output=$output.'Dropped : '.$PktsCounts[$ref_ratio_position{DROPPED}].',' if ( $o_subtype eq 'DROPPED' );
						$output=$output.'Rejected : '.$PktsCounts[$ref_ratio_position{REJECTED}].',' if ( $o_subtype eq 'REJECTED' );
						$output=$output.'Logged : '.$PktsCounts[$ref_ratio_position{LOGGED}].',' if ( $o_subtype eq 'LOGGED' );
						$output=$output.'Total packet : '.$TlPkts.',';
						$perf='Ratio='.$RAAccPct.';;;;,' if (! defined ($o_warn) && ! defined ($o_crit));
						$perf=$perf.'Logged_Packets='.$PktsCounts[$ref_ratio_position{LOGGED}].';;;;,' if ( $o_subtype eq 'LOGGED' );
						$perf=$perf.'Accepted_Packets='.$PktsCounts[$ref_ratio_position{ACCEPTED}].';;;;,' if ( $o_subtype eq 'ACCEPTED' );
						$perf=$perf.'Rejected_Packets='.$PktsCounts[$ref_ratio_position{REJECTED}].';;;;,' if ( $o_subtype eq 'REJECTED' );
						$perf=$perf.'Dropped_Packets='.$PktsCounts[$ref_ratio_position{DROPPED}].';;;;,' if ( $o_subtype eq 'DROPPED' );
						$perf=$perf.'Total_Packets='.$TlPkts.';;;;,';
					}
				}
				case "BYTES-RATIO" {
					$o_expect = uc($o_expect);
					init_snmp_session ();
					my $result;
					my @PktsCounts;
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWAcceptedBytes'}]);
					push (@PktsCounts, $$result{$FWOID{'FWAcceptedBytes'}});
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWRejectedBytes'}]);
					push (@PktsCounts, $$result{$FWOID{'FWRejectedBytes'}});
					$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWDroppedBytes'}]);
					push (@PktsCounts, $$result{$FWOID{'FWDroppedBytes'}});

					my $TlPkts = $PktsCounts[$ref_ratio_position{ACCEPTED}] + $PktsCounts[$ref_ratio_position{REJECTED}] + $PktsCounts[$ref_ratio_position{DROPPED}];
					if ( $TlPkts == 0 ) {
						$output = "No data to report.";
						$perf = "Ratio=0;;;;,";
					} elsif ( $PktsCounts[$ref_ratio_position{$o_expect}] == 0 ) { 
						$output = 'No '.$o_subtype.' packets.'; 
						$perf = "Ratio=0;;;;,";
					} else {
						my $RAAcc = $PktsCounts[$ref_ratio_position{$o_expect}] / $TlPkts;
						if (defined ($o_warn) || defined ($o_crit)) {
							my @warning= split (',', $o_warn);
							my @critical= split (',', $o_crit);
							if (scalar(@warning) <= 1){ print "Missing value to warning. Please check help :\n"; usage(); }
							if (scalar(@critical) <= 1){ print "Missing value to critical. Please check help:\n"; usage(); }
							if ( $RAAcc <= $warning[$alert_mark{Min}] || $RAAcc >= $warning[$alert_mark{Max}] ){
								if ($RAAcc <= $critical[$alert_mark{Min}] || $RAAcc >= $critical[$alert_mark{Max}] ){
									++$countcritical;
								} else {
									++$countwarning;
								}
							}
							$perf='Ratio='.$RAAcc.';'.$warning[$alert_mark{Max}].';'.$critical[$alert_mark{Max}].';'.$critical[$alert_mark{Min}].';'.$critical[$alert_mark{Max}].',';
						}
						$output='Actual ratio : '.$RAAcc.',';
						$output=$output.'Accepted : '.format_bytes($PktsCounts[$ref_ratio_position{ACCEPTED}]).',' if ( $o_subtype eq 'ACCEPTED' );
						$output=$output.'Dropped : '.format_bytes($PktsCounts[$ref_ratio_position{DROPPED}]).',' if ( $o_subtype eq 'DROPPED' );
						$output=$output.'Rejected : '.format_bytes($PktsCounts[$ref_ratio_position{REJECTED}]).',' if ( $o_subtype eq 'REJECTED' );
						$output=$output.'Total packet : '.format_bytes($TlPkts).',';
						$perf='Ratio='.$RAAcc.';;;;,' if (! defined ($o_warn) && ! defined ($o_crit));
						$perf=$perf.'Accepted_Bytes='.$PktsCounts[$ref_ratio_position{ACCEPTED}].';;;;,' if ( $o_subtype eq 'ACCEPTED' );
						$perf=$perf.'Rejected_Bytes='.$PktsCounts[$ref_ratio_position{REJECTED}].';;;;,' if ( $o_subtype eq 'REJECTED' );
						$perf=$perf.'Dropped_Bytes='.$PktsCounts[$ref_ratio_position{DROPPED}].';;;;,' if ( $o_subtype eq 'DROPPED' );
						$perf=$perf.'Total_Bytes='.$TlPkts.';;;;,';
					}
				}
				case 'IFACE' {
					init_snmp_session();
					my $IFaceTable = $snmpsession->get_entries(-columns => [$FWOID{'FWIfTableIndex'}]);
					foreach my $IFID (values %$IFaceTable) {
						if ( defined $o_expect ) {
							$o_expect = uc($o_expect);
							init_snmp_session ();
							my $result;
							my @PktsCounts;
							$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfTableName'}.'.'.$IFID.'.0']);
							push (@PktsCounts, $$result{$FWOID{'FWIfTableName'}.'.'.$IFID.'.0'});
							if ( $PktsCounts[$ref_ratio_if_position{'NAME'}] eq $o_iface ) {
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatAccptPktsIn'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatAccptPktsIn'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatAccptPktsOut'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatAccptPktsOut'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatDropPktsIn'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatDropPktsIn'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatDropPktsOut'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatDropPktsOut'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatRjctPktsIn'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatRjctPktsIn'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatRjctPktsOut'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatRjctPktsOut'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatLogPktsIn'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatLogPktsIn'}.'.'.$IFID.'.0'});
								$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWIfStatLogPktsOut'}.'.'.$IFID.'.0']);
								push (@PktsCounts, $$result{$FWOID{'FWIfStatLogPktsOut'}.'.'.$IFID.'.0'});

								my $TlInPkts = $PktsCounts[$ref_ratio_if_position{'ACCEPTED-IN'}] + $PktsCounts[$ref_ratio_if_position{'REJECTED-IN'}] + $PktsCounts[$ref_ratio_if_position{'DROPPED-IN'}];
								my $TlOutPkts = $PktsCounts[$ref_ratio_if_position{'ACCEPTED-OUT'}] + $PktsCounts[$ref_ratio_if_position{'REJECTED-OUT'}] + $PktsCounts[$ref_ratio_if_position{'DROPPED-OUT'}];
								my $RAInAcc = $PktsCounts[$ref_ratio_if_position{$o_expect.'-IN'}] / $TlInPkts;
								my $RAOutAcc = $PktsCounts[$ref_ratio_if_position{$o_expect.'-OUT'}] / $TlOutPkts;
								my $RAInAccPct = $RAInAcc * 100;
								my $RAOutAccPct = $RAOutAcc * 100;
								$output = $output.'Interface '.$o_iface.' '.$o_expect.'-IN ratio '.$RAInAccPct.'%,';
								$output = $output.'Interface '.$o_iface.' '.$o_expect.'-OUT ratio '.$RAOutAccPct.'%,';
								$perf=$perf.$o_iface.'-'.$o_expect.'-IN='.$RAInAccPct.';;,';
								$perf=$perf.$o_iface.'-'.$o_expect.'-OUT='.$RAOutAccPct.';;,';
							}
						}
					}
					if ( ! $output ) {
						print 'Needed interface'.$o_iface.' doesn\'t exist';
						type_help();
					}
				}
			}
		} else {
			init_snmp_session ();
			my $result;
			$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWPolicyInstallState'}]);
			my $State = $$result{$FWOID{'FWPolicyInstallState'}};
			$result = $snmpsession->get_request(-varbindlist => [$FWOID{'FWPolicyInstalledName'}]);
			my $Name = $$result{$FWOID{'FWPolicyInstalledName'}};
			if (defined ($o_expect)) {
				if ( $State ne $o_expect ) {
					++$countcritical;
					$output = "Firewall policy wasn't in expected state : ".$State." Expected : ".$o_expect;
				 }
			} elsif ( $State ne "Installed" ) {
				++$countcritical;
				$output = "Firewall policy wasn't correctly installed : ".$State;
			} else {
				$output = "Firewall policy was correctly installed.";
			}
		}
	}
	case 'HA' {
		if (defined ($o_subtype)) {
			switch ($o_subtype) {
				case 'PROBLEMS' {
					init_snmp_session ();
					my $IDTable = $snmpsession->get_entries(-columns => [$HAOID{'HAProblemIDTable'}]);
					foreach my $PBID (keys %$IDTable) {
						my $resultPBName = $snmpsession->get_request(-varbindlist => [$HAOID{'HAProblemNameTable'}.'.'.$$IDTable{$PBID}.'.0']);
						my $resultPBState = $snmpsession->get_request(-varbindlist => [$HAOID{'HAProblemStateTable'}.'.'.$$IDTable{$PBID}.'.0']);
						if ( $$resultPBState{$HAOID{'HAProblemStateTable'}.'.'.$$IDTable{$PBID}.'.0'} ne 'OK' ) {
							$output = $output.'Problem - HA service '.$$resultPBName{$HAOID{'HAProblemNameTable'}.'.'.$$IDTable{$PBID}.'.0'}.' is in state : '.$$resultPBState{$HAOID{'HAProblemStateTable'}.'.'.$$IDTable{$PBID}.'.0'}.',';
						} else {
							$output = $output.'HA service '.$$resultPBName{$HAOID{'HAProblemNameTable'}.'.'.$$IDTable{$PBID}.'.0'}.' is '.$$resultPBState{$HAOID{'HAProblemStateTable'}.'.'.$$IDTable{$PBID}.'.0'}.',';
						}
					}
				} else { print 'Subtype not recognized'; type_help(); }
			}
		} else {
			init_snmp_session ();
			my $result;
			my @HAStatusResult;
			$result = $snmpsession->get_request(-varbindlist => [$HAOID{'HAStarted'}]);
			push (@HAStatusResult, $$result{$HAOID{'HAStarted'}});
			$result = $snmpsession->get_request(-varbindlist => [$HAOID{'HAState'}]);
			push (@HAStatusResult, $$result{$HAOID{'HAState'}});
			$result = $snmpsession->get_request(-varbindlist => [$HAOID{'HABlockState'}]);
			push (@HAStatusResult, $$result{$HAOID{'HABlockState'}});
			$result = $snmpsession->get_request(-varbindlist => [$HAOID{'HAIdentifier'}]);
			push (@HAStatusResult, $$result{$HAOID{'HAIdentifier'}});

			$output = 'Gateway ID in HA cluster : '.$HAStatusResult[3].',';
			if ( $HAStatusResult[0] ne 'yes' ) {
				++$countcritical;
				$output = $output.'Problem - HA isn\' started,';
			} else { 
				$output = $output.'HA Started,';
			}
			$output = $output.'Gateway HA status : '.$HAStatusResult[1].',';
			if ( $HAStatusResult[2] ne 'OK' ) {
				++$countcritical;
				$output = $output.'Problem - Blocking state on the gateway,,';
			} else {
				$output = $output.'State isn\'t blocking ';
			}
		}
	}
	case 'TEMPERATURE' {
		init_snmp_session ();
		check_alert_value ();
		my $SensorsID = $snmpsession->get_entries(-columns => [$SVNOID{'SVNTempSensorsID'}]);
		foreach my $Sensor (keys %$SensorsID) {
			my $resultSensorName	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0']);
			my $resultSensorValue	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0']);
			my $resultSensorUnit	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0']);
			my $resultSensorStatus	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNTempSensorsStatus'}.'.'.$$SensorsID{$Sensor}.'.0']);
			if ( $$resultSensorStatus{$SVNOID{'SVNTempSensorsStatus'}.'.'.$$SensorsID{$Sensor}.'.0'} != $temp_sense_status{Ok} ) { 
				++$countcritical if ( $$resultSensorStatus{$SVNOID{'SVNTempSensorsStatus'}.'.'.$$SensorsID{$Sensor}.'.0'} == $temp_sense_status{Fail} );
				++$countwarning if ( $$resultSensorStatus{$SVNOID{'SVNTempSensorsStatus'}.'.'.$$SensorsID{$Sensor}.'.0'} == $temp_sense_status{'Read error'} );
				$output = $output.'Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is in state '.$rev_temp_sense_status{$$resultSensorStatus{$SVNOID{'SVNTempSensorsStatus'}.'.'.$$SensorsID{$Sensor}.'.0'}}.",";
			}
			my ($SensorShortName,$Indicator) =  split (/ /,$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'});
			$SensorShortName = 'CPU' if ( $SensorShortName =~ 'CPU' );
			my @warning= split (',', $o_warn);
			my @critical= split (',', $o_crit);
			if (scalar(@warning) <= 2){ print "Missing value to warning. Please check help :\n"; usage(); }
			if (scalar(@critical) <= 2){ print "Missing value to critical. Please check help:\n"; usage(); }
			switch ($SensorShortName) {
				case 'CPU' {
					if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} >= $warning[0] ) {
						if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} < $critical[0] ) {
							++$countwarning;
							$output = $output.'Warning - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$warning[0].'),';
						} else {
							++$countcritical;
							$output = $output.'Critical - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$critical[0].'),';
						}
					} else {
							$output = $output.'Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.',';
					}
					$perf = $perf.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.'='.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.';'.$warning[0].';'.$critical[0].',';
				}
				case 'Intake' {
					if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} >= $warning[1] ) {
						if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} < $critical[1] ) {
							++$countwarning;
							$output = $output.'Warning - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$warning[1].'),';
						} else {
							++$countcritical;
							$output = $output.'Critical - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$critical[1].'),';
						}
					} else {
							$output = $output.'Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.',';
					}
					$perf = $perf.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.'='.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.';'.$warning[1].';'.$critical[1].',';
				}
				case 'Outlet' {
					if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} >= $warning[2] ) {
						if ( $$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'} < $critical[2] ) {
							++$countwarning;
							$output = $output.'Warning - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$warning[2].'),';
						} else {
							++$countcritical;
							$output = $output.'Critical - Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.' ('.$critical[2].'),';
						}
					} else {
							$output = $output.'Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.',';
					}
					$perf = $perf.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.'='.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.';'.$warning[2].';'.$critical[2].',';
				}
				else {
						$output = $output.'Sensor '.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.' is at '.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.' '.$$resultSensorUnit{$SVNOID{'SVNTempSensorsUnit'}.'.'.$$SensorsID{$Sensor}.'.0'}.',';
					$perf = $perf.$$resultSensorName{$SVNOID{'SVNTempSensorsName'}.'.'.$$SensorsID{$Sensor}.'.0'}.'='.$$resultSensorValue{$SVNOID{'SVNTempSensorsValue'}.'.'.$$SensorsID{$Sensor}.'.0'}.';;,' if ( $SensorShortName ne 'CPU' || $SensorShortName ne 'Intake');
				}
			}
		}
	}
	case 'FAN' {
		init_snmp_session ();
		my $FanID = $snmpsession->get_entries(-columns => [$SVNOID{'SVNFanSpeedsID'}]);
		my $NBFans = keys (%$FanID);
		my $CountFaulted = $NBFans;
		foreach my $Fan (keys %$FanID) {
			my $resultFanName	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNFanSpeedsName'}.'.'.$$FanID{$Fan}.'.0']);
			my $resultFanValue	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNFanSpeedsValue'}.'.'.$$FanID{$Fan}.'.0']);
			my $resultFanUnit	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNFanSpeedsUnit'}.'.'.$$FanID{$Fan}.'.0']);
			my $resultFanStatus	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNFanSpeedsStatus'}.'.'.$$FanID{$Fan}.'.0']);
			if ( $$resultFanStatus{$SVNOID{'SVNFanSpeedsStatus'}.'.'.$$FanID{$Fan}.'.0'} != $temp_sense_status{Ok} ) {
				--$CountFaulted;
			}
			$output = $output.'Fan ID '.$$resultFanName{$SVNOID{'SVNFanSpeedsName'}.'.'.$$FanID{$Fan}.'.0'}.' is in state '.$rev_temp_sense_status{$$resultFanStatus{$SVNOID{'SVNFanSpeedsStatus'}.'.'.$$FanID{$Fan}.'.0'}}.' - '.$$resultFanValue{$SVNOID{'SVNFanSpeedsValue'}.'.'.$$FanID{$Fan}.'.0'}.' '.$$resultFanUnit{$SVNOID{'SVNFanSpeedsUnit'}.'.'.$$FanID{$Fan}.'.0'}. ',';
			$perf = $perf.$$resultFanName{$SVNOID{'SVNFanSpeedsName'}.'.'.$$FanID{$Fan}.'.0'}.'='.$$resultFanValue{$SVNOID{'SVNFanSpeedsValue'}.'.'.$$FanID{$Fan}.'.0'}.';;,';
			++$countcritical if ( $CountFaulted <= 1 );
			++$countwarning if ( $CountFaulted < $NBFans );
		}
	}
	case 'PSU' {
		init_snmp_session ();
		my $PSUID = $snmpsession->get_entries(-columns => [$SVNOID{'SVNPSUID'}]);
		my $CountFaulted = keys (%$PSUID);
		my $NBPSU = keys (%$PSUID);
		foreach my $PSU (keys %$PSUID) {
			my $resultPSUState	= $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNPSUStatus'}.'.'.$$PSUID{$PSU}.'.0']);
			if ( $$resultPSUState{$SVNOID{'SVNPSUStatus'}.'.'.$$PSUID{$PSU}.'.0'} ne 'Up' ) {
				--$CountFaulted;
			}
			$output = $output.'PSU ID '.$$PSUID{$PSU}.' is in state '.$$resultPSUState{$SVNOID{'SVNPSUStatus'}.'.'.$$PSUID{$PSU}.'.0'}.',';
			++$countcritical if ( $CountFaulted <= 1 );
			++$countwarning if ( $CountFaulted < $NBPSU );
		}
	}
	case 'SVN' {
		init_snmp_session ();
		my $result = $snmpsession->get_request(-varbindlist => [$SVNOID{'SVNStatus'}]);
		++$countwarning if ($$result{$SVNOID{'SVNStatus'}} == $log_serv_conn_state{'Warning'});
		++$countcritical if ($$result{$SVNOID{'SVNStatus'}} == $log_serv_conn_state{'Error'});
		$output = 'SVN Status : '.$rev_log_serv_conn_state{$$result{$SVNOID{'SVNStatus'}}};
	}
	case 'MGMT' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'LICENCE' {
					init_snmp_session ();
					my $resultLV	= $snmpsession->get_request(-varbindlist => [$MGMTOID{'MGMTLicenceViolation'}]);
					if ( $$resultLV{$MGMTOID{'MGMTLicenceViolation'}} != $licence_violation_status{'No'} ) {
						my $resultLVMsg	= $snmpsession->get_request(-varbindlist => [$MGMTOID{'MGMTLicenceViolationMsg'}]);
						$output = 'You are in licence violation case : '.$$resultLVMsg{$MGMTOID{'MGMTLicenceViolationMsg'}};
						++$countcritical;
					} else {
						$output = 'No licence violation.'
					}
				}
				case 'ACTIVE' {
					init_snmp_session ();
					my $resultActive	= $snmpsession->get_request(-varbindlist => [$MGMTOID{'MGMTActiveStatus'}]);
					my $resultAlive		= $snmpsession->get_request(-varbindlist => [$MGMTOID{'MGMTAlive'}]);
					if ( $$resultActive{$MGMTOID{'MGMTActiveStatus'}} eq 'active' ) {
						if ( $$resultAlive{$MGMTOID{'MGMTAlive'}} == 0 ) {
							++$countcritical;
							$output = 'Critical - Management is active but not alive';
						} else {
							$output = 'Management is active and alive';
						}
					} else {
						++$countcritical;
						if ( $$resultAlive{$MGMTOID{'MGMTAlive'}} == 0 ) {
							++$countcritical;
							$output = 'Critical - Management is inactive and not alive';
						} else {
							$output = 'Critical - Management is inactive but alive';
						}
					}
				}
				else { print "Subtype not recognized \n";type_help(); }
			}
		} else {
			init_snmp_session();
			my $result = $snmpsession->get_request(-varbindlist => [$MGMTOID{'MGMTStatus'}]);
			++$countwarning if ( $$result{$MGMTOID{'MGMTStatus'}} == $log_serv_conn_state{'Warning'} );
			++$countcritical if ( $$result{$MGMTOID{'MGMTStatus'}} == $log_serv_conn_state{'Error'} );
			$output = 'Management global status : '.$rev_log_serv_conn_state{$$result{$MGMTOID{'MGMTStatus'}}};

		}
	}
	case 'ANTI-VIRUS'{
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'SUBSCRIPTION' {
					init_snmp_session();
					check_alert_value();
					my @AVISubs;
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVISubsStatus'}]);
					push (@AVISubs, $$result{$AVIROID{'AVISubsStatus'}});
					$result = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVISubsExpDate'}]);
					my $ExpDateTS = str2time($$result{$AVIROID{'AVISubsExpDate'}});
					push (@AVISubs, $$result{$AVIROID{'AVISubsExpDate'}});
					$result = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVISubsDesc'}]);
					push (@AVISubs, $$result{$AVIROID{'AVISubsDesc'}});
					if ( $AVISubs[0] ne 'valid' ) {
						++$countcritical;
						$output = 'Anti-Virus Subscription is '.$AVISubs[0].' '.$AVISubs[2].',';
					} else {
						$output = 'Anti-Virus Subscription is '.$AVISubs[0].',';
					}
					my ($warning,$critical);
					my $warn = $o_warn;
					my $crit = $o_crit;
					if ($o_warn =~ 'y') { $warn =~ tr/'y'/' '/; $warning = $warn * 364 * 24 * 60 * 60;}
					if ($o_warn =~ 'd') { $warn =~ tr/'d'/' '/; $warning = $warn * 24 * 60 * 60;}
					if ($o_warn =~ 'h') { $warn =~ tr/'h'/' '/; $warning = $warn * 60 * 60; }
					if ($o_crit =~ 'y') { $crit =~ tr/'y'/' '/; $critical = $crit * 364 * 24 * 60 * 60;}
					if ($o_crit =~ 'd') { $crit =~ tr/'d'/' '/; $critical = $crit * 24 * 60 * 60; }
					if ($o_crit =~ 'h') { $crit =~ tr/'h'/' '/; $critical = $crit * 60 * 60; }
					my $warningtimestamp = $ExpDateTS - $warning;
					my $criticaltimestamp = $ExpDateTS - $critical;
					if ( $warningtimestamp <= time ) {
						if ( $criticaltimestamp <= time ) {
							++$countcritical;
							$output = $output."Critical - Subscription expiration date ".$AVISubs[1].'. Alert from '.$o_crit.' before ('.localtime($criticaltimestamp).'),';
						} else {
							++$countwarning;
							$output = $output."Warning - Subscription expiration date ".$AVISubs[1].'. Alert from '.$o_warn.' before ('.localtime($warningtimestamp).'),';
						}
					} else {
							$output = $output."Subscription expire on ".$AVISubs[1].' alert will comming on '.localtime($warningtimestamp).',';
					}
				}
				case 'UPDATES' {
					init_snmp_session();
					my $rsStatus = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVIUpdateStatus'}]);
					my $rsDesc = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVIUpdateDesc'}]);
					if ( $$rsStatus{$AVIROID{'AVIUpdateStatus'}} eq 'new' || $$rsStatus{$AVIROID{'AVIUpdateStatus'}} eq 'up-to-date' ) {
						$output = 'Ok - '.$$rsStatus{$AVIROID{'AVIUpdateStatus'}}.' '.$$rsDesc{$AVIROID{'AVIUpdateDesc'}}."\n";
					} elsif ( $$rsStatus{$AVIROID{'AVIUpdateStatus'}} eq 'unknown' ) {
						$output = $$rsStatus{$AVIROID{'AVIUpdateStatus'}}.' '.$$rsDesc{$AVIROID{'AVIUpdateDesc'}}."\n";
						print $output;
						exit $reverse_exit_code{Unknown};
					} elsif ( $$rsStatus{$AVIROID{'AVIUpdateStatus'}} eq 'degrade' ) {
						++$countwarning;
						$output = 'Warning - '.$$rsStatus{$AVIROID{'AVIUpdateStatus'}}.' '.$$rsDesc{$AVIROID{'AVIUpdateDesc'}}."\n";
					} else {
						++$countcritical;
						$output = 'Critical - '.$$rsStatus{$AVIROID{'AVIUpdateStatus'}}.' '.$$rsDesc{$AVIROID{'AVIUpdateDesc'}}."\n";
					}
				} else { print 'Not recognized subtype'; type_help(); }
			}
		} else {
			init_snmp_session();
			my $result = $snmpsession->get_request(-varbindlist => [$AVIROID{'AVIStatus'}]);
			++$countwarning if ( $$result{$AVIROID{'AVIStatus'}} == $log_serv_conn_state{'Warning'} );
			++$countcritical if ( $$result{$AVIROID{'AVIStatus'}} == $log_serv_conn_state{'Error'} );
			$output = 'Anti-Virus status : '.$rev_log_serv_conn_state{$$result{$AVIROID{'AVIStatus'}}};
		}
	}
	case 'ANTI-SPAM' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'STATS' {
					check_alert_value ();
					init_snmp_session ();
					my $rsScanned		= $snmpsession->get_request(-varbindlist => [$MSOID{'MSScannedMail'}]);
					my $rsSpam			= $snmpsession->get_request(-varbindlist => [$MSOID{'MSSpamMail'}]);
					my $rsHandled		= $snmpsession->get_request(-varbindlist => [$MSOID{'MSSpamHandled'}]);
					my $HAState			= $snmpsession->get_request(-varbindlist => [$HAOID{'HAState'}]);
					my $SpamRatio;
					my $HandledRatio;
					if ( $$rsScanned{$MSOID{'MSScannedMail'}} > 0 ) {
						$SpamRatio		= $$rsSpam{$MSOID{'MSSpamMail'}} / $$rsScanned{$MSOID{'MSScannedMail'}}
					} else {
						$SpamRatio		= 0;
					}
					if ( $$rsSpam{$MSOID{'MSSpamMail'}} > 0 ) {
						$HandledRatio	= $$rsHandled{$MSOID{'MSSpamHandled'}} / $$rsSpam{$MSOID{'MSSpamMail'}}
					} else {
						$HandledRatio	= 0;
					}
					$SpamRatio			= $SpamRatio * 100;
					$HandledRatio		= $HandledRatio * 100;
					if ( $HAState eq "active" ) {
						if ( $HandledRatio <= $o_warn ) {
							if ( $HandledRatio <= $o_crit ) {
								++$countcritical;
								$output = $output.'Poor handle spam ratio : '.$HandledRatio.'% ('.$o_crit.'%),';
								$output = $output.'Scanned e-mail ratio : '.$SpamRatio.',';
							} else {
								++$countwarning;
								$output = $output.'Alerting handle spam ratio : '.$HandledRatio.'% ('.$o_warn.'%),';
								$output = $output.'Scanned e-mail ratio : '.$SpamRatio.',';
							}
						} else {
							$output = $output.'Handled spam ratio : '.$HandledRatio.',';
							$output = $output.'Scanned e-mail ratio : '.$SpamRatio.',';
						}
					} else {
						$output = $output.'Handled spam ratio : '.$HandledRatio.',';
						$output = $output.'Scanned e-mail ratio : '.$SpamRatio.',';
					}
					$perf = $perf.'Handled ratio='.$HandledRatio.';'.$o_warn.';'.$o_crit.',';
					$perf = $perf.'Spam ratio='.$SpamRatio.';;,';
				}
				case 'DETAILED' {
					init_snmp_session ();
					my $rsCtrlSpamEngine		= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlSpamEngine'}]);
					my $rsCtrlIPRep				= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlIPRep'}]);
					my $rsCtrlSPF				= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlSPF'}]);
					my $rsCtrlDomainKeys		= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlDomainKeys'}]);
					my $rsCtrlRDNS				= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlRDNS'}]);
					my $rsCtrlRBL				= $snmpsession->get_request(-varbindlist => [$MSOID{'MSControlRBL'}]);
					$output = $output.'Spam filtered by Spam Engine : '.$$rsCtrlSpamEngine{$MSOID{'MSControlSpamEngine'}}.',';
					$output = $output.'Spam filtered by IP Reputation : '.$$rsCtrlIPRep{$MSOID{'MSControlIPRep'}}.',';
					$output = $output.'Spam filtered by SPF : '.$$rsCtrlSPF{$MSOID{'MSControlSPF'}}.',';
					$output = $output.'Spam filtered by Domain Keys : '.$$rsCtrlDomainKeys{$MSOID{'MSControlDomainKeys'}}.',';
					$output = $output.'Spam filtered by Reverse DNS : '.$$rsCtrlRDNS{$MSOID{'MSControlRDNS'}}.',';
					$output = $output.'Spam filtered by Domain Blacklist : '.$$rsCtrlRBL{$MSOID{'MSControlRBL'}}.',';
					$perf = $perf.'Spam Engine='.$$rsCtrlSpamEngine{$MSOID{'MSControlSpamEngine'}}.';;,';
					$perf = $perf.'IP Reputation='.$$rsCtrlIPRep{$MSOID{'MSControlIPRep'}}.';;,';
					$perf = $perf.'SPF='.$$rsCtrlSPF{$MSOID{'MSControlSPF'}}.';;,';
					$perf = $perf.'Domain Keys='.$$rsCtrlDomainKeys{$MSOID{'MSControlDomainKeys'}}.';;,';
					$perf = $perf.'Reverse DNS='.$$rsCtrlRDNS{$MSOID{'MSControlRDNS'}}.';;,';
					$perf = $perf.'Domain Blacklist='.$$rsCtrlRBL{$MSOID{'MSControlRBL'}}.';;,';
				}
				case 'SUBSCRIPTION' {
					init_snmp_session();
					check_alert_value();
					my @MSSubs;
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$MSOID{'MSSubsStatus'}]);
					push (@MSSubs, $$result{$MSOID{'MSSubsStatus'}});
					$result = $snmpsession->get_request(-varbindlist => [$MSOID{'MSSubsExpDate'}]);
					my $ExpDateTS = str2time($$result{$MSOID{'MSSubsExpDate'}});
					push (@MSSubs, $$result{$MSOID{'MSSubsExpDate'}});
					$result = $snmpsession->get_request(-varbindlist => [$MSOID{'MSSubsDesc'}]);
					push (@MSSubs, $$result{$MSOID{'MSSubsDesc'}});
					if ( $MSSubs[0] ne 'valid' ) {
						++$countcritical;
						$output = 'Anti-Virus Subscription is '.$MSSubs[0].' '.$MSSubs[2].',';
					} else {
						$output = 'Anti-Virus Subscription is '.$MSSubs[0].',';
					}
					my ($warning,$critical);
					my $warn = $o_warn;
					my $crit = $o_crit;
					if ($o_warn =~ 'y') { $warn =~ tr/'y'/' '/; $warning = $warn * 364 * 24 * 60 * 60;}
					if ($o_warn =~ 'd') { $warn =~ tr/'d'/' '/; $warning = $warn * 24 * 60 * 60;}
					if ($o_warn =~ 'h') { $warn =~ tr/'h'/' '/; $warning = $warn * 60 * 60; }
					if ($o_crit =~ 'y') { $crit =~ tr/'y'/' '/; $critical = $crit * 364 * 24 * 60 * 60; }
					if ($o_crit =~ 'd') { $crit =~ tr/'d'/' '/; $critical = $crit * 24 * 60 * 60; }
					if ($o_crit =~ 'h') { $crit =~ tr/'h'/' '/; $critical = $crit * 60 * 60; }
					my $warningtimestamp = $ExpDateTS - $warning;
					my $criticaltimestamp = $ExpDateTS - $critical;
					if ( $warningtimestamp <= time ) {
						if ( $criticaltimestamp <= time ) {
							++$countcritical;
							$output = $output."Critical - Subscription expiration date ".$MSSubs[1].'. Alert from '.$o_crit.' before ('.localtime($criticaltimestamp).'),';
						} else {
							++$countwarning;
							$output = $output."Warning - Subscription expiration date ".$MSSubs[1].'. Alert from '.$o_warn.' before ('.localtime($warningtimestamp).'),';
						}
					} else {
							$output = $output."Subscription expire on ".$MSSubs[1].' alert will comming on '.localtime($warningtimestamp).',';
					}
				} else { print 'Not recognized subtype '; type_help(); }
			}
		} else {
			init_snmp_session();
			my $result = $snmpsession->get_request(-varbindlist => [$MSOID{'MSStatusState'}]);
			my $resultMsg = $snmpsession->get_request(-varbindlist => [$MSOID{'MSStatusMsg'}]);
			my $resultLgMsg = $snmpsession->get_request(-varbindlist => [$MSOID{'MSStatusLongMsg'}]);
			++$countwarning if ( $$result{$MSOID{'MSStatusState'}} == $log_serv_conn_state{'Warning'} );
			++$countcritical if ( $$result{$MSOID{'MSStatusState'}} == $log_serv_conn_state{'Error'} );
			$output = 'Anti-Spam bad status : '.$rev_log_serv_conn_state{$$result{$MSOID{'MSStatusState'}}}.','.$$resultMsg{$MSOID{'MSStatusMsg'}}.','.$$resultLgMsg{$MSOID{'MSStatusLongMsg'}}.',' if ( $$result{$MSOID{'MSStatusState'}} != $log_serv_conn_state{'Ok'} );
			$output = 'Anti-Spam status : '.$rev_log_serv_conn_state{$$result{$MSOID{'MSStatusState'}}} if ( $$result{$MSOID{'MSStatusState'}} == $log_serv_conn_state{'Ok'} );
		}
	}
	case 'IDENTITY-AWARENESS' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case "CONNECTIONS" {
					if (defined $o_expect) {
						$o_expect = uc($o_expect);
						switch ($o_expect) {
							case 'KERBEROS'{
								init_snmp_session ();
								my $rsUsr	= $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthUsrKrb'}]);
								my $rsHst	= $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthHstKrb'}]);
								if (defined ($o_warn) && defined ($o_crit)) {
									if ( $$rsUsr{$IAOID{'IAAuthUsrKrb'}} >= $o_warn ) {
										if ( $$rsUsr{$IAOID{'IAAuthUsrKrb'}} >= $o_crit ){
											++$countcritical;
											$output = $output.'Critical - ';
										} else {
											++$countwarning;
											$output = $output.'Warning - ';
										}
									}
									if ( $$rsHst{$IAOID{'IAAuthHstKrb'}} >= $o_warn ) {
										if ( $$rsHst{$IAOID{'IAAuthHstKrb'}} >= $o_crit ){
											++$countcritical;
										} else {
											++$countwarning;
										}
									}
									$output = $output.'Critical - ' if ( $countcritical >= 1 );
									$output = $output.'Warning - ' if ( $countwarning >= 1 && $countcritical < 1 );
								}
								$output = $output.'Kerberos authenticated users : '.$$rsUsr{$IAOID{'IAAuthUsrKrb'}}.',';
								$output = $output.'Kerberos authenticated hosts : '.$$rsHst{$IAOID{'IAAuthHstKrb'}}.',';
								$perf = 'Krb_users='.$$rsUsr{$IAOID{'IAAuthUsrKrb'}}.';;,Krb_hosts='.$$rsHst{$IAOID{'IAAuthHstKrb'}}.';;,' if ( ! defined ($o_warn) && ! defined ($o_crit) );
								$perf = 'Krb_users='.$$rsUsr{$IAOID{'IAAuthUsrKrb'}}.';'.$o_warn.';'.$o_crit.',Krb_hosts='.$$rsHst{$IAOID{'IAAuthHstKrb'}}.';'.$o_warn.';'.$o_crit.',' if ( defined ($o_warn) && defined ($o_crit) );
							}
							case 'USRPASS'{
								init_snmp_session ();
								my $result = $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthUsrPass'}]);
								$output = 'Login password connected user : '.$$result{$IAOID{'IAAuthUsrPass'}}.',';
								$perf = 'login_password_usrs='.$$result{$IAOID{'IAAuthUsrPass'}}.'::,';
							}
							case 'AD' {
								init_snmp_session ();
								my $rsUsr	= $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthUsrAD'}]);
								my $rsHst	= $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthHstAD'}]);
								if (defined ($o_warn) && defined ($o_crit)) {
									if ( $$rsUsr{$IAOID{'IAAuthUsrAD'}} >= $o_warn ) {
										if ( $$rsUsr{$IAOID{'IAAuthUsrAD'}} >= $o_crit ){
											++$countcritical;
										} else {
											++$countwarning;
										}
									}
									if ( $$rsHst{$IAOID{'IAAuthHstAD'}} >= $o_warn ) {
										if ( $$rsHst{$IAOID{'IAAuthHstAD'}} >= $o_crit ){
											++$countcritical;
										} else {
											++$countwarning;
										}
									}
									$output = $output.'Critical - ' if ( $countcritical >= 1 );
									$output = $output.'Warning - ' if ( $countwarning >= 1 && $countcritical < 1 );
								}
								$output = $output.'Active Directory authenticated users : '.$$rsUsr{$IAOID{'IAAuthUsrAD'}}.',';
								$output = $output.'Active Directory authenticated hosts : '.$$rsHst{$IAOID{'IAAuthHstAD'}}.',';
								$perf = 'AD_users='.$$rsUsr{$IAOID{'IAAuthUsrAD'}}.';;,AD_hosts='.$$rsHst{$IAOID{'IAAuthHstAD'}}.';;,' if ( ! defined ($o_warn) && ! defined ($o_crit) );
								$perf = 'AD_users='.$$rsUsr{$IAOID{'IAAuthUsrAD'}}.';'.$o_warn.';'.$o_crit.',AD_hosts='.$$rsHst{$IAOID{'IAAuthHstAD'}}.';'.$o_warn.';'.$o_crit.',' if ( defined ($o_warn) && defined ($o_crit) );
							}
							case 'AGENT' {
								init_snmp_session ();
								my $result = $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthInAgt'}]);
								$output = 'Users connected by agent : '.$$result{$IAOID{'IAAuthInAgt'}}.',';
								$perf = 'Agent_users='.$$result{$IAOID{'IAAuthInAgt'}}.'::,';
							}
							case 'PORTAL' {
								init_snmp_session ();
								my $result = $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthInPortal'}]);
								$output = 'Users connected by portal : '.$$result{$IAOID{'IAAuthInPortal'}}.',';
								$perf = 'Portal_users='.$$result{$IAOID{'IAAuthInPortal'}}.'::,';
							}
							case 'AT-LOGIN' {
								init_snmp_session ();
								my $result = $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthInAD'}]);
								$output = 'At connection Active Directory logged : '.$$result{$IAOID{'IAAuthInAD'}}.',';
								$perf = 'At_logon_auth='.$$result{$IAOID{'IAAuthInAD'}}.'::,';
							}
							else { print "No matching subtype \n"; type_help(); }
						}
					} else {
						init_snmp_session ();
						my $result = $snmpsession->get_request(-varbindlist => [$IAOID{'IAAuthUsr'}]);
						my $resultUA = $snmpsession->get_request(-varbindlist => [$IAOID{'IAUnAuthUsr'}]);
						if (defined ($o_warn) && defined ($o_crit)) {
							if ( $$result{$IAOID{'IAAuthUsr'}} >= $o_warn ) {
								if ( $$result{$IAOID{'IAAuthUsr'}} >= $o_crit ){
									++$countcritical;
									$output = $output.'Critical - ';
									$perf = 'Connected_Users='.$$result{$IAOID{'IAAuthUsr'}}.';'.$o_warn.';'.$o_crit.',';
									$perf = $perf.'Unauthenticated_Users='.$$resultUA{$IAOID{'IAUnAuthUsr'}}.';;,';
								} else {
									++$countwarning;
									$output = $output.'Warning - ';
									$perf = 'Connected_Users='.$$result{$IAOID{'IAAuthUsr'}}.';'.$o_warn.';'.$o_crit.',';
									$perf = $perf.'Unauthenticated_Users='.$$resultUA{$IAOID{'IAUnAuthUsr'}}.';;,';
								}
							}
						}
						$output = $output.'Actually authenticated users : '.$$result{$IAOID{'IAAuthUsr'}}.',';
						$output = $output.'Unauthenticated users : '.$$resultUA{$IAOID{'IAUnAuthUsr'}}.',';
						$perf = 'Connected_Users='.$$result{$IAOID{'IAAuthUsr'}}.';;,Unauthenticated_Users='.$$resultUA{$IAOID{'IAUnAuthUsr'}}.';;,' if ( $perf eq '' );
					}
				}
				case 'AUTH-SERVER'{
					init_snmp_session ();
					my $rsADID = $snmpsession->get_entries(-columns => [$IAOID{'IAADQueryStatusTableID'}]);
					my $NBAD = keys %$rsADID;
					foreach my $ADID ( values %$rsADID ) {
						my $rsADStatus		= $snmpsession->get_request(-varbindlist => [$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0']);
						my $rsADDomain		= $snmpsession->get_request(-varbindlist => [$IAOID{'IAADQueryStatusDomainName'}.'.'.$ADID.'.0']);
						my $rsADIP			= $snmpsession->get_request(-varbindlist => [$IAOID{'IAADQueryStatusDomainIP'}.'.'.$ADID.'.0']);
						if ( $$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'} == $rev_ia_curr_status{'Connectivity error'} || $$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'} == $rev_ia_curr_status{'Internal error'} || $$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'} == $rev_ia_curr_status{'Connection timeout'} ) {
							++$countcritical;
							$output = $output.'Critical - Active Directory '.$$rsADIP{$IAOID{'IAADQueryStatusDomainIP'}.'.'.$ADID.'.0'}.' for domain '.$$rsADDomain{$IAOID{'IAADQueryStatusDomainName'}.'.'.$ADID.'.0'}.' is in state '.$ia_curr_status{$$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'}}.',';
						} elsif ( $$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'} != $rev_ia_curr_status{'Ok'} ){
							++$countwarning;
							$output = $output.'Warning - Active Directory '.$$rsADIP{$IAOID{'IAADQueryStatusDomainIP'}.'.'.$ADID.'.0'}.' for domain '.$$rsADDomain{$IAOID{'IAADQueryStatusDomainName'}.'.'.$ADID.'.0'}.' is in state '.$ia_curr_status{$$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'}}.',';
						} else {
							$output = $output.'Active Directory '.$$rsADIP{$IAOID{'IAADQueryStatusDomainIP'}.'.'.$ADID.'.0'}.' for domain '.$$rsADDomain{$IAOID{'IAADQueryStatusDomainName'}.'.'.$ADID.'.0'}.' is in state '.$ia_curr_status{$$rsADStatus{$IAOID{'IAADQueryStatusCurr'}.'.'.$ADID.'.0'}}.',';
						}
					}
					$countwarning = $countcritical if ( $countcritical < $NBAD );
					$countcritical = 0 if ( $countcritical < $NBAD );
				}
				else { print "Subtype not recognized \n"; type_help (); }
			}
		} else {
				init_snmp_session ();
				my $rsIASt		= $snmpsession->get_request(-varbindlist => [$IAOID{'IAStatus'}]);
				my $rsIAStMsg	= $snmpsession->get_request(-varbindlist => [$IAOID{'IAStatusMsg'}]);
				if ( $$rsIASt{$IAOID{'IAStatus'}} == $rev_ia_curr_status{'Connectivity error'} || $$rsIASt{$IAOID{'IAStatus'}} == $rev_ia_curr_status{'Internal error'} || $$rsIASt{$IAOID{'IAStatus'}} == $rev_ia_curr_status{'Connection timeout'} ) {
					++$countcritical;
					$output = $output.'Critical - Identity Awareness is in state '.$ia_curr_status{$$rsIASt{$IAOID{'IAStatus'}}}.' with message : '.$$rsIAStMsg{$IAOID{IAStatusMsg}}.',';
				} elsif ( $$rsIASt{$IAOID{'IAStatus'}} != $rev_ia_curr_status{'Ok'} ) {
					++$countwarning;
					$output = $output.'Warning - Identity Awareness is in state '.$ia_curr_status{$$rsIASt{$IAOID{'IAStatus'}}}.' with message : '.$$rsIAStMsg{$IAOID{IAStatusMsg}}.',';
				} else {
					$output = $output.'Identity Awareness is in state '.$ia_curr_status{$$rsIASt{$IAOID{'IAStatus'}}}.',';
				}
		}
	}
	case 'APPLICATION-CONTROL' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'SUBSCRIPTION' {
					init_snmp_session();
					check_alert_value();
					my @ACSubs;
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACSubsStatus'}]);
					push (@ACSubs, $$result{$APPCTRLOID{'ACSubsStatus'}});
					$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACSubsExpDate'}]);
					my $ExpDateTS = str2time($$result{$APPCTRLOID{'ACSubsExpDate'}});
					push (@ACSubs, $$result{$APPCTRLOID{'ACSubsExpDate'}});
					$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACSubsDesc'}]);
					push (@ACSubs, $$result{$APPCTRLOID{'ACSubsDesc'}});
					if ( $ACSubs[0] ne 'valid' ) {
						++$countcritical;
						$output = 'Application Control Subscription is '.$ACSubs[0].' '.$ACSubs[2].',';
					} else {
						$output = 'Application Control Subscription is '.$ACSubs[0].',';
					}
					my ($warning,$critical);
					my $warn = $o_warn;
					my $crit = $o_crit;
					if ($o_warn =~ 'y') { $warn =~ tr/'y'/' '/; $warning = $warn * 364 * 24 * 60 * 60;}
					if ($o_warn =~ 'd') { $warn =~ tr/'d'/' '/; $warning = $warn * 24 * 60 * 60;}
					if ($o_warn =~ 'h') { $warn =~ tr/'h'/' '/; $warning = $warn * 60 * 60; }
					if ($o_crit =~ 'y') { $crit =~ tr/'y'/' '/; $critical = $crit * 364 * 24 * 60 * 60; }
					if ($o_crit =~ 'd') { $crit =~ tr/'d'/' '/; $critical = $crit * 24 * 60 * 60; }
					if ($o_crit =~ 'h') { $crit =~ tr/'h'/' '/; $critical = $crit * 60 * 60; }
					my $warningtimestamp = $ExpDateTS - $warning;
					my $criticaltimestamp = $ExpDateTS - $critical;
					if ( $warningtimestamp <= time ) {
						if ( $criticaltimestamp <= time ) {
							++$countcritical;
							$output = $output."Critical - Subscription expiration date ".$ACSubs[1].'. Alert from '.$o_crit.' before ('.localtime($criticaltimestamp).'),';
						} else {
							++$countwarning;
							$output = $output."Warning - Subscription expiration date ".$ACSubs[1].'. Alert from '.$o_warn.' before ('.localtime($warningtimestamp).'),';
						}
					} else {
							$output = $output."Subscription expire on ".$ACSubs[1].' alert will comming on '.localtime($warningtimestamp).',';
					}
				}
				case 'UPDATES' {
					init_snmp_session();
					my $rsStatus = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACUpdateStatus'}]);
					my $rsDesc = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACUpdateDesc'}]);
					if ( $$rsStatus{$APPCTRLOID{'ACUpdateStatus'}} eq 'new' || $$rsStatus{$APPCTRLOID{'ACUpdateStatus'}} eq 'up-to-date' ) {
						$output = 'Ok - '.$$rsStatus{$APPCTRLOID{'ACUpdateStatus'}}.' '.$$rsDesc{$APPCTRLOID{'ACUpdateDesc'}}."\n";
					} elsif ( $$rsStatus{$APPCTRLOID{'ACUpdateStatus'}} eq 'unknown' ) {
						$output = $$rsStatus{$APPCTRLOID{'ACUpdateStatus'}}.' '.$$rsDesc{$APPCTRLOID{'ACUpdateDesc'}}."\n";
						print $output;
						exit $reverse_exit_code{Unknown};
					} elsif ( $$rsStatus{$APPCTRLOID{'ACUpdateStatus'}} eq 'degrade' ) {
						++$countwarning;
						$output = 'Warning - '.$$rsStatus{$APPCTRLOID{'ACUpdateStatus'}}.' '.$$rsDesc{$APPCTRLOID{'ACUpdateDesc'}}."\n";
					} else {
						++$countcritical;
						$output = 'Critical - '.$$rsStatus{$APPCTRLOID{'ACUpdateStatus'}}.' '.$$rsDesc{$APPCTRLOID{'ACUpdateDesc'}}."\n";
					}
				}
				else { print "Subtype not recognized \n"; type_help(); }
			}
		} else {
			init_snmp_session();
			my @ACStatus;
			my $result;
			$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACStatusCode'}]);
			push (@ACStatus, $$result{$APPCTRLOID{'ACStatusCode'}});
			$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACStatusMsg'}]);
			push (@ACStatus, $$result{$APPCTRLOID{'ACStatusMsg'}});
			$result = $snmpsession->get_request(-varbindlist => [$APPCTRLOID{'ACStatusLongMsg'}]);
			push (@ACStatus, $$result{$APPCTRLOID{'ACStatusLongMsg'}});
			if ( $ACStatus[0] != $log_serv_conn_state{'Ok'} ) {
				++$countcritical;
				$output = 'Critical - Application Control is in '.$rev_log_serv_conn_state{$ACStatus[0]}.' state with message : '.$ACStatus[1].','.$ACStatus[2].',';
			} else {
				$output = 'Application Control is in '.$rev_log_serv_conn_state{$ACStatus[0]}.',';
			}
		}
	}
	case 'URLFILTERING' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'SUBSCRIPTION' {
					init_snmp_session();
					check_alert_value();
					my @ADVFSubs;
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFSubsStatus'}]);
					push (@ADVFSubs, $$result{$ADVFOID{'ADVFSubsStatus'}});
					$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFSubsExpDate'}]);
					my $ExpDateTS = str2time($$result{$ADVFOID{'ADVFSubsExpDate'}});
					push (@ADVFSubs, $$result{$ADVFOID{'ADVFSubsExpDate'}});
					$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFSubsDesc'}]);
					push (@ADVFSubs, $$result{$ADVFOID{'ADVFSubsDesc'}});
					if ( $ADVFSubs[0] ne 'valid' ) {
						++$countcritical;
						$output = 'URL Filtering Subscription is '.$ADVFSubs[0].' '.$ADVFSubs[2].',';
					} else {
						$output = 'URL Filtering Subscription is '.$ADVFSubs[0].',';
					}
					my ($warning,$critical);
					my $warn = $o_warn;
					my $crit = $o_crit;
					if ($o_warn =~ 'y') { $warn =~ tr/'y'/' '/; $warning = $warn * 364 * 24 * 60 * 60;}
					if ($o_warn =~ 'd') { $warn =~ tr/'d'/' '/; $warning = $warn * 24 * 60 * 60;}
					if ($o_warn =~ 'h') { $warn =~ tr/'h'/' '/; $warning = $warn * 60 * 60; }
					if ($o_crit =~ 'y') { $crit =~ tr/'y'/' '/; $critical = $crit * 364 * 24 * 60 * 60; }
					if ($o_crit =~ 'd') { $crit =~ tr/'d'/' '/; $critical = $crit * 24 * 60 * 60; }
					if ($o_crit =~ 'h') { $crit =~ tr/'h'/' '/; $critical = $crit * 60 * 60; }
					my $warningtimestamp = $ExpDateTS - $warning;
					my $criticaltimestamp = $ExpDateTS - $critical;
					if ( $warningtimestamp <= time ) {
						if ( $criticaltimestamp <= time ) {
							++$countcritical;
							$output = $output."Critical - Subscription expiration date ".$ADVFSubs[1].'. Alert from '.$o_crit.' before ('.localtime($criticaltimestamp).'),';
						} else {
							++$countwarning;
							$output = $output."Warning - Subscription expiration date ".$ADVFSubs[1].'. Alert from '.$o_warn.' before ('.localtime($warningtimestamp).'),';
						}
					} else {
						$output = $output."Subscription expire on ".$ADVFSubs[1].' alert will comming on '.localtime($warningtimestamp).',';
					}
				}
				case 'UPDATES' {
					init_snmp_session();
					my $rsStatus = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFUpdateStatus'}]);
					my $rsDesc = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFUpdateDesc'}]);
					if ( $$rsStatus{$ADVFOID{'ADVFUpdateStatus'}} eq 'new' || $$rsStatus{$ADVFOID{'ADVFUpdateStatus'}} eq 'up-to-date' ) {
						$output = 'Ok - '.$$rsStatus{$ADVFOID{'ADVFUpdateStatus'}}.' '.$$rsDesc{$ADVFOID{'ADVFUpdateDesc'}}."\n";
					} elsif ( $$rsStatus{$ADVFOID{'ADVFUpdateStatus'}} eq 'unknown' ) {
						$output = $$rsStatus{$ADVFOID{'ADVFUpdateStatus'}}.' '.$$rsDesc{$ADVFOID{'ADVFUpdateDesc'}}."\n";
						print $output;
						exit $reverse_exit_code{Unknown};
					} elsif ( $$rsStatus{$ADVFOID{'ADVFUpdateStatus'}} eq 'degrade' ) {
						++$countwarning;
						$output = 'Warning - '.$$rsStatus{$ADVFOID{'ADVFUpdateStatus'}}.' '.$$rsDesc{$ADVFOID{'ADVFUpdateDesc'}}."\n";
					} else {
						++$countcritical;
						$output = 'Critical - '.$$rsStatus{$ADVFOID{'ADVFUpdateStatus'}}.' '.$$rsDesc{$ADVFOID{'ADVFUpdateDesc'}}."\n";
					}
				}
				case 'RADSTATUS' {
					init_snmp_session();
					my $radStatus	= $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFRADStatus'}]);
					my $radDesc		= $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFRADDesc'}]);
					if ( $$radStatus{$ADVFOID{'ADVFRADStatus'}} ne $log_serv_conn_state{'Ok'} ) {
						++$countcritical;
						$output = 'Critical - RAD Status isn\'t OK with message '.$$radDesc{$ADVFOID{'ADVFRADDesc'}}.',';
					} else {
						$output = $$radDesc{$ADVFOID{'ADVFRADDesc'}}.',';
					}
				}
				else { print "Subtype not recognized \n"; type_help(); }
			}
		} else {
			init_snmp_session();
			my @ADVFStatus;
			my $result;
			$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFStatusCode'}]);
			push (@ADVFStatus, $$result{$ADVFOID{'ADVFStatusCode'}});
			$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFStatusMsg'}]);
			push (@ADVFStatus, $$result{$ADVFOID{'ADVFStatusMsg'}});
			$result = $snmpsession->get_request(-varbindlist => [$ADVFOID{'ADVFStatusLongMsg'}]);
			push (@ADVFStatus, $$result{$ADVFOID{'ADVFStatusLongMsg'}});
			if ( $ADVFStatus[0] != $log_serv_conn_state{'Ok'} ) {
				++$countcritical;
				$output = 'Critical - Application Control is in state '.$rev_log_serv_conn_state{$ADVFStatus[0]}.' state with message : '.$ADVFStatus[1].','.$ADVFStatus[2].',';
			} else {
				$output = 'Application Control is in state '.$rev_log_serv_conn_state{$ADVFStatus[0]}.',';
			}
		}
	}
	case 'ANTI-BOT' {
		if ( defined ($o_subtype) ) {
			switch ($o_subtype) {
				case 'SUBSCRIPTION' {
					init_snmp_session();
					check_alert_value();
					my @ABSubs;
					my $result;
					$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABSubsStatus'}]);
					push (@ABSubs, $$result{$ABOID{'ABSubsStatus'}});
					$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABSubsExpDate'}]);
					my $ExpDateTS = str2time($$result{$ABOID{'ABSubsExpDate'}});
					push (@ABSubs, $$result{$ABOID{'ABSubsExpDate'}});
					$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABSubsDesc'}]);
					push (@ABSubs, $$result{$ABOID{'ABSubsDesc'}});
					if ( $ABSubs[0] ne 'valid' ) {
						++$countcritical;
						$output = 'Anti-Bot Subscription is '.$ABSubs[0].' '.$ABSubs[2].',';
					} else {
						$output = 'Anti-Bot Subscription is '.$ABSubs[0].',';
					}
					my ($warning,$critical);
					my $warn = $o_warn;
					my $crit = $o_crit;
					if ($o_warn =~ 'y') { $warn =~ tr/'y'/' '/; $warning = $warn * 364 * 24 * 60 * 60;}
					if ($o_warn =~ 'd') { $warn =~ tr/'d'/' '/; $warning = $warn * 24 * 60 * 60;}
					if ($o_warn =~ 'h') { $warn =~ tr/'h'/' '/; $warning = $warn * 60 * 60; }
					if ($o_crit =~ 'y') { $crit =~ tr/'y'/' '/; $critical = $crit * 364 * 24 * 60 * 60; }
					if ($o_crit =~ 'd') { $crit =~ tr/'d'/' '/; $critical = $crit * 24 * 60 * 60; }
					if ($o_crit =~ 'h') { $crit =~ tr/'h'/' '/; $critical = $crit * 60 * 60; }
					my $warningtimestamp = $ExpDateTS - $warning;
					my $criticaltimestamp = $ExpDateTS - $critical;
					if ( $warningtimestamp <= time ) {
						if ( $criticaltimestamp <= time ) {
							++$countcritical;
							$output = $output."Critical - Subscription expiration date ".$ABSubs[1].'. Alert from '.$o_crit.' before ('.localtime($criticaltimestamp).'),';
						} else {
							++$countwarning;
							$output = $output."Warning - Subscription expiration date ".$ABSubs[1].'. Alert from '.$o_warn.' before ('.localtime($warningtimestamp).'),';
						}
					} else {
						$output = $output."Subscription expire on ".$ABSubs[1].' alert will comming on '.localtime($warningtimestamp).',';
					}
				}
				case 'UPDATES' {
					init_snmp_session();
					my $rsStatus = $snmpsession->get_request(-varbindlist => [$ABOID{'ABUpdateStatus'}]);
					my $rsDesc = $snmpsession->get_request(-varbindlist => [$ABOID{'ABUpdateDesc'}]);
					if ( $$rsStatus{$ABOID{'ABUpdateStatus'}} eq 'new' || $$rsStatus{$ABOID{'ABUpdateStatus'}} eq 'up-to-date' ) {
						$output = 'Ok - '.$$rsStatus{$ABOID{'ABUpdateStatus'}}.' '.$$rsDesc{$ABOID{'ABUpdateDesc'}}."\n";
					} elsif ( $$rsStatus{$ABOID{'ABUpdateStatus'}} eq 'unknown' ) {
						$output = $$rsStatus{$ABOID{'ABUpdateStatus'}}.' '.$$rsDesc{$ABOID{'ABUpdateDesc'}}."\n";
						print $output;
						exit $reverse_exit_code{Unknown};
					} elsif ( $$rsStatus{$ABOID{'ABUpdateStatus'}} eq 'degrade' ) {
						++$countwarning;
						$output = 'Warning - '.$$rsStatus{$ABOID{'ABUpdateStatus'}}.' '.$$rsDesc{$ABOID{'ABUpdateDesc'}}."\n";
					} else {
						++$countcritical;
						$output = 'Critical - '.$$rsStatus{$ABOID{'ABUpdateStatus'}}.' '.$$rsDesc{$ABOID{'ABUpdateDesc'}}."\n";
					}
				}
				else { print "Subtype not recognized \n"; type_help(); }
			}
		} else {
			init_snmp_session();
			my @ABStatus;
			my $result;
			$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABStatusCode'}]);
			push (@ABStatus, $$result{$ABOID{'ABStatusCode'}});
			$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABStatusMsg'}]);
			push (@ABStatus, $$result{$ABOID{'ABStatusMsg'}});
			$result = $snmpsession->get_request(-varbindlist => [$ABOID{'ABStatusLongMsg'}]);
			push (@ABStatus, $$result{$ABOID{'ABStatusLongMsg'}});
			if ( $ABStatus[0] != $log_serv_conn_state{'Ok'} ) {
				++$countcritical;
				$output = 'Critical - Anti-Bot is in state '.$rev_log_serv_conn_state{$ABStatus[0]}.' state with message : '.$ABStatus[1].','.$ABStatus[2].',';
			} else {
				$output = 'Anti-Bot is in state '.$rev_log_serv_conn_state{$ABStatus[0]}.',';
			}
		}
	}
	case 'TUNNEL' {
		init_snmp_session();
		my @TunIPID;
		my $valcount=0;
		my $rsTUNEntries = $snmpsession->get_entries(-columns => [$TUNOID{'TUNTable'}]);

		foreach my $val (values($rsTUNEntries)) {
			push(@TunIPID,$val);
			my $rsTUNName		= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNName'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNState		= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNCommunity	= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNCommunity'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNIFace		= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNIFace'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNSrcIP		= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNSrcIP'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNLnkPrio	= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNLnkPrio'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNProbState	= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNProbState'}.'.'.$TunIPID[$valcount].'.0']);
			my $rsTUNPeerType	= $snmpsession->get_request(-varbindlist => [$TUNOID{'TUNPeerType'}.'.'.$TunIPID[$valcount].'.0']);

			if ( $$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'} eq $rev_tun_state{'down'} || $$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'} eq $rev_tun_state{'destroy'}) {
				++$countcritical;
				$output = $output.'Critical - Tunnel '.$$rsTUNName{$TUNOID{'TUNName'}.'.'.$TunIPID[$valcount].'.0'}.' is in state '.$tun_state{$$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'}}.',';
				$output = $output.'Community '.$$rsTUNCommunity{$TUNOID{'TUNCommunity'}.'.'.$TunIPID[$valcount].'.0'}.',';
				$output = $output.'Interface '.$$rsTUNIFace{$TUNOID{'TUNIFace'}.'.'.$TunIPID[$valcount].'.0'}.',' if ( $$rsTUNIFace{$TUNOID{'TUNIFace'}.'.'.$TunIPID[$valcount].'.0'} );
				$output = $output.'Source IP '.$$rsTUNSrcIP{$TUNOID{'TUNSrcIP'}.'.'.$TunIPID[$valcount].'.0'}.',';
				$output = $output.'Link Priority '.$tun_priority{$$rsTUNLnkPrio{$TUNOID{'TUNLnkPrio'}.'.'.$TunIPID[$valcount].'.0'}}.',';
				$output = $output.'Probing Status '.$tun_probing{$$rsTUNProbState{$TUNOID{'TUNProbState'}.'.'.$TunIPID[$valcount].'.0'}}.',';
				$output = $output.'Peer Type '.$tun_peer_type{$$rsTUNPeerType{$TUNOID{'TUNPeerType'}.'.'.$TunIPID[$valcount].'.0'}}.',';
			} elsif ( $$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'} eq $rev_tun_state{'phase1'} || $$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'} eq $rev_tun_state{'init'} ) {
				++$countwarning;
				$output = $output.'Warning - Tunnel '.$$rsTUNName{$TUNOID{'TUNName'}.'.'.$TunIPID[$valcount].'.0'}.' with source IP '.$$rsTUNSrcIP{$TUNOID{'TUNSrcIP'}.'.'.$TunIPID[$valcount].'.0'}.' operating in state '.$tun_state{$$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'}}.',';
			} else {
				$output = $output.'Tunnel '.$$rsTUNName{$TUNOID{'TUNName'}.'.'.$TunIPID[$valcount].'.0'}.' with source IP '.$$rsTUNSrcIP{$TUNOID{'TUNSrcIP'}.'.'.$TunIPID[$valcount].'.0'}.' operating in state '.$tun_state{$$rsTUNState{$TUNOID{'TUNState'}.'.'.$TunIPID[$valcount].'.0'}}.',';
			}

			++$valcount;
		}
	} else { $output = 'Type not recognized.'; type_help(); }
}
$snmpsession->close;
$output =~ tr/,/\n/;
$perf =~ tr/' '/'_'/;
$outputlines = $output =~ tr/\n//;
get_perf_data() if (defined $o_perf && $o_perf ne '');
output_display();
