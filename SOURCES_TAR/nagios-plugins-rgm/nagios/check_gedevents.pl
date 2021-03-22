#!/usr/bin/perl -w

my $Version='1.1-1';

use POSIX qw(locale_h); 
use strict;
use Net::SNMP;
use Getopt::Std;
use Getopt::Long;
use DBI;
use Data::Dumper;

setlocale(LC_CTYPE, "en_US");

my $countwarning=0;
my $countcritical=0;
my $output='';
my $dbh;
my $query;
my $id;
my $results;
my @occ;
my @equipment;
my @service;
my @state;
my @ip_address;
my @hostgroups;
my @servicegroups;
my $nb_object=0;
my $max_occ=0;
my $occ_crit;
my $occ_warn;
my $perf;
my $out_count=0;

sub help {
	print "Check GEDevents, $Version\n";
	print "GPL Licence, 2014 Vincent Fricou\n";
	print "Help :check_gedevents.pl
        -t host, service, servicegroups, hostgroups
        -s String to look for (ex: Cam%)
        -Pe Display perf data
        -Sc Complement search (ex: equipment like :colsan1a%:)
        -u mysql username
        -p mysql password
        -H Host target
        -we Warning maximum number of events
        -ce Critical maximum number of events
        -Wo Warning maximum number of occurence
        -Co Critical maximum number of occurence\n";
	exit 2;
}
sub outputdisplay () {
	$output =~ tr/,/\n/;
	if ($countcritical > 0){
		print "Critical : Click for detail \n\n$output";
		exit 2;
	} else {
		if ($countwarning > 0){
			print "Warning : Click for detail \n\n$output";
			exit 1;
		}
	}
	print $output;
	exit 0;
}

sub get_perf_data () {
$output=$output.'|'.$perf;
}
my ($type,$sqlstring,$o_perf,$sqlcomplement,$user,$password,$hostaddress,$evwarning,$evcritical,$occwarning,$occcritical,$help);
$sqlcomplement='' if (! $sqlcomplement);
GetOptions(
	"t=s"		=>	\$type,
	"s=s"		=>	\$sqlstring,
	"Pe=s"		=>	\$o_perf,
	"Sc=s"		=>	\$sqlcomplement,
	"u=s"		=>	\$user,
	"p=s"		=>	\$password,
	"H=s"		=>	\$hostaddress,
	"we=i"		=>	\$evwarning,
	"ce=i"		=>	\$evcritical,
	"Wo=i"		=>	\$occwarning,
	"Co=i"		=>	\$occcritical,
	"help=s"	=>	\$help,
);
$type=uc($type);
$sqlcomplement =~ s/:/'/g;
if (! $help && ! $type && ! $sqlstring && ! $user && ! $password && ! $hostaddress && ! $evwarning && ! $evcritical && ! $occwarning && ! $occcritical) { help(); }
if (defined ($help)) { 	help(); }
print "Type hasn't set. Please use -t.\n" if (! $type);
print "String to search hasn't set. Please use -s.\n" if (! $sqlstring);
print "Database user hasn't set. Please use -u.\n" if (! $user);
print "Database password hasn't set. Please use -p.\n" if (! $password);
print "Host address hasn't set. Please use -H.\n" if (! $hostaddress);

if (! defined($evwarning)  && ! defined($occwarning)) { print "You haven't set any warning value. Please use -we or -Wo.\n"; }
if (! defined($evcritical) && ! defined($occcritical)) { print "You haven't set any critical value. Please use -ce or -Co.\n"; }
if (! defined($occwarning)) { $occ_warn=0; } else { $occ_warn=$occwarning; }
if (! defined($occcritical)) { $occ_crit=0; } else { $occ_crit=$occcritical; }


if ($type eq "HOST") {
	$query = "SELECT id,occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments FROM nagios_queue_active WHERE equipment LIKE '$sqlstring' $sqlcomplement AND service LIKE 'HOST%' AND owner='' AND comments='' AND ( occ>$occ_crit OR occ>$occ_warn )";
}
if ($type eq "SERVICE") {
	$query = "SELECT id,occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments FROM nagios_queue_active WHERE service LIKE '$sqlstring' $sqlcomplement AND owner='' AND comments='' AND ( occ>$occ_crit OR occ>$occ_warn );";
}
if ($type eq "HOSTGROUPS") {
	$query = "SELECT id,occ,equipment,service,ip_address,hostgroups,servicegroups,owner,comments FROM nagios_queue_active WHERE hostgroups LIKE '$sqlstring' $sqlcomplement  AND owner='' AND comments='' AND ( occ>$occ_crit OR occ>$occ_warn )";
}
if ($type eq "SERVICEGROUPS") {
	$query = "SELECT id,occ,equipment,service,ip_address,hostgroups,servicegroups,owner,comments FROM nagios_queue_active WHERE servicegroups LIKE '$sqlstring' $sqlcomplement  AND owner='' AND comments='' AND ( occ>$occ_crit OR occ>$occ_warn )";
}

$dbh = DBI->connect("DBI:mysql:ged:$hostaddress", $user, $password);
$dbh->prepare($query);
$results = $dbh->selectall_hashref($query, 'id');
foreach my $id (keys %$results) {
	$occ[$nb_object]				= $results->{$id}->{occ};
	$equipment[$nb_object]			= $results->{$id}->{equipment};
	$service[$nb_object]			= $results->{$id}->{service};
	$ip_address[$nb_object]			= $results->{$id}->{ip_address};
	$hostgroups[$nb_object]			= $results->{$id}->{hostgroups};
	$servicegroups[$nb_object]		= $results->{$id}->{servicegroups};
	$state[$nb_object]				= $results->{$id}->{state};
	++$nb_object;
}

if (defined($occwarning) || defined($occcritical)){
	for (my $count=0; $count < $nb_object; ++$count){
		my $c_order=$count;
		my $cur_occ=$occ[$count];
		if ($cur_occ > $max_occ){ $max_occ=$cur_occ; }
		if ($state[$c_order] eq 2 || $state[$c_order] == 2) {
			if ($max_occ >= $occ_crit) {
				$countcritical=1;
				$output = "$output Equipemement $equipment[$c_order] ayant pour adresse $ip_address[$c_order] est en erreur depuis $occ[$c_order] cycle de notifications.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
				$output = "$output Le service $service[$c_order] de l’equipement $equipment[$c_order] ayant pour adresse $ip_address[$c_order] est en erreur depuis $occ[$c_order] cycle de notifications.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
			}
		} else {
			if ($max_occ >= $occ_warn && $countcritical < 1) {
				$countwarning=1;
				$output="$output Equipemement $equipment[$c_order] ayant pour adresse $ip_address[$c_order] est en erreur depuis $occ[$c_order] cycle de notifications.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
				$output="$output Le service $service[$c_order] de l'equipement $equipment[$c_order] ayant pour adresse $ip_address[$c_order] est en erreur depuis $occ[$c_order] cycle de notifications.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
			}
		}
		$out_count=$nb_object;
	}
	$perf=$o_perf."=".$out_count.";".$occwarning.";".$occcritical.',' if (defined($o_perf));
}

if (defined($evwarning) || defined($evcritical)) {
	for (my $count=0; $count < $nb_object; ++$count){
		if ($nb_object >= $evcritical) {
			$countcritical=1;
			my $c_order=$count - 1;
			$output="$output L'equipememt $equipment[$c_order] ayant pour adresse $ip_address[$c_order] a genere $occ[$c_order] evenements.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
			$output="$output Le service $service[$c_order] a genere $occ[$c_order] evenements.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
		} else {
			if ($nb_object >= $evwarning && $countcritical < 1) {
				$countwarning=1;
				my $c_order=$count - 1;
				$output="$output L'equipememt $equipment[$c_order] ayant pour adresse $ip_address[$c_order] a genere $occ[$c_order] evenements.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
				$output="$output Le service $service[$c_order] a genere $occ[$c_order] evenements.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
			}
		}
		$out_count=$nb_object;
	}
	$perf=$o_perf."=".$out_count.";".$evwarning.";".$evcritical.',' if (defined($o_perf));
}
$output="OK : Les evenements sans prise en charge concernant $sqlstring sont d'en volume et/ou d'un temps plus petit que les valeurs attendues.\n" if ($countcritical lt 1 && $countwarning lt 1);


get_perf_data () if (defined $o_perf);
outputdisplay ();
exit 0;
