#!/usr/bin/perl 
#
# Copyright (c) 2009 Dmitry Smirnov <dsmirnov@bemagold.ru>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
##########################################################
#
# Perfdata returned as follows:
#
# RIVERBED:HEALTH=<string>;OUTLAN=<number>;OUTWAN=<number>;INLAN=<number>;INWAN=<number>
#
#
use strict;
use Error qw(:try);
use Getopt::Std;
use Net::SNMP;

use constant RB_OID       => '1.3.6.1.4.1.17163.1.1';
use constant SNMP_TIMEOUT => 5;
use constant PEER_BULK	  => 5;
use constant HEALTH_OK	  => 10000;

sub main {

    my $status = ['OK', 'WARNING', 'ERROR', 'UNKNOWN'];
    my $code   = 3;
    my $text   = "";
    
    my ($snmp, $error, $param);
    
    @Error::SNMP::ISA = qw(Error::Simple);
    @Error::MissingParam::ISA = qw(Error::Simple);

	$param = getParam();

	($snmp, $error) = Net::SNMP->session(
	    -community => $param->{'community'} || 'public',
    	    -hostname  => $param->{'host'},
	    -version   => 2,
	    -timeout   => SNMP_TIMEOUT,
	);

	if ($error){
		print("erreur d'aguments!\n");
		exit (1);
	}
    
	($code, $text) = getRiverbedStatus($snmp, $param);
	
	if ($snmp){
		$snmp->close()
	}
    print $status->[$code] . ": $text\n";
    exit($code);
}

sub getParam {
    my %opts;

    getopts('H:c:p:', \%opts);
    
    #throw Error::MissingParam()
	#unless ($opts{'H'});

   {host      => $opts{'H'}, 
    community => $opts{'c'} || 'public', 
    peers     => $opts{'p'}};

}

sub getSNMPVars {
    my ($snmp, $vars) = @_;
    my $vals = {};

    my $varsHash = {map {$vars->{$_} => $_} keys %$vars};

    #throw Error::SNMP($snmp->error)
	#unless (defined($snmp->get_request(-varbindlist => [values %$vars],)));

    foreach ($snmp->var_bind_names()) {
	$vals->{$varsHash->{$_}} = 
	    $snmp->var_bind_list()->{$_};
    }	    

    $vals;
}

sub getSNMPTables {
    my ($snmp, $tables, $breakFunc) = @_;
    my ($baseOid, $idx);

    my $tableVals = {map {$tables->{$_} => {'into' => $_, 'idx' => 0, 'done' => 0}} keys %$tables};
    my $data      = {map {$_ => []} keys %$tables};
    
    while (1) {

	my @oids = map {"$_.$tableVals->{$_}->{'idx'}"} 
		       (grep {!$tableVals->{$_}->{'done'}} 
		  	keys %$tableVals);

	#throw Error::SNMP($snmp->error)
	    #unless (defined($snmp->get_bulk_request(-varbindlist     => \@oids,-maxrepetitions  => PEER_BULK,)));

	foreach (keys %$tableVals) {
	    $tableVals->{$_}->{'done'} = 1;
	}

	foreach ($snmp->var_bind_names()) {

	    ($baseOid, $idx) = (/^(.+?)\.(\d+)$/);

	    next unless ($tableVals->{$baseOid});
	    
	    $tableVals->{$baseOid}->{'done'} = 0;
	    $tableVals->{$baseOid}->{'idx'}  = $idx
		unless ($tableVals->{$baseOid}->{'idx'} > $idx);
	    
	    push(@{$data->{$tableVals->{$baseOid}->{'into'}}}, 
		 $snmp->var_bind_list()->{$_});
	}
	
	# Break if lists exhausted or the break function fires 
	last if (scalar(grep {$tableVals->{$_}->{'done'}} keys %$tableVals) ==
		 scalar(keys %$tableVals));
		 
	last if ($breakFunc &&
		 $breakFunc->($data));
    }
    
    $data;
}

sub getRiverbedStatusHealth {
    my ($snmp, $param) = @_;

    my $vals = getSNMPVars($snmp, {
	'outlan'     => RB_OID . '.5.3.1.1.0',
	'outwan'     => RB_OID . '.5.3.1.2.0',
	'inlan'      => RB_OID . '.5.3.1.3.0',
	'inwan'      => RB_OID . '.5.3.1.4.0',
	'healthenum' => RB_OID . '.2.7.0',
	'healthstr'  => RB_OID . '.2.2.0',
	'model'      => RB_OID . '.1.1.0',
    });
    
    return ($vals->{'healthenum'} != HEALTH_OK ? 2 : 0,
	    "Riverbed $vals->{'model'} status: $vals->{'healthstr'}",
	    "HEALTH=$vals->{'healthstr'};OUTLAN=$vals->{'outlan'};OUTWAN=$vals->{'outwan'};" .
	    "INLAN=$vals->{'inlan'};INWAN=$vals->{'inwan'};");
}

sub getRiverbedStatusPeers {
    my ($snmp, $param) = @_;

    my $havePeers = $param->{'peers'} ? {map {$_ => 0} (split(/\s*,\s*/,lc($param->{'peers'})))}
				      : {};

    return (0, '', '') 
	unless scalar(keys %$havePeers);
				      
    my $isAllPeersFound = sub {
	my $data = shift;

	my ($ips, $hosts) = ($data->{'peers_ip'}   || [],
			     $data->{'peers_host'} || []);
			     
	my $reverseIP = sub {
	    /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
	    ($_, "$4.$3.$2.$1");
	};
			     
	foreach my $peer (map {$reverseIP->($_)} @$ips, @$hosts) {
	    $havePeers->{lc($peer)} = 1
		if (exists $havePeers->{lc($peer)});
	}

        scalar(grep {$havePeers->{$_} == 0} keys %$havePeers) == 0;
    };

    my $data = getSNMPTables($snmp, {
	'peers_ip'   => RB_OID . '.2.6.1.1.2',
	'peers_host' => RB_OID . '.2.6.1.1.4',
    }, $isAllPeersFound);

    my $all = $isAllPeersFound->($data);
    my @peers = $all ? keys %$havePeers 
		     : grep {$havePeers->{$_} == 0} keys %$havePeers;
    my $peers  = join(', ', @peers);
    my $plural = scalar(@peers) > 1 ? 's' : '';

    return ($all ? 0 : 2,
	    "peer${plural} $peers" . ($all ? " connected" : " MISSING"),
	    '');    
}

sub getRiverbedStatus {
    my ($snmp, $param) = @_;
    my ($code, $output, $perf);
    my (@outputAll, @perfAll);

    # Break on first error to save traffic.
    foreach my $func (\&getRiverbedStatusHealth, \&getRiverbedStatusPeers) {
	($code, $output, $perf) = $func->($snmp, $param);

	push @outputAll, $output
	    if ($output);
	    
	push @perfAll, $perf
	    if ($perf);

	last if ($code);
    }

    return ($code, join(', ', @outputAll) . '|RIVERBED:' .
		   join(', ', @perfAll));
}

&main();
