#!/usr/bin/perl
###
### -- Nagios plugin for checking HOST-RESOURCES-MIB::hrStorage on remote hosts
###
 
use strict;
use warnings;
use vars qw($VERSION $VERBOSE $PROGNAME $OID_BASE);
use lib "/usr/local/nagios/libexec";
#use utils qw(%ERRORS $TIMEOUT &print_revision);		## - nagios helpers
use utils qw($TIMEOUT %ERRORS &print_revision &support);

use Socket qw(inet_aton);				## - hostname lookup
use Net::SNMP;

if (eval "require oreon" ) {
        use oreon qw(get_parameters create_rrd update_rrd &is_valid_serviceid);
        use vars qw($VERSION %oreon);
        %oreon=get_parameters();
} else {
        print "Unable to load oreon perl module\n";
    exit $ERRORS{'UNKNOWN'};
}



$VERSION	= 2.09;
$PROGNAME	= 'check_disk_snmp';
#$OID_BASE	= '.1.3.6.1.4.1.11.2.3.1';
$OID_BASE	= '.1.3.6.1.4.1.11.2.3.1.2.2.1';
#$OID_BASE2     = '.1.3.6.1.4.1.11.2.3.1.1';
$VERBOSE	= 0;

sub print_version ();
sub print_usage ();
sub print_help ();
sub croak (;$);
sub commify ($);
sub shift_argv ($);
sub lookup_desc ($;$);

my $snmp	= q{};					## - snmp methods
my $resp	= q{};					## - snmp response
my $host	= q{};					## - host address
my $port	= 161;					## - snmp port
my $comm	= 'public';				## - snmp community
my $index	= q{};					## - device index
my $desc	= q{};					## - device description
my $warn	= '85%';				## - warning threshold
my $crit	= '90%';				## - critical threshold
my $state	= q{};					## - nagios state
my $devDesc	= q{};					## - description oid
my $devUnit	= q{};					## - allocation unit oid
my $devSize	= q{};					## - size oid
my $devUsed	= q{};					## - used oid
my $devName	= q{};					## - used oid
my $devBlck	= q{};					## - used oid
my $perc	= 0;					## - percent used
my $free	= 0;					## - free space
my $FreeAlloc   = 0;                                    ## - percent used
my $UsedAlloc   = 0;                                    ## - percent used
my $TotlAlloc   = 0;                                    ## - percent used

my $ssid	= 0;					## - ssid oreon
my %unit_t	= (					## - units table
  'KB'		=> 1 << 10,
  'MB'		=> 1 << 20,
  'GB'		=> 1 << 30,
);
my $unit_desc	= 'MB';					## - unit description
my $unit_sz	= $unit_t{$unit_desc};			## - unit size in bytes

sub print_version () {
###
### -- display plugin revision

  print STDOUT "$PROGNAME $VERSION\n";
}

sub print_usage () {
###
### -- display usage help

  print "\nUsage: ${PROGNAME} -H host_address [-s snmp_community]\n",
             "\t[-p snmp_udp_port] [-d device_description_or_index]\n",
             "\t[-w warning_threshold] [-c critical_threshold]\n",
	     "\n",
	     "\tConvenience abbreviations:\n",
	     "\tUse single letter [A-Z] device description for windows drive\n",
	     "\tUse \"phys\" device_description for \"Physical Memory\"\n",
	     "\tUse \"real\" device_description for \"Real Memory\"\n",
	     "\tUse \"swap\" device_description for \"Swap Space\"\n",
	     "\tUse \"virt\" device_description for \"Virtual Memory\"\n",
	     "\n";
}

sub print_help () {
###
### -- display extended usage help

  #print_revision($PROGNAME, $VERSION);

  print	"\nThis plugin checks the amount of used disk and memory on\n",
	"remote hosts via snmp query of HOST-RESOURCES-MIB::hrStorage\n";

  print_usage;

  print	"Options:\n",
    "  -h\n",
    "\tPrint help detailed help screen\n",
    "  -V\n",
    "\tPrint version information\n",
    "  -H STRING\n",
    "\tDotted decimal IP address or fully qualified domain name of host\n",
    "  -p INTEGER\n",
    "\tUDP port number for SNMP access (default: 161)\n",
    "  -s STRING\n",
    "\tSNMP community string for host (default: public)\n",
    "  -w INTEGER\n",
    "\tExit with WARNING if less than INTEGER units are free\n",
    "  -w PERCENT%\n",
    "\tExit with WARNING if more than PERCENT is used (default: 85%)\n",
    "  -c INTEGER\n",
    "\tExit with CRITICAL if less than INTEGER units are free\n",
    "  -c PERCENT%\n",
    "\tExit with CRITICAL if more than PERCENT is used (default: 90%)\n",
    "  -u STRING\n",
    "\tChoose units: KB, MB, GB or (default: MB)\n",
    "  -d INTEGER\n",
    "\tSNMP index of device to check\n",
    "  -d STRING\n",
    "\tSNMP description of device to check (e.g. /var)\n",
  "\n";

  print	"Examples:\n",
    "  $PROGNAME -H 10.0.2.8 -s mycommunity -w 85% -c 90% -d /var\n",
    "  # Checks space used on /var, warning at 85%, critical at 90%\n\n",
    "  $PROGNAME -H 10.0.2.8 -s mycommunity -w 90% -c 95% -d C\n",
    "  # Checks space used on C:\\ drive, warning at 90%, critical at 95%\n\n",
    "  $PROGNAME -H 10.0.2.8 -s mycommunity -w 1024 -c 512 -d virt\n",
    "  # Checks free \"Virtual Memory\", warning at 1GB, critical at 512MB\n\n",
    "  $PROGNAME -H 10.0.2.8 -s mycommunity\n",
    "  # Gives a table listing of devices available via SNMP\n\n",
  "\n";
}

sub croak (;$) {
###
### -- display error message and exit

  print "$_\n" if $_ = shift; exit $ERRORS{'UNKNOWN'};
}

sub shift_argv ($) {
###
### -- get next command line argument
  
  my $opt	= shift(@_) || return;
  my $arg	= shift(@ARGV);
  
  return $arg if defined($arg);
  croak("CONFIG: missing argument for option: -${opt}");
}

sub commify ($) {
###
### -- pretty print numbers as from the perl cookbook

  my $num	= shift;
  $num		= reverse(sprintf('%u', $num));
  $num		=~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;

  scalar reverse $num;
}

sub lookup_desc ($;$) {
###
### -- lookup snmp device index by description

  my $snmp	= shift || return;
  my $desc	= shift || q{};
  my $query	= join('.', $OID_BASE, '10');
  my $titi	= '.1.3.6.1.4.1.11.2.3.1.2.2.1.10';
  #my $query	= join('.', $OID_BASE, '2.2.1.10');
#print "$query\n";
  my $resp	= $snmp->get_table($titi);
  #my $resp	= $snmp->get_table($query);
  my $index	= q{};
  my $letter	= q{};
  my %table	= ();


  if (!defined($resp)) {
    croak('SNMP query failed');
  }
  if ($desc =~ /^[A-Za-z]$/o) {				## - drive letter?
    $letter	= uc($desc);
    if ($VERBOSE) {
      print "Looking for \"${letter}:\\\" drive\n";
    }
  }
  if ($VERBOSE && $desc && !$letter) {
    print "Finding index for \"$desc\"\n";
  }

  
  foreach (keys %$resp) {
    $index	= substr($_, length($query) + 1);
  
    if ($VERBOSE > 1) {
      print "devDesc $_ => $resp->{$_}\n";
    }
    if (!$desc) {					## - device table list?
      $table{$index} = $resp->{$_};
      next;
    }
    if ($resp->{$_} eq $desc) {				## - device desc match?
      if ($VERBOSE) {
	print "Matched \"$desc\" as index $index\n";
      }
      return $index;
    }
    next unless $letter;
    if ($resp->{$_} =~ /^${letter}:\\/) {		## - drive letter match?
      if ($VERBOSE) {
	print "Matched \"${letter}:\\\" drive as index $index\n";
      }
      return $index;
    }
  }


  if (! $desc) {
    print "\nIndex\tDescription\n=====\t===========\n";
    foreach (sort {$a <=> $b} (keys %table)) {
      print "$_\t$table{$_}\n";
    }
    croak();
  }
  croak("lookup device-id failed: ${desc}");
}

### parse and qualify arguments
###--------------------------------------------------------------------------###

if ($#ARGV == -1) {
  print_usage();
  croak();
}
while($_ = shift(@ARGV)){	
  if ($_ !~ s/^\-//o) {unshift(@ARGV, $_); last}	## - well formed arg?
  if ($_ eq "H") {$host		= shift_argv($_); next}
  if ($_ eq "p") {$port		= shift_argv($_); next}
  if ($_ eq "s") {$comm		= shift_argv($_); next}
  if ($_ eq "w") {$warn		= shift_argv($_); next}
  if ($_ eq "c") {$crit		= shift_argv($_); next}
  if ($_ eq "S") {$ssid		= shift_argv($_); next}
  if ($_ eq "v") {$VERBOSE++;      next}
  if ($_ eq "V") {print_version(); croak()}
  if ($_ eq "h") {print_help();	   croak()}
  if ($_ eq "d") {
    $desc	= shift_argv($_) || q{};
    $desc	= $desc	eq 'real' ? 'Real Memory'	:
		  $desc eq 'phys' ? 'Physical Memory'	:
		  $desc eq 'swap' ? 'Swap Space'	:
		  $desc eq 'virt' ? 'Virtual Memory'	:
		  $desc;
    next;
  }
  if ($_ eq "u") {
    $unit_desc	= shift_argv($_) || q{};
    $unit_desc	= uc($unit_desc);
    if (defined($unit_t{$unit_desc})) {
      $unit_sz	= $unit_t{$unit_desc};
      next;
    }
    croak("unit type $unit_desc not known");
  }
  croak("CONFIG: unknown option -${_}");
}
if ($port !~ /^[0-9]+$/o || $port < 1 || $port > 65535) {
  croak("CONFIG: invalid port number: ${port}");
}
if (! $host)			{croak("CONFIG: missing host address")}
if (! inet_aton($host))		{croak("CONFIG: bad host address: ${host}")}
if ($VERBOSE)			{print "\n"}

### create snmp object
###--------------------------------------------------------------------------###

$snmp		= Net::SNMP->session(
  -hostname	=> $host,
  -port		=> $port,
  -community	=> $comm,
  -timeout	=> int(($TIMEOUT / 3) + 1),
  -retries	=> 2,
  -version	=> 1,
  -nonblocking	=> 0x0
);
if ($VERBOSE) {
  print "HOST\t$host\nPORT\t$port\nCOMM\t$comm\n";
}
if (!defined($snmp)) {
  croak("create snmp session failed: ${!}")
}

if ($desc =~ /^[0-9]+$/o) {
  $index	= $desc;
}
else {

 if ($desc eq 'Swap Space' || $desc eq 'Physical Memory') {
   if ($desc eq 'Swap Space'){
     $devName	= '.1.3.6.1.4.1.11.2.3.1.1.11.0';
     $devBlck 	= '.1.3.6.1.4.1.11.2.3.1.1.12.0';
   }
   else {
   $devName	= '.1.3.6.1.4.1.11.2.3.1.1.7.0';
   $devBlck 	= '.1.3.6.1.4.1.11.2.3.1.1.8.0';
   }
   $resp		= $snmp->get_request(
          -varbindlist => [$devName, $devBlck]
   );
   print $snmp->error() ;
   $snmp->close();
   $perc		= int(100 - ( ($resp->{$devName} / $resp->{$devBlck})  * 100));
   $free		= sprintf("%0.2f",
       ( $resp->{$devName} / 1024 )
   );
   if ($warn =~ /\%$/o || $crit =~ /\%$/o) {
     $warn		=~ s/%$//;
     $crit		=~ s/%$//;
     $state	= $perc >= $crit ? 'CRITICAL' :
  		  $perc >= $warn ? 'WARNING'  :
		  'OK';
   }
   else {
      $state	= $free <= $crit ? 'CRITICAL' :
		  $free <= $warn ? 'WARNING'  :
		  'OK';
   }
   if ($free >= 100) {
     $free		= commify(int($free));
   }
   print "SNMP ${state} - $desc at ${perc}% with ", 
   	 $free, q{ }, $unit_desc, " free\n";




    }
    else {

        $index	= lookup_desc($snmp, $desc);

#  }
#}

### create snmp query
###--------------------------------------------------------------------------###

$devDesc	= join('.', $OID_BASE, '3', $index);
$devUnit	= join('.', $OID_BASE, '4', $index);
$devSize	= join('.', $OID_BASE, '5', $index);
$devUsed	= join('.', $OID_BASE, '6', $index);
$devName	= join('.', $OID_BASE, '10', $index);
$devBlck	= join('.', $OID_BASE, '7', $index);

#$devPhysFre	= join('.', $OID_AUTRE, '7');
#$devPhysTot	= join('.', $OID_AUTRE, '8');
#$devSwapCfg	= join('.', $OID_AUTRE, '10');
#$devSwapEna	= join('.', $OID_AUTRE, '11');
#$devSwapFre	= join('.', $OID_AUTRE, '12');

# free memory         .1.3.6.1.4.1.11.2.3.1.1.7
# tot physical memory .1.3.6.1.4.1.11.2.3.1.1.8
# swap config         .1.3.6.1.4.1.11.2.3.1.1.10
# swap enabled        .1.3.6.1.4.1.11.2.3.1.1.11
# swap free           .1.3.6.1.4.1.11.2.3.1.1.12


if ($VERBOSE) {
  print "Getting information for hrStorage.${index}\n";
}


$resp		= $snmp->get_request(
  -varbindlist => [$devDesc, $devUnit, $devSize, $devUsed, $devName, $devBlck]
);
$snmp->close();


croak("SNMP query failed for device-id: ${index}") if ! defined($resp);
croak("No size returned for device-id: ${index}") if $resp->{$devSize} < 1;
if ($VERBOSE > 1) {
  print "devDesc $devDesc => $resp->{$devDesc}\n",
		"devSize $devSize => $resp->{$devSize}\n",
		"devUsed $devUsed => $resp->{$devUsed}\n",
		"devUnit $devUnit => $resp->{$devUnit}\n"
		;
}
if ($VERBOSE) {
  print "\n";
}

### process snmp response
###--------------------------------------------------------------------------###

##$perc		= int(($resp->{$devUsed} / $resp->{$devSize}) * 100);
$perc		= int(( ($resp->{$devUnit} - $resp->{$devSize}) / $resp->{$devUnit}) * 100);
$free		= sprintf("%0.2f",
  ( ( ($resp->{$devSize} * $resp->{$devBlck} ) / 1024 ) / 1024 )
  #($resp->{$devSize} - $resp->{$devUsed}) / ($unit_sz / $resp->{$devUnit})
);

$FreeAlloc = ($resp->{$devUsed} * 1024);
$UsedAlloc = (($resp->{$devUnit} - $resp->{$devSize}) * 1024);
$TotlAlloc = ($resp->{$devUnit} * 1024);


## pour rrd
my $rrdtot = int( $resp->{$devUnit} * $resp->{$devBlck});
# my $rrdrst = int( $resp->{$devSize} * $resp->{$devBlck});
my $rrdrst = int( $resp->{$devUsed} * $resp->{$devBlck});
my $rrdrst1 = int( $rrdtot - $rrdrst);

#print "$rrdtot $rrdrst1\n";

my $pathtorrdbase = $oreon{GLOBAL}{DIR_RRDTOOL};
my $rrd = $pathtorrdbase.$ssid.".rrd";
my $start=time;
#if (! -e $rrd) {
#  create_rrd ($rrd,2,$start,"300","U","U","GAUGE");
#}
#update_rrd ($rrd,$start,$rrdtot,$rrdrst1);

if ($warn =~ /\%$/o || $crit =~ /\%$/o) {
  $warn		=~ s/%$//;
  $crit		=~ s/%$//;
  $state	= $perc >= $crit ? 'CRITICAL' :
		  $perc >= $warn ? 'WARNING'  :
		  'OK';
}
else {
  $state	= $free <= $crit ? 'CRITICAL' :
		  $free <= $warn ? 'WARNING'  :
		  'OK';
}
if ($free >= 100) {
  $free		= commify(int($free));
}

# changement giusti
#print "SNMP ${state} - $resp->{$devName} ($resp->{$devDesc}) at ${perc}% with ", 
#	 $free, q{ }, $unit_desc, " free\n";

if ($state eq 'CRITICAL') {
  print "Critical value : ${perc}|total=${TotlAlloc}Go used=${UsedAlloc}Go free=${FreeAlloc}Go;;\n";
  #print "Critical value : ${perc}|value=${perc};$warn;$crit;;\n";
}
if ($state eq 'WARNING') {
  print "Warning value : ${perc}|total=${TotlAlloc}Go used=${UsedAlloc}Go free=${FreeAlloc}Go;;\n";
  #print "Warning value : ${perc}|value=${perc};$warn;$crit;;\n";
}
if ($state eq 'OK') {
  print "Ok value : ${perc}|total=${TotlAlloc}Go used=${UsedAlloc}Go free=${FreeAlloc}Go;;\n";
  #print "Ok value : ${perc}|value=${perc};$warn;$crit;;\n";
}




exit $ERRORS{$state};
  }
}

### -- EOF
