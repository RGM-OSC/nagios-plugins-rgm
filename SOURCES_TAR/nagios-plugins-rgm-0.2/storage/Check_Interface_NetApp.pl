#! /usr/bin/perl

use Getopt::Long;

# Variables
$PROGNAME = "Dinamyc Iface Analyzer";
$REVISION = "0.1";
my ($opt_version,$opt_help,$opt_all);
my ($opt_timeout,$opt_license,$opt_device);
my ($opt_hostname,$opt_community,$opt_port,$opt_snmpvers);
my ($opt_warn,$opt_crit);
my ($PROGNAME,$REVISION);

use constant DEFAULT_PORT               =>161;
use constant DEFAULT_COMMUNITY          =>"public";
use constant DEFAULT_SNMPVERS           =>"1";
use constant DEFAULT_WARNING            =>"80";
use constant DEFAULT_CRITICAL           =>"90";

# OIDs

my      $ifNumber        ="IF-MIB::ifNumber";
my	$ifDescr	 ="IF-MIB::ifDescr";
my	$ifSpeed	 ="IF-MIB::ifSpeed";
my      $ifPhysAdress	 ="IF-MIB::ifPhysAddress";
my      $ifAdminStatus	 ="IF-MIB::ifAdminStatus";
my	$ifOperStatus	 ="IF-MIB::ifOperStatus";
my	$ifInOctets	 ="IF-MIB::ifInOctets";
my	$ifInErrors	 ="IF-MIB::ifInErrors";
my	$ifOutOctets	 ="IF-MIB::ifOutOctets";
my	$ifOutErrors	 ="IF-MIB::ifOutErrors";

# Comprobacion de las opciones pasadas

my $arg_status = check_args();
if ($arg_status){
  print "ERROR: some arguments wrong\n";
  exit $ERRORS{"UNKNOWN"};
}

sub check_args {

  Getopt::Long::Configure('bundling');
  GetOptions
        ("V"                    => \$opt_version,
         "version"              => \$opt_version,
         "L"                    => \$opt_license, 
         "license"              => \$opt_license, 
         "h|?"                  => \$opt_help,
         "help"                 => \$opt_help,
         "H=s"                  => \$opt_hostname, 
         "hostname=s"           => \$opt_hostname, 
         "d=s"                  => \$opt_device, 
         "device=s"             => \$opt_device, 
         "C=s"                  => \$opt_community, 
         "community=s"          => \$opt_community, 
         "w=s"                  => \$opt_warn,
         "warn=s"               => \$opt_warn,
         "c=s"                  => \$opt_crit,
         "crit=s"               => \$opt_crit,
	 "a"			=> \$opt_all,
         );

  if ($opt_license) {
    print_gpl($PROGNAME,$REVISION);
    exit $ERRORS{'OK'};
  }

  if ($opt_version) {
    print_revision($PROGNAME,$REVISION);
    exit $ERRORS{'OK'};
  }

  if ($opt_help) {
    print_help();
    exit $ERRORS{'OK'};
  }

  if ( ! defined($opt_hostname)){
    print "\nERROR: Hostname not defined\n\n";
    print_usage();
    exit $ERRORS{'UNKNOWN'};
  }

  unless (defined $opt_snmpvers) {
    $opt_snmpvers = DEFAULT_SNMPVERS;
  }

  if (($opt_snmpvers ne "1") && ($opt_snmpvers ne "2c")) {
    printf ("\nERROR: SNMP Version %s unknown\n",$opt_snmpvers);
    print_usage();
    exit $ERRORS{'UNKNOWN'};
  }

  unless (defined $opt_warn) {
    $opt_warn = DEFAULT_WARNING;
  }

  unless (defined $opt_crit) {
    $opt_crit = DEFAULT_CRITICAl;
  }

  if ( $opt_crit > $opt_warn) {
    print "\nERROR: parameter -c <crit> greater than parameter -w\n\n";
    print_usage();
    exit ($ERRORS{'UNKNOWN'});
  }

  unless (defined $opt_community) {
    $opt_community = DEFAULT_COMMUNITY;
  }

  if ($opt_all) {
    all_info();
    exit $ERRORS{'OK'};
  }

  if ($opt_device){
     device();
  }

  return $ERRORS{'OK'};
}

# Menu de ayuda

sub print_help {

  print_revision($PROGNAME,$REVISION);
  printf("\n");
  print_usage();
  printf("\n");
  printf("   Check Dinamyc Iface Analyzer\n");
  printf("   e.g: used on linux in net-snmp agent.\n\n");
  printf("-t (--timeout)      Timeout in seconds (default=%d)\n",DEFAULT_TIMEOUT);
  printf("-H (--hostname)     Host to monitor\n");
  printf("-d (--device)       Iface to monitor\n");
  printf("-s (--snmpvers)     SNMP Version [1|2c] (default=%d)\n",DEFAULT_SNMPVERS);
  printf("-C (--community)    SNMP Community (default=%s)\n",DEFAULT_COMMUNITY);
  printf("-p (--port)         SNMP Port (default=%d)\n",DEFAULT_PORT);
  printf("-w (--warn)         Parameter warning\n");
  printf("-c (--crit)         Parameter critical\n");
  printf("-h (--help)         Help\n");
  printf("-V (--version)      Programm version\n");
  printf("-L (--license)      Print license information\n");
  printf("-a        	      Print all info detecte\n");
  printf("\n");
}

sub print_usage {
  print "Usage: $PROGNAME [-h] [-L] [-V] [-C community] [-p port] [-s 1|2c] -a -H hostname -d interface -w <warning> -c <critical>\n\n"; }

sub all_info {
	@n_iface = split(/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifNumber`);
	$count = $n_iface[3];
	while ($count >= 1) {
		@descr  = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifDescr.$count`);
		@speed  = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifSpeed.$count`);
		@mac    = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifPhysAdress.$count`);
		@admin  = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifAdminStatus.$count`);
		@oper   = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOperStatus.$count`);
		@inoct  = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifInOctets.$count`);
		@inerr  = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifInErrors.$count`);
		@outoct = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOutOctets.$count`);
		@outerr = split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOutErrors.$count`);
		print "Ethernet detectada: $descr[3] con una velocidad de $speed[3] con mac $mac[3], admin $admin[3], oper $oper[3]\n";
		print "Entrada de datos usada $inoct[3] con $inerr[3] errores\n";
		print "Salida de datos usada $outoct[3] con $outerr[3] errores\n\n";	
		$count--;
	}
}

sub device{
	
	#print "$opt_device\n";
	@iface_name = split (/\./, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifDescr`);
	@grep_iface_name = grep /$opt_device/, @iface_name;
	@device = split (/\s+/, $grep_iface_name[0]);
	#print "$device[0] - $device[3]";
	@Speed		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifSpeed.$device[0]`);
	@Mac		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifPhysAdress.$device[0]`);
	@Admin		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifAdminStatus.$device[0]`);
	@Oper		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOperStatus.$device[0]`);
	@In		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifInOctets.$device[0]`);
	@Out		= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOutOctets.$device[0]`);
	@ErrorIn	= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifInErrors.$device[0]`);
	@ErrorOut	= split (/\s+/, `snmpwalk -v $opt_snmpvers -c $opt_community $opt_hostname $ifOutErrors.$device[0]`);
	$kb_in		= $In[3] / 1024; 
	$kb_out		= $Out[3] / 1024;
	$mb_in          = $kb_in / 1024;
	$mb_out		= $kb_out / 1024;
	$redondeo_kb_in = sprintf("%.2f",$kb_in);
	$redondeo_kb_out= sprintf("%.2f",$kb_out);
	$redondeo_mb_in = sprintf("%.2f",$mb_in);
        $redondeo_mb_out= sprintf("%.2f",$mb_out);
	print "Dispositivo: $device[3] Datos (redondeados): Entrada $redondeo_mb_in Mb, Salida $redondeo_mb_out Mb|In=$In[3];Out=$Out[3];ErrorIn=@ErrorIn[3];ErrorOut=@ErrorOut[3]\n";
	
}
# Version

sub print_revision {
  print <<EOD

  Copyright (C) 2012 Alejandro Sanchez

  This program comes with ABSOLUTELY NO WARRANTY;
  for details type " -L".
EOD
}


sub print_gpl {
  print <<EOD;
    
  Copyright (C) 2012 Alejandro Sanchez Losa
  email: alejandrosl\@gmail.com
    
  License Information:
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.
 
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
 
  You should have received a copy of the GNU General Public License 
  along with this program; if not, see <http://www.gnu.org/licenses/>. 

EOD

}