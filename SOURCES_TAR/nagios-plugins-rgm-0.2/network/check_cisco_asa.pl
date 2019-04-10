#!/usr/bin/perl -X
# ============================================================================
# 
#
#       This program is free software; you can redistribute it and/or modify it
#       under the terms of the GNU General Public License as published by the
#       Free Software Foundation; either version 2, or (at your option) any
#       later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ============================================================================
#
# check_cisco_asa.pl : SNMP check for cisco pix/asa and 
#                      returning state of different interfaces.
# ./check_cisco.pl -h (ip) -c (community) -i (number of interface) or 
#                  -n (name of interface) -s state (optional)
#
# Version 0.91 (Bugfix for ASA 8.0(3)19
# ============================================================================

#
###################Setting up some parameters#########################
use strict;
use Getopt::Long;

my $UNKNOW = -1;
my $OK = 0;
my $WARNING = 1;
my $CRITICAL = 2;
my $state = "up"; 
my $mode = "i";
my $host = "127.0.0.1";
my $community = "public";
my $interface = "99";
my $name = "na";
my $walkDescr="";
my $MIBifDescr="IF-MIB::ifDescr";
my $MIBifOper="IF-MIB::ifOperStatus";
my $MIBipAdEntAddr="IP-MIB::ipAdEntAddr";
my $MIBipAdEntIfIndex="IP-MIB::ipAdEntIfIndex";
my $MIBipAdEntNetMask="IP-MIB::ipAdEntNetMask";
my $MIBifMtu="IF-MIB::ifMtu";
my $MIBUpTime="sysUpTime.0";
my $MIBDescription="sysDescr.0";

# not used yet
#my $warning = "1000";
#my $critical = "2000";
#my $oid="0";
#my $MIBifName="IF-MIB::ifName";
#my $MIBifLastChange="IF-MIB::ifLastChange";
#my $MIBTrafficIn="IF-MIB::ifInOctets";
#my $MIBTrafficOut="IF-MIB::ifOutOctets";
#my $MIBDescription="IF-MIB::ifAlias";

###################Getting options##############################
GetOptions(
        "mode|m=s" => \$mode,
        "host|h=s" => \$host,
        "community|c=s"  => \$community,
	"interface|i=s"   => \$interface,
	"name|n=s"	=> \$name,
	"state|s=s"	=>\$state,
);
chomp($mode);
chomp($host);
chomp($community);
chomp($interface);
chomp($name);
chomp($state);
#################################################################

# Check for Parameters Errors

if ($host eq "127.0.0.1") {
   outputerror();
   exit
   }


if ($name eq "na" && $interface == 99 && $mode eq "i") {
   outputerror();
   exit
   }


if ($name ne "na" && $interface != 99 && $mode eq "i") {
   outputerror();
   exit
   }


#  Mode Uptime

if ($mode eq "u") {

    my $uptime = snmpget($host, $community, $MIBUpTime, "-Ova");
    print "$uptime\n";
    exit
    }


#  Mode Description

if ($mode eq "d") {

    my $description = snmpget($host, $community, $MIBDescription, "-Ovq");
    print "$description\n";
    exit
    }


#  Main Programm   


   if ($name ne "na" ) {


    # SNMP read
    $walkDescr = snmpwalkgrep1($host, $community, $MIBifDescr, $name);

    my $nfp=index($walkDescr,".",);
    my $gn=substr($walkDescr,$nfp+1,2);

    $interface=$gn;
    }


    # SNMP read
    my $walkIp = snmpwalkgrep2($host, $community, $MIBipAdEntIfIndex, $interface);


    # Bestimmen wo das '=' im String steht
    # $le = laenge - $fg = finde '='
    my $le=length($walkIp);
    my $fg=$le-index($walkIp,"=",);

    # Bestimmen wo der erste '.' im String steht
    # $fp = wo der erste '.' ist
    my $fp=index($walkIp,".",);

    # Baue die IP zusammen
    my $IP=substr($walkIp, $fp+1,$le-$fp-$fg-2);


    # Interface Name komplett holen
    my $InfName = snmpget($host, $community, "$MIBifDescr.$interface", -Ovq);

    # ' ' Finden
    # $l1 = erstes ' und $l2 = zweites ' und $lo = länge dazwischen
    my $l1=index($InfName,"'",);
    my $l2=index($InfName,"'",++$l1);
    my $lo=$l2-$l1;

    # SubMaske
    my $IPMask = snmpget($host, $community, "$MIBipAdEntNetMask.$IP", -Ovq);

    # MTU
    my $IPMtu = snmpget($host, $community, "$MIBifMtu.$interface", -Ovq);


    # OperStatus 
    my $IFStatus = snmpget($host, $community, "$MIBifOper.$interface", -Ovq); 
    my $IFName = substr($InfName,$l1,$lo);

    my $output ="Interface $IFName with IP $IP MASK $IPMask MTU $IPMtu is $IFStatus";

    # my $change = snmpget($host, $community, "$MIBifLastChange.$interface");




    if ($IFStatus =~ /up/ && $state eq "up"){
                     print "$output\n";
                     exit $OK;
            
             }elsif ($IFStatus =~ /down/ && $state eq "up"){
                     print "$output\n";
                     exit $CRITICAL;
             
             }elsif($IFStatus =~ /down/ && $state eq "down"){
                     print "$output\n";
                     exit $OK;
                     
             }elsif($IFStatus =~ /up/ && $state eq "down"){
                     print "$output\n";
                     exit $CRITICAL;
             }else{
                     print "Unknown state for $name $interface check connection/syntax\n";
                     exit $UNKNOW;
             }


# Sub Routine

sub CleanMe
{
	my $input=$_[0];
	if ($input =~ /: (.*)/){
	my $return=$1;
	chomp($return);
	return $return;
	}
}

sub snmpwalk
{
	my ($host, $community, $tree)=@_;
	my $walk = `snmpwalk -v 1 -c $community $host $tree`;
	chomp($walk);
	return $walk;
}

sub snmpwalkgrep1
{
	my ($host, $community, $tree, $interface)=@_;
	my $walk = `snmpwalk -v 1 -c $community $host $tree |grep $interface`;
	chomp($walk);
	return $walk;
}

sub snmpwalkgrep2
{
        my ($host, $community, $tree, $intfa)=@_;
        my $walk = `snmpwalk -v 1 -c $community $host $tree |grep "INTEGER: "$intfa`;
        chomp($walk);
        return $walk;
}

sub snmpget
{
	my ($host, $community, $tree, $output)=@_;
	my $get = `snmpget -v 1 $output -c $community $host $tree`;
	chomp($get);
	return $get;
}

sub outputerror

{
	print " \n\n";
	print " Wrong Parameters Set - Please Check your Input\n\n";
      
        print " -h or --host       : Set here the ip of your host\n"; 
        print " -c or --community  : Set here your own community\n\n";

        print " -m or --mode       : Modus of the Plugin : i = Interfaces (Default)\n";
        print "                                            d = Description\n";
        print "                                            u = uptime\n\n";
               
        print " Notice : !! Do not use -n and -i simultaneously !!\n";
        print " -n or --name       : Set here the interface name (exemple : inside / outside ...)\n";
        print " -i or --interface  : Set here the interface Number (exemple : 1 (the Name will be read automatic)\n\n";
                        
        print " Optional\n";
        print " -s or --state      : Set the state of your interface. Options are : up/down\n\n";
                                
        print " (c) 2008 by Michael Trautes\n\n\n";
}
                                    

# ============================================================================

# This module is free software; you can redistribute it and/or
# modify it under the terms of the GNU Public License.
