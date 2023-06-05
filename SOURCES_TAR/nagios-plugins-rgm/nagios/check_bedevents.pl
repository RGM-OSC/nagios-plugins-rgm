#!/usr/bin/perl

my $version = '1.0.0';
my $author = 'Vincent Fricou <vfricou@fr.scc.com>';
my $licence = 'GPL Licence';
my $copyright = $licence . 'SCC 2023';

use POSIX qw(locale_h);
use strict;
use warnings FATAL => 'all';
use Getopt::Std;
use Getopt::Long;
use DBI;

# Constant definition
my $countwarning=0;
my $countcritical=0;
my $output='';
my ($perf,
    $pkt_dbh,
    $dbh,
    $query,
    $id,
    $results
);
my (@occ,
    @contract,
    @site,
    @equipment,
    @service,
    @state,
    @ip_address,
    @hostgroups,
    @servicegroups,
    $occ_crit,
    $occ_warn
);
my $nb_object=0;
my $max_occ=0;
my $out_count=0;
my ($type,
    $sqlstring,
    $o_perf,
    $sqlcomplement,
    $pkttype,
    $db_user,
    $db_password,
    $db_hostaddress,
    $evwarning,
    $evcritical,
    $occwarning,
    $occcritical,
    $help
);

my %exit_code = (
    'ok'   => 0,
    'warn' => 1,
    'crit' => 2,
    'unkn' => 3,
);

# Functions definition
sub help {
    print "Check BEDevents, $version\n";
    print "Author : $author\n";
    print "Copyright : $copyright\n";
    print "Help : check_bedevent.pl
        -t host, service, servicegroups, hostgroups
        -s String to look for (ex: Cam%)
        -Pe Display perf data
        -Sc Complement search (ex: equipment like :colsan1a%:)
        -St Ged type (check ged table 'pkt_type' column 'pkt_type_id' content)
        -u mysql username
        -p mysql password
        -H Host target
        -we Warning maximum number of events
        -ce Critical maximum number of events
        -Wo Warning maximum number of occurence
        -Co Critical maximum number of occurence\n";
    exit $exit_code{unkn};
}

sub outputdisplay () {
    $output =~ tr/,/\n/;
    if ($countcritical > 0){
        print "Critical : Click for detail \n\n$output";
        exit $exit_code{crit};
    } else {
        if ($countwarning > 0){
            print "Warning : Click for detail \n\n$output";
            exit $exit_code{warn};
        }
    }
    print $output;
    exit $exit_code{ok};
}

sub get_perf_data () {
    $output=$output.'|'.$perf;
}

# Main process
GetOptions(
    "t=s"       =>  \$type,
    "s=s"       =>  \$sqlstring,
    "Pe=s"      =>  \$o_perf,
    "Sc=s"      =>  \$sqlcomplement,
    "St=i"      =>  \$pkttype,
    "u=s"       =>  \$db_user,
    "p=s"       =>  \$db_password,
    "H=s"       =>  \$db_hostaddress,
    "we=i"      =>  \$evwarning,
    "ce=i"      =>  \$evcritical,
    "Wo=i"      =>  \$occwarning,
    "Co=i"      =>  \$occcritical,
    "help:s"    =>  \$help,
);
$sqlcomplement='' if (!defined $sqlcomplement);


if (! defined $help &&
    ! defined $type &&
    ! defined $sqlstring &&
    ! defined $pkttype &&
    ! defined $db_user &&
    ! defined $db_password &&
    ! defined $db_hostaddress &&
    ! defined $evwarning &&
    ! defined $evcritical &&
    ! defined $occwarning &&
    ! defined $occcritical
) { help(); }

$type=uc($type);
$sqlcomplement =~ s/:/'/g;

if (defined ($help)) { 	help(); }
print "Type hasn't set. Please use -t.\n" if (!defined $type);
print "String to search hasn't set. Please use -s.\n" if (!defined $sqlstring);
print "Pkttype to use hasn't set. Please use -St.\n" if (!defined $pkttype);
print "Database user hasn't set. Please use -u.\n" if (!defined $db_user);
print "Database password hasn't set. Please use -p.\n" if (!defined $db_password);
print "Host address hasn't set. Please use -H.\n" if (!defined $db_hostaddress);

if (! defined($evwarning)  && ! defined($occwarning)) { print "You haven't set any warning value. Please use -we or -Wo.\n"; }
if (! defined($evcritical) && ! defined($occcritical)) { print "You haven't set any critical value. Please use -ce or -Co.\n"; }
if (! defined($occwarning)) { $occ_warn=0; } else { $occ_warn=$occwarning; }
if (! defined($occcritical)) { $occ_crit=0; } else { $occ_crit=$occcritical; }

my $pkt_query = "SELECT pkt_type_name FROM ged.pkt_type WHERE pkt_type_id=$pkttype";

$pkt_dbh = DBI->connect("DBI:mysql:ged:$db_hostaddress", $db_user, $db_password);
$pkt_dbh->prepare($pkt_query);
my $pkt_result = $pkt_dbh->selectrow_array($pkt_query);

my $field_selection = 'id,contract,site,occ,equipment,service,state,ip_address,host_alias,hostgroups,servicegroups,owner,comments';
my $select_base = 'SELECT ' . $field_selection . ' FROM ged.' . $pkt_result . '_queue_active';
my $where_clause_comp = "AND owner='' AND comments='' AND ( occ>" . $occ_crit . " OR occ>" . $occ_warn." )";

if ($type eq "HOST") {
    $query = "$select_base WHERE equipment LIKE '$sqlstring' $sqlcomplement AND service LIKE 'HOST%' $where_clause_comp ;";
}
if ($type eq "SERVICE") {
    $query = "$select_base WHERE service LIKE '$sqlstring' $sqlcomplement $where_clause_comp ;";
}
if ($type eq "HOSTGROUPS") {
    $query = "$select_base WHERE hostgroups LIKE '$sqlstring' $sqlcomplement  $where_clause_comp ;";
}
if ($type eq "SERVICEGROUPS") {
    $query = "$select_base WHERE servicegroups LIKE '$sqlstring' $sqlcomplement  $where_clause_comp ;";
}
if ($type eq "CONTRACT") {
    $query = "$select_base WHERE contract = '$sqlstring' $sqlcomplement $where_clause_comp ;";
}

$dbh = DBI->connect("DBI:mysql:ged:$db_hostaddress", $db_user, $db_password);
$dbh->prepare($query);
$results = $dbh->selectall_hashref($query, 'id');
foreach my $id (keys %$results) {
    $occ[$nb_object]                = $results->{$id}->{occ};
    $contract[$nb_object]           = $results->{$id}->{contract};
    $site[$nb_object]               = $results->{$id}->{site};
    $equipment[$nb_object]          = $results->{$id}->{equipment};
    $service[$nb_object]            = $results->{$id}->{service};
    $state[$nb_object]            = $results->{$id}->{state};
    $ip_address[$nb_object]         = $results->{$id}->{ip_address};
    $hostgroups[$nb_object]         = $results->{$id}->{hostgroups};
    $servicegroups[$nb_object]      = $results->{$id}->{servicegroups};
    $state[$nb_object]              = $results->{$id}->{state};
    ++$nb_object;
}

if ($type eq "HOST" || $type eq "SERVICE" || $type eq "HOSTGROUPS" || $type eq "SERVICEGROUPS" || $type eq "CONTRACT") {
    if (defined($occwarning) || defined($occcritical)) {
        for (my $count = 0; $count < $nb_object; ++$count) {
            my $c_order = $count;
            my $cur_occ = $occ[$count];
            if ($cur_occ > $max_occ) {$max_occ = $cur_occ;}
            if ($state[$c_order] eq 2 || $state[$c_order] == 2) {
                if ($max_occ >= $occ_crit) {
                    $countcritical = 1;
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) is criticaly faulted from $occ[$c_order] notification cycles.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) service $service[$c_order] is criticaly faulted from $occ[$c_order] notification cycles.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
                    $output = "$output Contract $contract[$c_order] is critical faulted from $occ[$c_order] notification cycle.\n" if ($type eq "CONTRACT");
                }
            } else {
                if ($max_occ >= $occ_warn && $countcritical < 1) {
                    $countwarning = 1;
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) is faulted from $occ[$c_order] notification cycles.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) service $service[$c_order] is faulted from $occ[$c_order] notification cycles.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
                    $output = "$output Contract $contract[$c_order] is faulted from $occ[$c_order] notification cycle.\n";
                }
            }
            $out_count = $nb_object;
        }
        $perf = $o_perf . "=" . $out_count . ";" . $occwarning . ";" . $occcritical . ',' if (defined($o_perf));
    }

    if (defined($evwarning) || defined($evcritical)) {
        for (my $count = 0; $count < $nb_object; ++$count) {
            my $c_order = $count - 1;
            my $cur_occ = $occ[$count];
            if ($cur_occ > $max_occ) {$max_occ = $cur_occ;}
            if ($state[$c_order] eq 2 || $state[$c_order] == 2) {
                if ($nb_object >= $evcritical) {
                    $countcritical = 1;
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) was generated $occ[$c_order] events.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
                    $output = "$output Service $service[$c_order] was generated $occ[$c_order] events.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
                    $output = "$output Contract $contract[$c_order] was generated $occ[$c_order] critical events.\n";
                }
            } elsif ($state[$c_order] ge 1 || $state[$c_order] >= 1) {
                if ($nb_object >= $evwarning && $countcritical < 1) {
                    $countwarning = 1;
                    $output = "$output Equipment $equipment[$c_order]($ip_address[$c_order]) was generated $occ[$c_order] events.\n" if ($type eq "HOST" || $type eq "HOSTGROUPS");
                    $output = "$output Service $service[$c_order] was generated $occ[$c_order] events.\n" if ($type eq "SERVICE" || $type eq "SERVICEGROUPS");
                    $output = "$output Contract $contract[$c_order] was generated $occ[$c_order] warning events.\n";
                }
            }
            $out_count = $nb_object;
        }
        $perf = $o_perf . "=" . $out_count . ";" . $evwarning . ";" . $evcritical . ',' if (defined($o_perf));
    }
}

$output="OK : Events without active action concern $sqlstring have lower volume and/or less occurring than required values.\n" if ($countcritical lt 1 && $countwarning lt 1);

get_perf_data () if (defined $o_perf);
outputdisplay ();
exit $exit_code{ok};