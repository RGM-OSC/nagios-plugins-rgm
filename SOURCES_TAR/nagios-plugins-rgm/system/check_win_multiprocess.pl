#! /usr/bin/perl -w
use strict;

# Author : jakubowski Benjamin
# Date : 19/12/2005
# check_win_snmp_process.pl IP COMMUNITY service

my $PROGNAME = "check_win_snmp_process.pl";

sub print_usage {
    print "$PROGNAME IP COMMUNITY service\n";
}

if  ( !defined($ARGV[0]) || !defined($ARGV[1]) || !defined($ARGV[2]) ) {
    print_usage();
    exit 0;
}


my $STATE_CRITICAL = 2;
my $STATE_OK = 0;

my $IP=$ARGV[0];
my $COMMUNITY=$ARGV[1];
#my $Service=$ARGV[2];
my @tab=split(/,/,$ARGV[2]);
my $Service;
my $state=0;
foreach $Service (@tab) {
	my $resultat =`snmpwalk -v 1 -c $COMMUNITY $IP  hrSWRunName | grep $Service`;
	my @sid;
	my $pb_calcul;
	my $memory;

	if ( $resultat ) {
	    @sid=split(/\n/,$resultat);
	    my $nb_service = $#sid + 1;
    
	    my $total_memory_used=0;
    
	    my $char_memory="";	
	    my @liste_pid;

	    foreach (@sid) {
		s/HOST-RESOURCES-MIB::hrSWRunName.//g;
		my @information_sid = split (/ /);
		my $num_sid = $information_sid[0];
		push(@liste_pid,$num_sid);
	    
	#	$memory = `snmpwalk -v 1 -c $COMMUNITY $IP hrSWRunPerfMem | grep hrSWRunPerfMem.$num_sid`;

		$memory = `snmpget -v 1 -c $COMMUNITY $IP hrSWRunPerfMem.$num_sid`;
		chomp $memory;

		$memory=~ s/HOST-RESOURCES-MIB::hrSWRunPerfMem\.\d+ = INTEGER: //g;
	
		my @information_memory = split(/ /,$memory);

	if (  $information_memory[1] eq "KBytes") {
		    $total_memory_used+=$information_memory[0];
		} else {
		    $pb_calcul=1;
		    $char_memory.=$memory;
		}
    	}		 

	    if ( $pb_calcul ) {
		print "OK : Service $Service PID's (",join(" ",@liste_pid),"). Running impossible to ckeck memory : $char_memory\n";
	#	exit $STATE_OK;
		$state= $state + 0;
	    } else {
		print "OK : Service $Service PID's (",join(" ",@liste_pid),"). Running Memory used $total_memory_used KBytes\n";
	#	exit $STATE_OK;
 		$state= $state + 0;
 	   } 
 	 #  print "OK : Service $Service Running Memory used $memory\n";
	 #   exit $STATE_OK;
	} else {
	    print "Critical  : Service $Service not found\n";
 	#   exit $STATE_CRITICAL;
	     $state= $state + 1;	
	}
}
if ( $state > 0) {
exit $STATE_CRITICAL;
} else {

exit $STATE_OK;
}
