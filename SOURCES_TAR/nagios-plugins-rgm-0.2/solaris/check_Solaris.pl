#!/usr/bin/perl
## 
## License: GPL
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

use strict;
use POSIX qw(locale_h);	
use POSIX qw(strftime);
use POSIX;
use DateTime;
use File::Basename;
use XML::Simple;
use Data::Dumper;
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_F $opt_t $host $connector $verbose $PROGNAME $critical $warning $Revision);

use utils qw(%ERRORS &print_revision &support &usage);
use Socket;

$PROGNAME="check_Solaris.pl";
sub print_help ();
sub print_usage ();


setlocale(LC_CTYPE, "en_EN");
$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
$Revision="0.1";

my $dtnow = DateTime->now;

my $debug;
my $chain;
my $server;
my $FSname;
my @LastCheck;
my $ChainFile;

Getopt::Long::Configure('bundling');
GetOptions
        ("V"     => \$opt_V,           "version"      => \$opt_V,
         "h"     => \$opt_h,           "help"         => \$opt_h,
         "v"     => \$verbose,         "verbose"      => \$verbose,
         "d"     => \$debug,           "debug"        => \$debug,
         "S=s"   => \$server,          "server=s"     => \$server,
         "C=s"   => \$chain,           "chain=s"      => \$chain,
	 "F=s"   => \$FSname,	       "FSname=s"     => \$FSname,
         "w=i"   => \$warning,         "warning=i"    => \$warning,
         "c=i"   => \$critical,        "critical=i"   => \$critical);

if ($opt_V) {
        print "$PROGNAME Revision: $Revision\n";
        exit $ERRORS{'OK'};
}

$opt_t = $utils::TIMEOUT ;      # default timeout

if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

unless (defined $server) {
        print "Missing Server Name\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

unless (defined $chain) {
        print "Missing Chain\n";
        print_usage();
        exit $ERRORS{'UNKNOWN'};
}

#unless (defined $warning) {
#        print "Missing WARNING in seconds\n";
#        print_usage();
#        exit $ERRORS{'UNKNOWN'};
#}

#unless (defined $critical) {
#        print "Missing CRITICAL in seconds\n";
#        print_usage();
#        exit $ERRORS{'UNKNOWN'};
#}

#if ( $warning > $critical ) {
#        print "Warning cannot be greater than Critical\n";
#        print_usage();
#        exit $ERRORS{'UNKNOWN'};
#}

my $address = gethostbyname($server);
my $ip = Socket::inet_ntoa($address);

$FSname =~ tr/\//µ/;

if ( $FSname ) {
	$ChainFile = "/tmp/tmp-internal-Solaris/" . $server . "/" . $ip . "/" . $chain . "_" . $FSname . "_Last_State.txt";
	print "ChainFile: $ChainFile \n" if $debug;
}

else {
	$ChainFile = "/tmp/tmp-internal-Solaris/" . $server . "/" . $ip . "/" . $chain . "_Last_State.txt";
        print "ChainFile: $ChainFile \n" if $debug;
}

unless (-f $ChainFile ) {
        print "Cannot find \"$ChainFile\"\n";
        exit $ERRORS{'UNKNOWN'};
}

open (MYFILE, $ChainFile);
 while (<MYFILE>) {
 	chomp;
 	@LastCheck= split ( /\s/, $_ );
 }
 close (MYFILE);
print "Warning: $warning    Critical: $critical\n" if $debug;

my @LastTupleDate = split ( '-', @LastCheck[0] );
my @LastTupleTime = split ( ':', @LastCheck[1] );

my @fs_name;
my @percent_values;
my @used_values;
my @max_values;
my $final_chain;

if ( $chain eq "SolarisCheckFS" ) {
	@fs_name = split( ' ', @LastCheck[7] );
	@percent_values = split( ' ', @LastCheck[6] );
	@used_values = split( ' ', @LastCheck[4] );
	@max_values = split( ' ', @LastCheck[3] );
	
	my $graph = " @fs_name[0]=" . ceil(@used_values[0] /1000) . "MB;" . $warning . ";" . $critical . ";0 " . @fs_name[0] . "_percent=" . @percent_values[0] . ";" . $warning . ";" . $critical . ";0";
	$final_chain = @fs_name[0] . ": " . @percent_values[0] . "used (" . ceil(@used_values[0] /1000) . "MB/" . ceil(@max_values[0] /1000) . "MB) : |" . $graph;

	if ( (@max_values[0] * $critical) /100 <= @used_values[0] ) {
		print "CRITICAL $final_chain\n";
		exit $ERRORS{'CRITICAL'}; 
	}
	elsif ( (@max_values[0] * $warning) /100 <= @used_values[0] ) {
        	print "WARNING $final_chain\n";
		exit $ERRORS{'WARNING'};
	}
  
}

my @proc_name;
my @pid_nb;
my @cons_cpu;
my @cons_mem;

if ( $chain eq "SolarisCheckProc" ) {
        @proc_name = split( ' ', @LastCheck[5] );
        @pid_nb = split( ' ', @LastCheck[4] );
        @cons_cpu = split( ' ', @LastCheck[2] );
        @cons_mem = split( ' ', @LastCheck[3] );
	
	$final_chain = "Process: " . @proc_name[0] . ", PID: " . @pid_nb[0] . ", cons: CPU: " . @cons_cpu[0] . "%" . ", MEM: " . @cons_mem[0] . "%";

	if ( @cons_cpu[0] >= $critical ) {
                print "$final_chain CRITICAL\n";
                exit $ERRORS{'CRITICAL'};
        }

	elsif ( @cons_mem[0] >= $critical ) {
                print "$final_chain CRITICAL\n";
                exit $ERRORS{'CRITICAL'};
        }

        elsif ( @cons_cpu[0] >= $warning ) {
                print "$final_chain WARNING\n";
                exit $ERRORS{'WARNING'};
        }

	elsif ( @cons_cpu[0] >= $warning ) {
                print "$final_chain WARNING\n";
                exit $ERRORS{'WARNING'};
        }

}

my @idle_cpu;

if ( $chain eq "SolarisCheckCPU" ) {
        @idle_cpu = split( ' ', @LastCheck[2] );
	my $total_cons_cpu = 100 - @idle_cpu[0];

	$final_chain = "CPU used: " . $total_cons_cpu . "% ";

	if ( $total_cons_cpu >= $critical ) {
		print "CRITICAL $final_chain (<$critical)\n";
	}
	
	elsif ( $total_cons_cpu >= $warning ) {
		print "WARNING $final_chain (<$warning)\n";
	}
	
	else {
		my $graph = " cpu=" . $total_cons_cpu . "%;" . $warning . ";" . $critical . ";0";
		$final_chain = "CPU used: " . $total_cons_cpu . "% (<" . $warning . ") | " . $graph;
	}	
}

my @value;
my @value1;
my @value2;
my @name;
my @name1;
my @name2;

if ( $chain eq "SolarisCheckVALSYS" ) {
        @value = split( ' ', @LastCheck[2] );
        @value1 = split( ' ', @LastCheck[4] );
        @value2 = split( ' ', @LastCheck[6] );
        @name = split( ' ', @LastCheck[3] );
        @name1 = split( ' ', @LastCheck[5] );
        @name2 = split( ' ', @LastCheck[7] );

	my $graph = @name[0] . "=" . @value[0] . " " . @name1[0] . "=" . @value1[0] . " " . @name2[0] . "=" . @value2[0];
	$final_chain = "Click on for details\nName: " . @name[0] . ", Value: " . @value[0] . "\nName: " . @name1[0] . ", Value: " . @value1[0] . "\nName: " . @name2[0] . ", Value: " . @value2[0] . "|" . $graph;
}

my @boot_month;
my @boot_day;
my @boot_hour;

if ( $chain eq "SolarisCheckUpTime" ) {
        @boot_month = split( ' ', @LastCheck[2] );
        @boot_day = split( ' ', @LastCheck[3] );
        @boot_hour = split( ' ', @LastCheck[4] );

	$final_chain = "boot time : " . @boot_month[0] . " " . @boot_day[0] . " " . @boot_hour[0];
}

my @value_1;
my @value_2;
my @value_3;

if ( $chain eq "SolarisCheckLoadAverage" ) {
	@value_1 = split( ' ', @LastCheck[2] );
	@value_2 = split( ' ', @LastCheck[3] );
	@value_3 = split( ' ', @LastCheck[4] );
	
	my $graph = " LoadAverage=" . substr(@value_1[0], 0, -1) . ";" . $warning . ";" . $critical . ";0";
	$final_chain = "Load average: " . @value_1[0] . @value_2[0] . @value_3[0] . "|" . $graph;

	if ( @value_1[0] >= $critical ) {
                print "CRITICAL $final_chain\n";
                exit $ERRORS{'CRITICAL'};
        }

        elsif ( @value_1[0] >= $warning ) {
                print "WARNING $final_chain\n";
                exit $ERRORS{'WARNING'};
        }
}

my @total_mem;
my @mem_free;
my @total_swap;
my @swap_use;

my $percent_mem;
my $percent_swap;
my $mem_use;

if ( $chain eq "SolarisCheckMEM" ) {
	@total_mem = split( ' ', @LastCheck[2] );
	@mem_free = split( ' ', @LastCheck[3] );
	@total_swap = split( ' ', @LastCheck[5] );
	@swap_use = split( ' ', @LastCheck[4] );

	my $total_mem = substr(@total_mem[0], 0, -1);
	my $mem_free = substr(@mem_free[0], 0, -1);
	my $total_swap = substr(@total_swap[0], 0, -1);
	my $swap_use = substr(@swap_use[0], 0, -1);

	my $mem_unity = chop(@total_mem[0]);
	my $swap_unity = chop(@total_swap[0]);
        my $mem_free_unity = chop(@mem_free[0]);

	my $warning_swap = $warning - 40;
	my $critical_swap = $critical - 35;

	if ( $mem_unity eq "M" ) {
		
		$mem_use = $total_mem - $mem_free;
		
		$percent_mem = ceil(($mem_use *100) / $total_mem);
		if ( $swap_unity eq "G" ) {
			$percent_swap = ceil(($swap_use *100) / ceil($total_swap *1000));
		}
		else {
			$percent_swap = ceil(($swap_use *100) / $total_swap);
		}
		my $graph = " memory=" . $mem_use . "MB;" . $warning . ";" . $critical . ";0 memory_percent=" . $percent_mem . "%;" . $warning . ";" . $critical . " swap=" . $swap_use . "MB;" . $warning_swap . ";" . $critical_swap . ";0 swap_percent=" . $percent_swap . "%;" . $warning_swap . ";" . $critical_swap;
		$final_chain = "Memory: " . $mem_use . "M/" . ceil($total_mem) . "M, Swap: " . $swap_use . "M/" . ceil($total_swap) . "M :: " . $percent_mem . "%, " . $percent_swap . "% |" . $graph;
	
	}

	elsif ( $mem_unity eq "G" ) {

		if ( $mem_free_unity eq "G" ) {
                        $mem_use = ceil($total_mem *1000) - ceil($mem_free *1000);
		}

		else {
			$mem_use = ceil($total_mem *1000) - $mem_free;
		}

                $percent_mem = ceil(($mem_use *100) / ($total_mem *1000));
                $percent_swap = ceil(($swap_use *100) / ($total_swap *1000));
               
		my $graph = " memory=" . $mem_use . "MB;" . $warning . ";" . $critical . ";0 memory_percent=" . $percent_mem . "%;" . $warning . ";" . $critical . ";0 swap=" . $swap_use . "MB;" . $warning_swap . ";" . $critical_swap . ";0 swap_percent=" . $percent_swap . "%;" . $warning_swap . ";" . $critical_swap . ";0";
		$final_chain = "Memory: " . $mem_use . "M/" . ceil($total_mem *1000) . "M, Swap: " . $swap_use . "M/" . ceil($total_swap *1000) . "M :: " . $percent_mem . "%, " . $percent_swap . "%|" . $graph;
	
	}

	if ( $percent_mem >= $critical ) {
		print "CRITICAL $final_chain\n";
                exit $ERRORS{'CRITICAL'};
        }
	
	elsif ( $percent_swap >= $critical_swap ) {
                print "CRITICAL $final_chain\n";
                exit $ERRORS{'CRITICAL'};
        }

	elsif ( $percent_mem >= $warning ) {
                print "WARNING $final_chain\n";
                exit $ERRORS{'WARNING'};
        }

	elsif ( $percent_swap >= $warning_swap ) {
                print "WARNING $final_chain\n";
                exit $ERRORS{'WARNING'};
        }
}

my @NBU_bpcd;
my @NBU_vnetd;

if ( $chain eq "SolarisCheckNBUClient" ) {
	@NBU_bpcd = split( ' ', @LastCheck[2] );
	@NBU_vnetd = split( ' ', @LastCheck[3] );

	$final_chain = "NBU client communication";

	if ( @NBU_bpcd[0] eq "" and @NBU_vnetd[0] eq "" ) {
		print "CRITICAL Click for details\n $final_chain bpcd,vnetd port not open\nPlease run /usr/openv/netbackup/bin/vnetd -standalone\n/usr/openv/netbackup/bin/bpcd -standalone";
                exit $ERRORS{'CRITICAL'};
	}

	elsif ( @NBU_bpcd[0] eq "" ) {
		print "CRITICAL Click for details\n $final_chain bpcd port not open\nPlease run /usr/openv/netbackup/bin/bpcd -standalone";
		exit $ERRORS{'CRITICAL'};
	}

	elsif ( @NBU_vnetd[0] eq "" ) {
                print "CRITICAL Click for details\n $final_chain vnetd port not open\nPlease run /usr/openv/netbackup/bin/vnetd -standalone";
                exit $ERRORS{'CRITICAL'};
        }

}	

my @Fault;

if ( $chain eq "SolarisCheckFault" ) {
	@Fault = split( ' ', @LastCheck[2] );

	if ( @Fault[0] eq "nothing" ) {
		$final_chain = "No fault in system";
	}

	else {
		$final_chain = "Please run cmd `fmadm faulty -a` for more information";
		print "CRITICAL, $final_chain \n";
		exit $ERRORS{'CRITICAL'};
	}
}

my @Nb_Zone_Sys;
my $Nb_Zone_EON;

if ( $chain eq "SolarisCheckZone" ) {
	@Nb_Zone_Sys = split( ' ', @LastCheck[2] );
	$Nb_Zone_EON = `/bin/grep -e '$server\$' /srv/eyesofnetwork/nagios/etc/objects/hosts.cfg | /bin/grep -Ev 'host_name|display_name|alias' | /usr/bin/wc -l`;

	print "Avant Splice Debug Array Zone: ".Dumper(@LastCheck)." \n" if $debug;
        my $SizeArray = @LastCheck;
        my @ZoneListFinalArray = @LastCheck;
        splice @ZoneListFinalArray, 0, 3;
        print "Debug Array Zone: ".Dumper(@ZoneListFinalArray)." \n" if $debug;

 	$final_chain = "Click on for details\n@ZoneListFinalArray | nb_zone=" . @Nb_Zone_Sys[0] . ";3;5;0";

	if ( @Nb_Zone_Sys[0] != $Nb_Zone_EON ) {
		print "CRITICAL, all virtuals hosts not running, $final_chain \n";
                exit $ERRORS{'CRITICAL'};
	}
}

my @Nb_Zombie;
my @PID;

if ( $chain eq "SolarisCheckZombie" ) {
	@Nb_Zombie = split( ' ', @LastCheck[2] );
	my $SizeArray = @LastCheck;
        @PID = @LastCheck;
        splice @PID, 0, 3;

	my $graph = "zombie=" . @Nb_Zombie[0] . ";" . $warning . ";" . $critical . ";0";

	if ( @Nb_Zombie[0] == 0 ) {
		$final_chain = "No Zombie process find |" . $graph;
	}
	elsif ( @Nb_Zombie[0] < $warning ) {
		$final_chain = "Awesome Zombie process find, click for detail\n PID: @PID |" . $graph;
	}
	elsif ( @Nb_Zombie[0] >= $critical ) {
		$final_chain = "Lots of Zombie process find, kill the following processes (PID)";
		print "CRITICAL, $final_chain \n PID: @PID |" . $graph;
		exit $ERRORS{'CRITICAL'};
	}
	else {
		$final_chain = "Several Zombie process find, kill the following processes (PID)"; 
		print "WARNING, $final_chain \n PID: @PID |" . $graph;
		exit $ERRORS{'WARNING'};
	}
}

my @LogInfo;
my @AllInfo;
my $elem;

if ( $chain eq "SolarisCheckLog" ) {
	@AllInfo = @LastCheck;
	splice @AllInfo, 0, 2;
	
	if ( @AllInfo[0] eq "ok" ) {
		$final_chain = "No error in log";
	}
	
	else {
		$final_chain = "Click for details\n@AllInfo";
		print "CRITICAL $final_chain";
		exit $ERRORS{'CRITICAL'};
	}
}	

print "$final_chain \n" if $debug;
print "LastCheck: @LastCheck \n" if $debug;
print "Date: @LastTupleDate \n" if $debug;
print "Time: @LastTupleTime \n" if $debug;

my $dtlastcheck =  DateTime->new(
      year       => $LastTupleDate[0],
      month      => $LastTupleDate[1],
      day        => $LastTupleDate[2],
      hour       => $LastTupleTime[0],
      minute     => $LastTupleTime[1],
      second     => $LastTupleTime[2],
      time_zone   => 'Europe/Paris',
      );

my $epoch_dtnow = $dtnow->epoch();
my $epoch_dtlastcheck = $dtlastcheck->epoch();

print "Now: " if $debug;
print $epoch_dtnow if $debug;
print " \n" if $debug;

print "Last Check: " if $debug;
print $epoch_dtlastcheck if $debug;
print " \n" if $debug;

print "GAP Time in seconde: " if $debug;
my $gap = $epoch_dtnow - $epoch_dtlastcheck;
print $gap if $debug;
print " \n" if $debug;

if ( $gap == 0  || not defined ($gap) ){
        print "CRITICAL: Cannot get last execution time for the chain $chain | lastcheck=0\n";
        exit $ERRORS{'CRITICAL'};
}

if ( 900 < $gap ) {
   print "CRITICAL: Too much time enlapse since the last execution of $chain. | lastcheck=$gap \n";
   exit $ERRORS{'CRITICAL'};
}

if ( 600 < $gap ) {
    print "WARNING: Time enlapse since the last execution of $chain is too high. | lastcheck=$gap\n";
    exit $ERRORS{'WARNING'};
}

#print "OK: The chain $chain was check $gap seconds ago. | lastcheck=$gap\n";

print "OK: $final_chain\n";
exit $ERRORS{'OK'};

#
# Additional functions
#

sub print_usage () {
    print "Usage:
   $PROGNAME -S servername -C Chain [-F FSname] -w warning -c critical [-d] [-h]
   $PROGNAME --help
   $PROGNAME --version
";
}

sub print_help () {
        print "$PROGNAME Revision $Revision\n \n";
        print "Copyright (c) 2013 Michael Aubertin <michael.aubertin\@gmail.com> Licenced
under GPLV2\n";

        print_usage();
        print "
-F, --FSname
   Name FS ONLY for check FS
-C, --Chain
   Chain CheckSolaris
-d, --verbose
   Print some extra debugging information (not advised for normal operation)
-w, --warning
   Seconds before expiration
-c, --critical
   Seconds before expiration
\n";
}
