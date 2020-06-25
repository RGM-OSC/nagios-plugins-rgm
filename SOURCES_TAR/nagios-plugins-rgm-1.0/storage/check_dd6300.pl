#!/usr/bin/perl -w
######################### check_snmp_name.pl #################
my $Version='0.1';
my $check_name='check_dd6300.pl';
# Date : Apr 1 2019
# Author  : Vincent FRICOU (vincent at fricouv dot eu)
# Nagios check for Dell/EMC Datadomain 6300.
################################################################

use POSIX qw(locale_h);
use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;
use Number::Format qw(:subs);
use Date::Parse;
use Data::Dumper;
use List::MoreUtils qw(uniq);


### Global vars declaration

my ($o_host,$o_community,$o_port,$o_help,$o_timeout,$o_warn,$o_crit,$o_type,$o_perf,$o_expect,$o_subtype,$o_iface);
my %reverse_exit_code = (
	'Ok'=>0,
	'Warning'=>1,
	'Critical'=>2,
	'Unknown'=>3,
);

my $output='';
my $perf='';
my $outputlines;
my $countcritical=0;
my $countwarning=0;
my ($snmpsession,$snmperror);

### Custom hash

my %pow_stat_code = (
    0           =>  'absent',
    1           =>  'ok',
    2           =>  'failed',
    3           =>  'faulty',
    4           =>  'acnone',
    99          =>  'unknown',
);

my %r_pow_stat_code = (
    'absent'    =>  0,
    'ok'        =>  1,
    'failed'    =>  2,
    'faulty'    =>  3,
    'acnone'    =>  4,
    'anknown'   =>  99,
);

my %temp_stat_code = (
    0                   =>  'failed',
    1                   =>  'ok',
    2                   =>  'notfound',
    3                   =>  'overheatWarning',
    4                   =>  'overheatCritical',
);

my %r_temp_stat_code = (
    'failed'            =>  0,
    'ok'                =>  1,
    'notfound'          =>  2,
    'overheatWarning'   =>  3,
    'overheatCritical'  =>  4,
);

my %fan_stat_code = (
    0                   =>  'notfound',
    1                   =>  'ok',
    2                   =>  'fail',
);

my %r_fan_stat_code = (
    'notfound'          =>  0,
    'ok'                =>  1,
    'fail'              =>  2,
);

my %rep_state_code = (
    1                   =>  'initializing',
    2                   =>  'normal',
    3                   =>  'recovering',
    4                   =>  'uninitialized',
);

my %r_rep_state_code = (
    'initializing'      =>  1,
    'normal'            =>  2,
    'recovering'        =>  3,
    'uninitialized'     =>  4,
);

my %rep_status_code = (
    1                   =>  'connected',
    2                   =>  'disconnected',
    3                   =>  'migrating',
    4                   =>  'suspended',
    5                   =>  'neverConnected',
    6                   =>  'idle',
);

my %r_rep_status_code = (
    'connected'         =>  1,
    'disconnected'      =>  2,
    'migrating'         =>  3,
    'suspended'         =>  4,
    'neverConnected'    =>  5,
    'idle'              =>  6,
);

my %disk_state_code = (
    1                   =>  'ok',
    2                   =>  'unknown',
    3                   =>  'absent',
    4                   =>  'failed',
    5                   =>  'spare',
    6                   =>  'available',
    8                   =>  'raidReconstruction',
    9                   =>  'copyReconstruction',
    10                  =>  'system',
);

my %r_disk_state_code = (
    'ok'                =>  1,
    'unknown'           =>  2,
    'absent'            =>  3,
    'failed'            =>  4,
    'spare'             =>  5,
    'available'         =>  6,
    'raidReconstruction'=>  8,
    'copyReconstruction'=>  9,
    'system'            =>  10,
);


### OID vars declaration

my %OIDAlarms = (
    'table'                 =>  '.1.3.6.1.4.1.19746.1.4.1.1.1',
    'timestamp'             =>	'.1.3.6.1.4.1.19746.1.4.1.1.1.2',
    'description'           =>	'.1.3.6.1.4.1.19746.1.4.1.1.1.3',
    'severity'              =>  '.1.3.6.1.4.1.19746.1.4.1.1.1.4',
);

my %OIDPower = (
    'enclosure-index'       =>  '.1.3.6.1.4.1.19746.1.1.1.1.1.1.1',
    'psu-index'             =>  '.1.3.6.1.4.1.19746.1.1.1.1.1.1.2',
    'psu-desc'              =>  '.1.3.6.1.4.1.19746.1.1.1.1.1.1.3',
    'psu-state'             =>  '.1.3.6.1.4.1.19746.1.1.1.1.1.1.4',
);

my %OIDTemp = (
    'enclosure-index'       =>  '.1.3.6.1.4.1.19746.1.1.2.1.1.1.1',
    'temp-index'            =>  '.1.3.6.1.4.1.19746.1.1.2.1.1.1.2',
    'temp-desc'             =>  '.1.3.6.1.4.1.19746.1.1.2.1.1.1.4',
    'temp-value'            =>  '.1.3.6.1.4.1.19746.1.1.2.1.1.1.5',
    'temp-state'            =>  '.1.3.6.1.4.1.19746.1.1.2.1.1.1.6',
);

my %OIDFan = (
    'enclosure-index'       =>  '.1.3.6.1.4.1.19746.1.1.3.1.1.1.1',
    'fan-index'             =>  '.1.3.6.1.4.1.19746.1.1.3.1.1.1.2',
    'fan-desc'              =>  '.1.3.6.1.4.1.19746.1.1.3.1.1.1.4',
    'fan-state'             =>  '.1.3.6.1.4.1.19746.1.1.3.1.1.1.6',
);

my %OIDFileSystem = (
    'name'                  =>  '.1.3.6.1.4.1.19746.1.3.2.1.1.3',
    'pctused'               =>  '.1.3.6.1.4.1.19746.1.3.2.1.1.7',
    'size'                  =>  '.1.3.6.1.4.1.19746.1.3.2.1.1.4',
);

my %OIDCompression = (
    'period'                =>  '.1.3.6.1.4.1.19746.1.3.3.1.1.2',
    'presize'               =>  '.1.3.6.1.4.1.19746.1.3.3.1.1.5',
    'postsize'              =>  '.1.3.6.1.4.1.19746.1.3.3.1.1.6',
    'totalfact'             =>  '.1.3.6.1.4.1.19746.1.3.3.1.1.9',
    'pctreductfact'         =>  '.1.3.6.1.4.1.19746.1.3.3.1.1.11',
);

my %OIDReplication = (
    'context'               =>  '.1.3.6.1.4.1.19746.1.8.1.1.1.1',
    'state'                 =>  '.1.3.6.1.4.1.19746.1.8.1.1.1.3',
    'status'                =>  '.1.3.6.1.4.1.19746.1.8.1.1.1.4',
    'source'                =>  '.1.3.6.1.4.1.19746.1.8.1.1.1.7',
    'destination'           =>  '.1.3.6.1.4.1.19746.1.8.1.1.1.7',
);

my %OIDDisk = (
    'enclosure-index'       =>  '.1.3.6.1.4.1.19746.1.6.1.1.1.1',
    'disk-index'            =>  '.1.3.6.1.4.1.19746.1.6.1.1.1.2',
    'disk-state'            =>  '.1.3.6.1.4.1.19746.1.6.1.1.1.8',
);

### Function declaration

sub usage {
   print "\nSNMP '.$check_name.' for Nagios. Version ",$Version,"\n";
   print "GPL Licence - Vincent FRICOU\n\n";
   print <<EOT;
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v2 protocol)
-f, --perfparse
   perfparse output
-w, --warning=<value>
   Warning value
-c, --critical=<value>
   Critical value
-t, --type=CHECK TYPE
EOT
   type_help();
   exit $reverse_exit_code{Unknown};
}

sub type_help {
print "- alarms : Check current alams and auto set nagios error code according to alert severity.
- power : Check all power supplies viewed and set state according to status criticity.
- temp : Check temperature sensors values. Threshold provided by device.
- diskspace : Check disk space occupation. Provide warning and critical value to filling percentage.
- dedfactord : Check deduplication/compression value for last 24 hours. Provide warning and critical value for minimal deduplication ratio.
- dedfactorw : Check deduplication/compression value for last 7 days. Provide warning and critical value for minimal deduplication ratio.
- fan : Check all fan units viewed and set state according to status criticity.
- replication : Check replication targets status.
- diskstate : Check disks status.
";
	exit $reverse_exit_code{Unknown};
}
sub get_options () {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'h|help'			=>	\$o_help,
		'H|hostname:s'	    =>	\$o_host,
		'C|community:s'	    =>	\$o_community,
		'f|perfparse'		=>	\$o_perf,
		'w|warning:s'		=>	\$o_warn,
		'c|critical:s'	    =>	\$o_crit,
		't|type:s'		    =>	\$o_type,
	);

	usage() if (defined ($o_help));
	usage() if (! defined ($o_host) && ! defined ($o_community) && ! defined ($o_type));
	type_help() if (! defined ($o_type));
	$o_type=uc($o_type);
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
    check_dd_model();
}

sub check_alert_value () {
	if (! defined ($o_warn)) { print "Warning value missing, please use -w option.\n"; exit $reverse_exit_code{Unknown}; }
	if (! defined ($o_crit)) { print "Critical value missing, please use -c option.\n"; exit $reverse_exit_code{Unknown}; }
}
sub check_subtype () {
	if (! defined ($o_subtype)) { print "No subtype defined, please use -s option.\n"; exit $reverse_exit_code{Unknown}; }
}

sub dedupcalc {
    init_snmp_session();
    my $dedIdx          =   shift;
    my $warn            =   shift;
    my $crit            =   shift;
    my $cwarn           =   0;
    my $ccrit           =   0;
    my ($dout,$dperf);

    my $rPeriod         =   $snmpsession->get_request(-varbindlist => [$OIDCompression{'period'}.'.'.$dedIdx]);
    my $rPreSize        =   $snmpsession->get_request(-varbindlist => [$OIDCompression{'presize'}.'.'.$dedIdx]);
    my $rPostSize       =   $snmpsession->get_request(-varbindlist => [$OIDCompression{'postsize'}.'.'.$dedIdx]);
    my $rTotalFact      =   $snmpsession->get_request(-varbindlist => [$OIDCompression{'totalfact'}.'.'.$dedIdx]);
    my $rReductFact     =   $snmpsession->get_request(-varbindlist => [$OIDCompression{'pctreductfact'}.'.'.$dedIdx]);

    my $PreCompSizeTB   =   $$rPreSize{$OIDCompression{'presize'}.'.'.$dedIdx} / 1024;
    my $PostCompSizeTB  =   $$rPostSize{$OIDCompression{'postsize'}.'.'.$dedIdx} / 1024;
    my $Period          =   $$rPeriod{$OIDCompression{'period'}.'.'.$dedIdx};
    $Period             =~  s/Last//g ;

    if ( $$rTotalFact{$OIDCompression{'totalfact'}.'.'.$dedIdx} <= $warn ) {
        if ( $$rTotalFact{$OIDCompression{'totalfact'}.'.'.$dedIdx} <= $crit ) {
            ++$ccrit;
        } else {
            ++$cwarn;
        }
    }

    $dout = 'Dedup factor : '.$$rTotalFact{$OIDCompression{'totalfact'}.'.'.$dedIdx}.' (data reduction '.$$rReductFact{$OIDCompression{'pctreductfact'}.'.'.$dedIdx}.'%)'.',';
    $dout = $dout.'Precompression size '.$PreCompSizeTB.'TB. Postcompression size '.$PostCompSizeTB.'TB.,';

    $dperf = 'dedup_factor'.$Period.'='.$$rTotalFact{$OIDCompression{'totalfact'}.'.'.$dedIdx}.';'.$warn.';'.$crit."\n";
    $dperf = $dperf.'reduction_pct'.$Period.'='.$$rReductFact{$OIDCompression{'pctreductfact'}.'.'.$dedIdx}.";;\n";
    $dperf = $dperf.'precomp_size'.$Period.'='.$PreCompSizeTB.";;\n";
    $dperf = $dperf.'dedup_factor'.$Period.'='.$PostCompSizeTB.";;\n";

    return ($dout,$cwarn,$ccrit,$dperf);
}

sub check_dd_model () {
    my $rVersion    =   $snmpsession->get_request(-varbindlist => ['.1.3.6.1.4.1.19746.1.13.1.4.0']);
    if ($$rVersion{'.1.3.6.1.4.1.19746.1.13.1.4.0'} ne 'DD6300') {
        print "Data domain model is not DD6300 (".$$rVersion{'.1.3.6.1.4.1.19746.1.13.1.4.0'}."). Check will not correctly run.\n";
        $snmpsession->close;
   		exit $reverse_exit_code{Unknown};
    }
}

### Main
get_options();

switch ($o_type) {
	case 'ALARMS' {
        init_snmp_session();
        my $result  =   $snmpsession->get_table(-baseoid => $OIDAlarms{'table'});

        if ( ! defined ($result) ) {
            $output = $output.'No alerts found,';
        } else {
            my $alTS    =   $snmpsession->get_entries(-columns => [$OIDAlarms{'timestamp'}]);
            my $alDesc  =   $snmpsession->get_entries(-columns => [$OIDAlarms{'description'}]);
            my $alSev   =   $snmpsession->get_entries(-columns => [$OIDAlarms{'severity'}]);
            my @alIdx;
            my $i      =   0;
            foreach my $idx (keys %$alDesc) {
                my @tId = split /$OIDAlarms{'description'}./, $idx;
                $alIdx[$i] = $tId[1];
                ++$i;
            }
            foreach my $aid (@alIdx) {
                my $alTime          =   $$alTS{$OIDAlarms{'timestamp'}.'.'.$aid};
                my $alDescription   =   $$alDesc{$OIDAlarms{'description'}.'.'.$aid};
                my $alSeverity      =   $$alSev{$OIDAlarms{'severity'}.'.'.$aid};

                ++$countwarning if ( $alSeverity eq 'WARNING' );
                ++$countcritical if ( $alSeverity eq 'CRITICAL' );

                $output = $output.$alTime.' '.$alSeverity.' '.$alDescription.',';
            }
        }
	}
    case 'POWER' {
        init_snmp_session();
        my $resEncIdx      =   $snmpsession->get_entries(-columns => [$OIDPower{'enclosure-index'}]);
        my @EncIdx;
        for my $EID (values %$resEncIdx) {
            push @EncIdx, $EID;
        }
		my @uniqEncIdx = uniq @EncIdx;

        foreach my $Encl (@uniqEncIdx) {
            my $psuIdx = $snmpsession->get_entries(-columns => [$OIDPower{'psu-index'}.'.'.$Encl]);

            foreach my $psu (values %$psuIdx) {
                my $psuDesc     =   $snmpsession->get_request (-varbindlist => [$OIDPower{'psu-desc'}.'.'.$Encl.'.'.$psu]);
                my $psuStatus   =   $snmpsession->get_request (-varbindlist => [$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu]);

                if ( $$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu} == $r_pow_stat_code{'failed'} || $$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu} == $r_pow_stat_code{'acnone'} ) {
                    ++$countcritical;
                    $output = $output.'Enclosure '.$Encl.' PSU : '.$$psuDesc{$OIDPower{'psu-desc'}.'.'.$Encl.'.'.$psu}.' is in state '.$pow_stat_code{$$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu}}.',';
                } elsif ( $$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu} == $r_pow_stat_code{'absent'} || $$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu} == $r_pow_stat_code{'faulty'} ) {
                    ++$countwarning;
                    $output = $output.'Enclosure '.$Encl.' PSU : '.$$psuDesc{$OIDPower{'psu-desc'}.'.'.$Encl.'.'.$psu}.' is in state '.$pow_stat_code{$$psuStatus{$OIDPower{'psu-state'}.'.'.$Encl.'.'.$psu}}.',';
                }
            }
        }
        $output = 'All PSU are ok,' if ($countcritical == 0 && $countwarning == 0);
    }
    case 'TEMP' {
        init_snmp_session();
        my $resEncIdx      =   $snmpsession->get_entries(-columns => [$OIDTemp{'enclosure-index'}]);
        my @EncIdx;
        for my $EID (values %$resEncIdx) {
            push @EncIdx, $EID;
        }
		my @uniqEncIdx = uniq @EncIdx;

        foreach my $Encl (@uniqEncIdx) {
            my $tempIdx = $snmpsession->get_entries(-columns => [$OIDTemp{'temp-index'}.'.'.$Encl]);

            foreach my $temp (values %$tempIdx) {
                my $tempDesc     =   $snmpsession->get_request (-varbindlist => [$OIDTemp{'temp-desc'}.'.'.$Encl.'.'.$temp]);
                my $tempValue    =   $snmpsession->get_request (-varbindlist => [$OIDTemp{'temp-value'}.'.'.$Encl.'.'.$temp]);
                my $tempStatus   =   $snmpsession->get_request (-varbindlist => [$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp]);

                if ( $$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp} == $r_temp_stat_code{'failed'} || $$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp} == $r_temp_stat_code{'overheatCritical'} ) {
                    ++$countcritical;
                    $output = $output.'Enclosure '.$Encl.' Temp : '.$$tempDesc{$OIDTemp{'temp-desc'}.'.'.$Encl.'.'.$temp}.' is in state '.$temp_stat_code{$$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp}}.' with value '.$$tempValue{$OIDTemp{'temp-value'}.'.'.$Encl.'.'.$temp}.',';
                } elsif ( $$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp} == $r_temp_stat_code{'notfound'} || $$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp} == $r_temp_stat_code{'overheatWarning'} ) {
                    ++$countwarning;
                    $output = $output.'Enclosure '.$Encl.' Temp : '.$$tempDesc{$OIDTemp{'temp-desc'}.'.'.$Encl.'.'.$temp}.' is in state '.$temp_stat_code{$$tempStatus{$OIDTemp{'temp-state'}.'.'.$Encl.'.'.$temp}}.' with value '.$$tempValue{$OIDTemp{'temp-value'}.'.'.$Encl.'.'.$temp}.',';
                }
                $perf = $perf.$$tempDesc{$OIDTemp{'temp-desc'}.'.'.$Encl.'.'.$temp}.'='.$$tempValue{$OIDTemp{'temp-value'}.'.'.$Encl.'.'.$temp}.";;\n";
            }
        }
        $output = 'All temperature sensors are ok,' if ($countcritical == 0 && $countwarning == 0);
    }
    case 'DISKSPACE' {
        init_snmp_session();
        check_alert_value();
        my $rDiskName   =   $snmpsession->get_entries (-columns => [$OIDFileSystem{'name'}]);
        my $rDiskSize   =   $snmpsession->get_entries (-columns => [$OIDFileSystem{'size'}]);
        my $rDiskUsed   =   $snmpsession->get_entries (-columns => [$OIDFileSystem{'pctused'}]);
        my @diskIdx;
        my $i           =   0;
        foreach my $idx (keys %$rDiskName) {
            my @tId = split /$OIDFileSystem{'name'}./, $idx;
            $diskIdx[$i] = $tId[1];
            ++$i;
        }
        foreach my $disk (@diskIdx) {
            if ( $$rDiskUsed{$OIDFileSystem{'pctused'}.'.'.$disk} >= $o_warn ) {
                if ( $$rDiskUsed{$OIDFileSystem{'pctused'}.'.'.$disk} >= $o_crit ) {
                    ++$countcritical;
                    $output = $output.'Disk '.$$rDiskName{$OIDFileSystem{'name'}.'.'.$disk}.' is at '.$$rDiskUsed{$OIDFileSystem{'pctused'}.'.'.$disk}.'% filled on size of '.$$rDiskSize{$OIDFileSystem{'size'}.'.'.$disk}.',';
                } else {
                    ++$countwarning;
                    $output = $output.'Disk '.$$rDiskName{$OIDFileSystem{'name'}.'.'.$disk}.' is at '.$$rDiskUsed{$OIDFileSystem{'pctused'}.'.'.$disk}.'% filled on size of '.$$rDiskSize{$OIDFileSystem{'size'}.'.'.$disk}.',';
                }
            }
            $perf = $perf.$$rDiskName{$OIDFileSystem{'name'}.'.'.$disk}.'='.$$rDiskUsed{$OIDFileSystem{'pctused'}.'.'.$disk}.';'.$o_warn.';'.$o_crit."\n";
        }
        $output = 'All volume are under alert threshold,' if ( $countwarning == 0 && $countcritical == 0);
    }
    case 'DEDFACTORD' {
        check_alert_value();
        ($output,$countwarning,$countcritical,$perf) = dedupcalc('1',$o_warn,$o_crit);
    }
    case 'DEDFACTORW' {
        check_alert_value();
        ($output,$countwarning,$countcritical,$perf) = dedupcalc('2',$o_warn,$o_crit);
    }
    case 'FAN' {
        init_snmp_session();
        my $resEncIdx      =   $snmpsession->get_entries(-columns => [$OIDFan{'enclosure-index'}]);
        my @EncIdx;
        for my $EID (values %$resEncIdx) {
            push @EncIdx, $EID;
        }
		my @uniqEncIdx = uniq @EncIdx;

        foreach my $Encl (@uniqEncIdx) {
            my $fanIdx = $snmpsession->get_entries(-columns => [$OIDFan{'fan-index'}.'.'.$Encl]);

            foreach my $fan (values %$fanIdx) {
                my $fanDesc     =   $snmpsession->get_request (-varbindlist => [$OIDFan{'fan-desc'}.'.'.$Encl.'.'.$fan]);
                my $fanStatus   =   $snmpsession->get_request (-varbindlist => [$OIDFan{'fan-state'}.'.'.$Encl.'.'.$fan]);

                if ( $$fanStatus{$OIDFan{'fan-state'}.'.'.$Encl.'.'.$fan} == $r_fan_stat_code{'fail'}) {
                    ++$countcritical;
                    $output = $output.'Enclosure '.$Encl.' fan : '.$$fanDesc{$OIDFan{'fan-desc'}.'.'.$Encl.'.'.$fan}.' is in state '.$fan_stat_code{$$fanStatus{$OIDFan{'fan-state'}.'.'.$Encl.'.'.$fan}}.',';
                } elsif ( $$fanStatus{$OIDFan{'fan-state'}.'.'.$Encl.'.'.$fan} == $r_fan_stat_code{'notfound'}) {
                    ++$countwarning;
                    $output = $output.'Enclosure '.$Encl.' fan : '.$$fanDesc{$OIDFan{'fan-desc'}.'.'.$Encl.'.'.$fan}.' is in state '.$fan_stat_code{$$fanStatus{$OIDFan{'fan-state'}.'.'.$Encl.'.'.$fan}}.',';
                }
            }
        }
        $output = 'All FAN are ok,' if ($countcritical == 0 && $countwarning == 0);
    }
	case 'REPLICATION' {
        init_snmp_session();
        my $rContext        =   $snmpsession->get_entries (-columns => [$OIDReplication{'context'}]);
        my $rState          =   $snmpsession->get_entries (-columns => [$OIDReplication{'state'}]);
        my $rStatus         =   $snmpsession->get_entries (-columns => [$OIDReplication{'status'}]);
        my $rSource         =   $snmpsession->get_entries (-columns => [$OIDReplication{'source'}]);
        my $rDestination    =   $snmpsession->get_entries (-columns => [$OIDReplication{'destination'}]);

        foreach my $Context (values %$rContext) {
            ++$countcritical if ( $$rState{$OIDReplication{'state'}.'.'.$Context} == $r_rep_state_code{'uninitialized'} );
            ++$countwarning if ( $$rState{$OIDReplication{'state'}.'.'.$Context} == $r_rep_state_code{'initializing'} || $$rState{$OIDReplication{'state'}.'.'.$Context} == $r_rep_state_code{'recovering'} );
            ++$countcritical if ( $$rStatus{$OIDReplication{'status'}.'.'.$Context} == $r_rep_status_code{'disconnected'} );
            ++$countwarning if ( $$rStatus{$OIDReplication{'status'}.'.'.$Context} == $r_rep_status_code{'migrating'} || $$rStatus{$OIDReplication{'status'}.'.'.$Context} == $r_rep_status_code{'neverConnected'} || $$rStatus{$OIDReplication{'status'}.'.'.$Context} == $r_rep_status_code{'suspended'});

            if ( $$rState{$OIDReplication{'state'}.'.'.$Context} == $r_rep_state_code{'initializing'} && $$rStatus{$OIDReplication{'status'}.'.'.$Context} == $r_rep_status_code{'connected'} ) {
                $output = $output."Currently replicating from ".$$rSource{$OIDReplication{'source'}.'.'.$Context}.' to '.$$rSource{$OIDReplication{'destination'}.'.'.$Context}.',';
            } else {
                $output = $output."Replication from ".$$rSource{$OIDReplication{'source'}.'.'.$Context}.' to '.$$rSource{$OIDReplication{'destination'}.'.'.$Context}.' is in state '.$rep_state_code{$$rState{$OIDReplication{'state'}.'.'.$Context}}.' with status '.$rep_status_code{$$rStatus{$OIDReplication{'status'}.'.'.$Context}}.',';
            }
        }

	}
    case 'DISKSTATE' {
        init_snmp_session();
        my $resEncIdx       =   $snmpsession->get_entries ( -columns => [$OIDDisk{'enclosure-index'}] );
        my @EncIdx;
        my $spareCount      =   0;
        for my $EID (values %$resEncIdx) {
            push @EncIdx, $EID;
        }
		my @uniqEncIdx = uniq @EncIdx;

        foreach my $enc (@uniqEncIdx) {
            my $rDiskIdx    =   $snmpsession->get_entries ( -columns => [$OIDDisk{'disk-index'}] );
            my @DiskIdx;
            for my $DID (values %$rDiskIdx) {
                push @DiskIdx, $DID;
            }
            my @uniqDiskIdx = uniq @DiskIdx;

            foreach my $disk (@uniqDiskIdx) {
                my $rDiskState  =   $snmpsession->get_request ( -varbindlist => [$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk] );
                if ( $$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk} ne 'noSuchInstance') {
                    if ( $$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk} == $r_disk_state_code{'failed'} ) {
                        ++$countcritical;
                        $output = $output.'Disk '.$enc.'-'.$disk.' is '.$disk_state_code{$$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk}};
                    }
                    if ( $$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk} == $r_disk_state_code{'raidReconstruction'} || $$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk} == $r_disk_state_code{'copyReconstruction'} ) {
                        ++$countwarning;
                        $output = $output.'Disk '.$enc.'-'.$disk.' is '.$disk_state_code{$$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk}};
                    }
                    ++$spareCount if ( $$rDiskState{$OIDDisk{'disk-state'}.'.'.$enc.'.'.$disk} == $r_disk_state_code{'spare'} );
                }
            }
        }

        $output = 'All disks are ok with '.$spareCount.' spare disk,' if ( $countwarning == 0 && $countcritical == 0);

    }

    else { $output = 'Type not recognized.'; }
}

$snmpsession->close if (defined $snmpsession);
$output =~ tr/,/\n/;
$perf =~ tr/' '/'_'/;
$outputlines = $output =~ tr/\n//;
get_perf_data() if (defined $o_perf && $o_perf ne '');
output_display();