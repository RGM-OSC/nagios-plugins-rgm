#!/usr/bin/perl 
# This  Plugin checks the Riverbed system values
#
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-130

use strict;
use Net::SNMP;
use Switch;
use constant RB_OID       => '1.3.6.1.4.1.17163.1.1';
use constant HEALTH_OK	  => 10000;



my %status	= (  'UNKNOWN'  => '-1',
                      'OK'       => '0',
                      'WARNING'  => '1',
                      'CRITICAL' => '2'   );

my %status_inv   = (  '-1'  => 'UNKNOWN',
                      '0'       => 'OK',
                      '1'  => 'WARNING',
                      '2' => 'CRITICAL'   );



my %oid_list	= (
		'outlan'     => RB_OID . '.5.3.1.1.0',
		'outwan'     => RB_OID . '.5.3.1.2.0',
		'inlan'      => RB_OID . '.5.3.1.3.0',
		'inwan'      => RB_OID . '.5.3.1.4.0',
		'healthenum' => RB_OID . '.2.7.0',
		'healthstr'  => RB_OID . '.2.2.0',
		'model'      => RB_OID . '.1.1.0',
    );					  

sub print_help()
{
  print "Usage: $0 -H [host] -C [community] [-p] [peer]\n";
  print "Options:\n";
  print " -H --host STRING or IPADDRESS\n";
  print "   Check interface on the indicated host.\n";
  print " -C --community STRING\n";
  print "   Community-String for SNMP-Walk.\n";
  print " -p --Peer [arg]\n";
  print "   List of peer Riverbed servers to check\n";
  exit($status{"UNKNOWN"});
}
				  
if ($#ARGV == -1)
{
  print_help();
}
					  
my $res_string	= "";
my $oid		= 0;
my $health	= "OK";

sub pars_args
{
  my $name      = "";
  my $community = ""; 
  my $peer      = "";
  
  while($ARGV[0] =~/^-/) 
  {
    if($ARGV[0] =~/^-H|^--host/) 
    {
      $name = $ARGV[1];
      shift @ARGV;
      shift @ARGV;
      next;
    }
    if($ARGV[0] =~/^-C|^--Community/) 
    {
      $community = $ARGV[1];
      shift @ARGV;
      shift @ARGV;
      next;
    }
    if($ARGV[0] =~/^-p|^--Peer/) 
    {
      $peer = $ARGV[1];
      shift @ARGV;
      shift @ARGV;
      next;
    }
  }
  return ($name, $community, $peer);
}

my ($name, $community, $peer) = pars_args();

#sub print_cpu_usage
#{
#$oid = "1.3.6.1.4.1.12356.101.4.1.3";
#my $res = `snmpwalk -c $community -Ov -Oq -v 2c $ip $oid`;
#$res_string = sprintf("CPU usage: %d \%", $res);
#$health = ($res > $warning ? ($res > $critical ? "CRITICAL" : "WARNING") : "OK"); 
#}

#sub print_mem_usage
#{
#$oid = "1.3.6.1.4.1.12356.101.4.1.4";
#my $res = `snmpwalk -c $community -Ov -Oq -v 2c $ip $oid`;
#$res_string = sprintf("Memory usage: %d \%", $res);
#$health = ($res > $warning ? ($res > $critical ? "CRITICAL" : "WARNING") : "OK");
#}

#sub print_disk_usage
#{
#$oid = "1.3.6.1.4.1.12356.101.4.1.6";
#my $memU = `snmpwalk -c $community -Ov -Oq -v 2c $ip $oid`;
#my $memC = `snmpwalk -c $community -Ov -Oq -v 2c $ip 1.3.6.1.4.1.12356.101.4.1.7`;
#my $res = $memU * 100 / $memC;
#$res_string = sprintf("Disk usage: %.3f \% ( %d \/ %d )", $res, $memU, $memC);
#$health = ($res > $warning ? ($res > $critical ? "CRITICAL" : "WARNING") : "OK");
#}

#sub old_print_health
#{
#	
#my @oid_cles = keys(%oid_list);
#my $i;
#
#	foreach $i (@oid_cles)
#	{
#	"$i => $oid_list{$i} => ";
#		my $res = `snmpwalk -c $community -Ov -Oq -v 2c $name $oid_list{$i}`;
#		print $res . "\n";
#	}
#}

sub get_health
{
	my $k;
	my $v;
	my %out;
        while (($k,$v) = each(%oid_list))
        {
                my $res = `snmpwalk -c $community -Ov -Oq -v 2c $name $v`;
		chomp($res);
		$out{$k} = $res;
#                print "$k =>\t$v =>\t" . $res . "\n";
        }
	return ($out{'healthenum'} != HEALTH_OK ? 2 : 0,
	    "Riverbed $out{'model'} | Status: $out{'healthstr'}",
	    "OUTLAN=$out{'outlan'} OUTWAN=$out{'outwan'} INLAN=$out{'inlan'} INWAN=$out{'inwan'}\n");
}

sub get_peer
{
	my @peer = split(/\,/,$peer);
	my $code = 1;
	my %res;
	my $oid_name = RB_OID . '.2.6.1.1.2';
	my $oid_ip = RB_OID . '.2.6.1.1.4';
        my @res_ip = `snmpwalk -c $community -Ov -Oq -v 2c $name $oid_ip`;
	my @res_name = `snmpwalk -c $community -Ov -Oq -v 2c $name $oid_name`;
	my ($state,$reponse) = (0,"");
	chomp(@res_ip);
	chomp(@res_name);
	for( my $i=0; $i<=$#res_ip; $i+=1 ) {
#   		print("\ni:$i\t$res_name[$i] --> $res_ip[$i]");
		$res{$res_name[$i]} = $res_ip[$i];
	}
	for my $i (@peer)
	{
		if( exists( $res{"\"$i\""} ) ) {
 			$reponse=$reponse . "Le peer $i est PRESENT\t";
			$state = ($state = 0 ? 0 : $state);
		}
		else {
			$reponse=$reponse . "Le peer $i est INJOIGNABLE";
			$state = 2;
		} 		
	}
	return($state,$reponse,"");
}



my ($code, $output, $perf);
my (@outputAll, @perfAll);
#($code, $output, $perf)=get_health();

if ($peer ne ""){($code, $output, $perf)=get_peer();}
else {($code, $output, $perf)=get_health();}

printf ("%s: %s\n%s", $status_inv{$code}, $output, $perf);
exit($code);
