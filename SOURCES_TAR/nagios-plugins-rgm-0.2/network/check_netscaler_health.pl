#!/usr/bin/perl -w
# nagios: -epn
# ============================================================================
# ============================== INFO ========================================
# ============================================================================
# Date		: January 7 2013
# Author	: Michael Pagano
# Based on	: "check_snmp_environment.pl" plugin (version 0.7) from Michiel Timmers
# Based on	: "check_snmp_env" plugin (version 1.3) from Patrick Proy
# Licence 	: GPL - summary below
#
# ============================================================================
# ============================== SUMMARY =====================================
# ============================================================================
# The function of this script uses SNMP to check hardware based health
# information contained in Citrix NetScaler Health table nsSysHealthTable.
# This version has been tuned for the NetScaler using the Citrix NetScaler
# SNMP OID Reference - Release 9.3e document. 
#
# The default SNMP version is SNMPv2c because of the use of SNMP Bulk option
# which is more efficient. SNMPv3 also uses SNMP Bulk.
#
# This script supports IPv6. You can use the "-6" switch for this.
#
# ============================================================================
# ============================== SUPPORTED CHECKS ============================
# ============================================================================
# The following check are supported: 
#
# Citrix NetScaler : Fans, Voltages, Temperatures, HA state & SSL engine state.
# Check the http://exchange.nagios.org website for new versions.
# For comments, questions, problems and patches send me an
# e-mail: mike.pagano@allkidslabs.org 
#
# ============================================================================
# ============================== VERSIONS ====================================
# ============================================================================
# version 0.1 : - Citrix: Support for Citrix NetScaler Version 9.3
#    - -f perfdata option implemented. Provides Nagios standard format perfdata.
#    - -v verbose output implemented.  Provides counter by counter details
#         to aid in tuning parameters to your specific needs.
# version 0.2 : - Added "$session->max_msg_size(5000);" to prevent script error.
#	-	CPU Temperature: Added ranges to trigger warning and critical alerts.
#	-	Skips any non-CPU Temperature that returns 0.
#	-	Power Supply Failure Status: Added results with warning and critical alerts.
#	-	Fixed output results to show power supply failure information.
#	-	Added subroutine to preserve highest alert status.
#	-	Verbose output enhanced.
# version 0.2.1: - On 1 of 2 Citrix NetScaler devices had issue where max_msg_size
#	 	greater than 1500 caused error, other NS worked fine with 5000.
#		"ERROR: No response from remote host "X.X.X.X" : UNKNOWN"
#
# ============================================================================
# ============================== LICENCE =====================================
# ============================================================================
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# ============================================================================
# ============================== HELP ========================================
# ============================================================================
# Help : ./check_netscaler_health.pl --help
#
# ============================================================================

use warnings;
use strict;
use Net::SNMP;
use Getopt::Long;
#use lib "/usr/local/nagios/libexec";
#use utils qw(%ERRORS $TIMEOUT);

# ============================================================================
# ============================== NAGIOS VARIABLES ============================
# ============================================================================

my $TIMEOUT 				= 15;	# This is the global script timeout, not the SNMP timeout
my %ERRORS				= ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @Nagios_state 			= ("UNKNOWN","OK","WARNING","CRITICAL"); # Nagios states coding

# ============================================================================
# ============================== OID VARIABLES ===============================
# ============================================================================

# System description 
my $sysdescr				= "1.3.6.1.2.1.1.1";			# Global system description
# Citrix NetScaler
my $citrix_desc     			= "1.3.6.1.4.1.5951.4.1.1.41.7.1.1"; 
my $citrix_value     			= "1.3.6.1.4.1.5951.4.1.1.41.7.1.2"; 
my $citrix_high_availability_state     	= "1.3.6.1.4.1.5951.4.1.1.23.24.0"; 
my @citrix_high_availability_state_text	= ("unknown","init","down","up","partialFail","monitorFail","monitorOk","completeFail","dumb","disabled","partialFailSsl","routemonitorFail");
my $citrix_ssl_engine_state     	= "1.3.6.1.4.1.5951.4.1.1.47.2.0"; 
my @citrix_ssl_engine_state_text	= ("down","up");

# ============================================================================
# ============================== GLOBAL VARIABLES ============================
# ============================================================================

my $Version			= '0.2.1';		# Version number of this script
my $Ver_date		= "1/7/2013";	# Version Date of this script
my $o_host			= undef;	 	# Hostname
my $o_community 	= undef; 		# Community
my $o_port	 		= 161; 			# Port
my $o_help			= undef; 		# Want some help ?
my $o_verb			= undef;		# Verbose mode
my $o_version		= undef;		# Print version
my $o_timeout		= undef;	 	# Timeout (Default 5)
my $o_perf			= undef;		# Output performance data
my $o_version1		= undef;		# Use SNMPv1
my $o_version2		= undef;		# Use SNMPv2c
my $o_domain		= undef;		# Use IPv6
my $o_check_type	= "citrix";		# Default check is "citrix"
my @valid_types		= ("citrix");	
my $o_temp			= undef;		# Max temp
my $o_fan			= undef;		# Min fan speed
my $o_login			= undef;		# Login for SNMPv3
my $o_passwd		= undef;		# Pass for SNMPv3
my $v3protocols		= undef;		# V3 protocol list.
my $o_authproto		= 'sha';		# Auth protocol
my $o_privproto		= 'aes';		# Priv protocol
my $o_privpass		= undef;		# priv password
my $alert_status 	= 0	;			# Alert Status placeholder
my $final_status 	= 0	;			# Alert Status placeholder

# ============================================================================
# ============================== SUBROUTINES (FUNCTIONS) =====================
# ============================================================================

# Subroutine: Print version
sub p_version { 
	print "check_netscaler_health version : $Version $Ver_date\n"; 
}

# Subroutine: Print Usage
sub print_usage {
    print "Usage: $0 [-v] -H <host> [-6] -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -T (citrix) [-F <rpm>] [-c <celcius>] [-f] [-t <timeout>] [-V]\n";
}

# Subroutine: Check number
sub isnnum { # Return true if arg is not a number
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
	return 1;
}

# Subroutine: Set Alert Status
sub set_status { # Return worst status with this order : OK, unknown, warning, critical 
	if ($final_status == 1 && $alert_status != 2) {$alert_status = $final_status;};
	if ($final_status == 2) {$alert_status = $final_status;};
	if ($final_status == 3 && $alert_status == 0) {$alert_status = $final_status;};
	verb("Set Alert Status Sub >> Final Status: ".$final_status." Alert Status:".$alert_status);	
	return $final_status;
}

# Subroutine: Check if SNMP table could be retrieved, otherwise give error
sub check_snmp_result {
	my $snmp_table		= shift;
	my $snmp_error_mesg	= shift;

	# Check if table is defined and does not contain specified error message.
	# Had to do string compare it will not work with a status code
	if (!defined($snmp_table) && $snmp_error_mesg !~ /table is empty or does not exist/) {
		printf("ERROR: ". $snmp_error_mesg . " : UNKNOWN\n");
		exit $ERRORS{"UNKNOWN"};
	}
}

# Subroutine: Print complete help
sub help {
	print "\nCitrix NetScaler Health SNMP plugin for Nagios\nVersion: $Version\nDate: $Ver_date\n\n";
	print_usage();
	print <<EOT;

Options:
-v, --verbose
   Print extra debugging information 
-h, --help
   Print this help message
-H, --hostname=HOST
   Hostname or IPv4/IPv6 address of host to check
-6, --use-ipv6
   Use IPv6 connection
-C, --community=COMMUNITY NAME
   Community name for the host's SNMP agent
-1, --v1
   Use SNMPv1
-2, --v2c
   Use SNMPv2c (default)
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for SNMPv3 authentication 
   If no priv password exists, implies AuthNoPriv 
-X, --privpass=PASSWD
   Priv password for SNMPv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default sha)
   <privproto> : Priv protocole (des|aes : default aes) 
-P, --port=PORT
   SNMP port (Default 161)
-T, --type=citrix (Default)
   Health checks for Citrix NetScaler : Fans, voltages, tempertures (thresholds are hardcoded), HA state, SSL engine state
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   Timeout for SNMP in seconds (Default: 5)
-V, --version
   Prints version number

Notes:
- Check the http://exchange.nagios.org website for new versions.
- For questions, problems and patches send me an e-mail (mike.pagano\@allkidslabs.org).

EOT
}

# Subroutine: Verbose output
sub verb { 
	my $t=shift; 
	print $t,"\n" if defined($o_verb); 
}

# Subroutine: Check Options
sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'		=> \$o_verb,		'verbose'		=> \$o_verb,
		'h'		=> \$o_help,		'help'			=> \$o_help,
		'H:s'	=> \$o_host,		'hostname:s'	=> \$o_host,
		'p:i'	=> \$o_port,		'port:i'		=> \$o_port,
		'C:s'	=> \$o_community,	'community:s'	=> \$o_community,
		'l:s'	=> \$o_login,		'login:s'		=> \$o_login,
		'x:s'	=> \$o_passwd,		'passwd:s'		=> \$o_passwd,
		'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
		'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,   
		't:i'	=> \$o_timeout,		'timeout:i'		=> \$o_timeout,
		'V'		=> \$o_version,		'version'		=> \$o_version,
		'6'		=> \$o_domain,		'use-ipv6'		=> \$o_domain,
		'1'		=> \$o_version1,	'v1'			=> \$o_version1,
		'2'		=> \$o_version2,	'v2c'			=> \$o_version2,
		'f'		=> \$o_perf,		'perfparse'		=> \$o_perf,
		'T:s'	=> \$o_check_type,	'type:s'		=> \$o_check_type,
		'F:i'	=> \$o_fan,			'fan:i'			=> \$o_fan,
		'c:i'	=> \$o_temp,		'celcius:i'		=> \$o_temp
	);

	# Check the -T option
	my $T_option_valid=0; 
	foreach (@valid_types) { 
		if ($_ eq $o_check_type) {
			$T_option_valid=1;
		} 
	}
	if ( $T_option_valid == 0 ) {
		print "Invalid check type (-T)!\n"; 
		print_usage(); 
		exit $ERRORS{"UNKNOWN"};
	}

	# Basic checks
	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) { 
		print "Timeout must be >1 and <60 !\n";
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	}
	if (!defined($o_timeout)) {
		$o_timeout=5;
	}
	if (defined ($o_help) ) {
		help();
		exit $ERRORS{"UNKNOWN"};
	}
	if (defined($o_version)) { 
		p_version(); 
		exit $ERRORS{"UNKNOWN"};
	}
	# check host and filter 
	if ( ! defined($o_host) ) {
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	}
	# Check IPv6 
	if (defined ($o_domain)) {
		$o_domain="udp/ipv6";
	} else {
		$o_domain="udp/ipv4";
	}
	# Check SNMP information
	if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) ){ 
		print "Put SNMP login info!\n"; 
		print_usage(); 
		exit $ERRORS{"UNKNOWN"};
	}
	if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) ){ 
		print "Can't mix SNMP v1,v2c,v3 protocols!\n"; 
		print_usage(); 
		exit $ERRORS{"UNKNOWN"};
	}
	# Check SNMPv3 information
	if (defined ($v3protocols)) {
		if (!defined($o_login)) { 
			print "Put SNMP V3 login info with protocols!\n"; 
			print_usage(); 
			exit $ERRORS{"UNKNOWN"};
		}
		my @v3proto=split(/,/,$v3protocols);
		if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {
			$o_authproto=$v3proto[0];
		}
		if (defined ($v3proto[1])) {
			$o_privproto=$v3proto[1];
		}
		if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
			print "Put SNMP v3 priv login info with priv protocols!\n";
			print_usage(); 
			exit $ERRORS{"UNKNOWN"};
		}
	}
}

# ============================================================================
# ============================== MAIN ========================================
# ============================================================================

check_options();

# Check gobal timeout if SNMP screws up
if (defined($TIMEOUT)) {
	verb("Alarm at ".$TIMEOUT." + ".$o_timeout);
	alarm($TIMEOUT+$o_timeout);
} else {
	verb("no global timeout defined : ".$o_timeout." + 15");
	alarm ($o_timeout+15);
}

# Report when the script gets "stuck" in a loop or takes to long
$SIG{'ALRM'} = sub {
	print "UNKNOWN: Script timed out\n";
	exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if (defined($o_login) && defined($o_passwd)) {
	# SNMPv3 login
	verb("SNMPv3 login");
	if (!defined ($o_privpass)) {
		# SNMPv3 login (Without encryption)
	verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 3,
		-username	=> $o_login,
		-authpassword	=> $o_passwd,
		-authprotocol	=> $o_authproto,
		-timeout	=> $o_timeout
	);  
	} else {
		# SNMPv3 login (With encryption)
	verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 3,
		-username	=> $o_login,
		-authpassword	=> $o_passwd,
		-authprotocol	=> $o_authproto,
		-privpassword	=> $o_privpass,
		-privprotocol	=> $o_privproto,
		-timeout	=> $o_timeout
		);
	}
} else {
	if ((defined ($o_version2)) || (!defined ($o_version1))) {
		# SNMPv2 login
	verb("SNMP v1 login");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 1,
		-community	=> $o_community,
		-port		=> $o_port,
		-timeout	=> $o_timeout
		);
	} else {
		# SNMPv1 login
		verb("SNMP v1 login");
		($session, $error) = Net::SNMP->session(
		-domain		=> $o_domain,
		-hostname	=> $o_host,
		-version	=> 1,
		-community	=> $o_community,
		-port		=> $o_port,
		-timeout	=> $o_timeout
		);
	}
}

# Check if there are any problems with the session
if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	exit $ERRORS{"UNKNOWN"};
}
my $exit_val=undef;

# ============================================================================
# ============================== CITRIX NETSCALER ============================
# ============================================================================

if ($o_check_type eq "citrix") {
	verb("Checking Citrix NetScaler");
	# Define variables
	my $output				= "";			
	my $voltage_output		= "";
	my $powersupply_output	= "";
	my $fan_output			= "";
	my $temp_output			= "";
	my $ha_state_output		= "";
	my $ssl_engine_output	= "";
 	my $ha_state_and_ssl_engine		= "";
	my $result_t;
	my $index;
	my @temp_oid;
	my $using_voltage_threshold;
	my ($num_voltage,$num_voltage_ok,$num_powersupply,$num_powersupply_ok,$num_fan,$num_fan_ok,$num_temp,$num_temp_ok)=(0,0,0,0,0,0,0,0);
	my $perf_output			= "\n";
	my $perf_outtmp			= " | ";
	my $ps_alert 			= "";

	# Get SNMP table(s) and check the result
	verb("Get SNMP Tables");
	# See version notes about max_msg_size.
	$session->max_msg_size(5000);
	my $resultat_status 		=  $session->get_table(Baseoid => $citrix_desc);
	&check_snmp_result($resultat_status,$session->error);
	my $resultat_value 		=  $session->get_table(Baseoid => $citrix_value);
	&check_snmp_result($resultat_value,$session->error);
	verb("Getting result ok.");
	if (defined($resultat_status))
	{	
	verb("Start of Loop >>>>>>>>>>>>>");
		foreach my $key ( keys %$resultat_status) 
		{
			if ($key =~ /$citrix_desc/) 
			{	my $reported_counter_name = $$resultat_status{$key};
				$using_voltage_threshold = 0;
				$index = $key;
				$index =~ s/^$citrix_desc.//;
				my $reported_counter_value = $$resultat_value{$citrix_value.".".$index};

	# Thresholds are hardcoded and are based on the "Citrix NetScaler SNMP OID Reference - Release 9.3" document. 
	# If a threshold for a specific component is not available in this document then a logical threshold has been picked.
	verb("Top of Loop >>>>>>>>>>>>");	
				$final_status = 0;
				if ($reported_counter_name =~ /Voltage/ )
				{	
					#print "Voltage ($reported_counter_name) = $reported_counter_value \n";
					$num_voltage++; 	
					# Measures the +5V power supply in millivolt. Reference Value 4500 - 5500 mv.
					if ($reported_counter_name =~ /\+5.0VSupplyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 4500 ) && ($reported_counter_value < 5500))  
						{$num_voltage_ok++}
						else 
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";
	verb("+5V Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}
					# Measures the +12V power supply in millivolt. Reference Value 10800 - 13200 mv.
					if ($reported_counter_name =~ /\+12.0VSupplyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 10800 ) && ($reported_counter_value < 13200))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}	
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";
	verb("+12V Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the -5V power supply in millivolt. Reference Value -5500 - -4500 mv.
					if ($reported_counter_name =~ /\-5.0VSupplyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > -5500 ) && ($reported_counter_value < -4500))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": "; 
							$voltage_output.= $reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("-5V Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the -12V power supply in millivolt. Reference Value -13200 - -10800 mv.
					if ($reported_counter_name =~ /\-12.0VSupplyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > -13200 ) && ($reported_counter_value < -10800))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("-12V Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the +3.3V main and standby power supply in millivolt. Reference Value 2970 - 3630 mv.
					if ($reported_counter_name =~ /3.3VSupplyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 2970 ) && ($reported_counter_value < 3630))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("+3.3V Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the +5V standby power supply in millivolt. Reference Value 4500 - 5500 mv.
					if ($reported_counter_name =~ /PowerSupply5vStandbyVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 4500 ) && ($reported_counter_value < 5500))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("+5V Standby Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the processor core voltage in millivolt. Reference Value 1080 - 1650 mv.
					if ((($reported_counter_name =~ /CPU/) && ($reported_counter_name =~ /CoreVoltage/)) or ($reported_counter_name =~ /VoltageSensor/ ))
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 1045 ) && ($reported_counter_value < 1650))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("Processor Voltage Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

					# Measures the battery voltage in millivolt. Reference Value Platform dependant.  Set range close to current value.
					if ($reported_counter_name =~ /BatteryVoltage/ )
					{	$using_voltage_threshold = 1;
						if (($reported_counter_value > 2800 ) && ($reported_counter_value < 3500))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("Battery Voltage Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

                   	# If no defined voltage description is found, uses the following thresholds.
					if ($using_voltage_threshold == 0)
					{	if (($reported_counter_value > 1000 ) && ($reported_counter_value < 6000))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", ";}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("No Defined Voltage>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}
				}

				# Intel CPU Power check. Measures the processor core voltage in millivolt.
				# Documentation has no reference values. Used range from processor core voltage.
				if ($reported_counter_name =~ /IntelCPUVttPower/ )
					{	$num_voltage++;				
						if (($reported_counter_value > 1040 ) && ($reported_counter_value < 1650))
						{$num_voltage_ok++}
						else
						{	if ($voltage_output ne "") {$voltage_output.=", "}
							$voltage_output.= "(" .$reported_counter_name.": ".$reported_counter_value." mV)";
							$final_status = 2;
						}
					$perf_outtmp.= $reported_counter_name."=".($reported_counter_value/1000).", ";						
	verb("Intel CPU Power Check>> ".$reported_counter_name.": ".$reported_counter_value."mV, num_voltage_ok: ".$num_voltage_ok."/".$num_voltage.", Status: ".$final_status);
					}

				# Power Supply check. Values are NORMAL = 0 ; NOT PRESENT = 1 ; FAILED = 2 ; NOT SUPPORTED = 3.
				# Tune $final_status to meet your desired Alert level 0, 1, 2 or 3.
				if (($reported_counter_name =~ /PowerSupply/) && ($reported_counter_name =~ /FailureStatus/)) 
				{	$num_powersupply++;
					if ($reported_counter_value == 0)
					{$num_powersupply_ok++}
					else
					{	if ($reported_counter_value == 1)
						{$final_status = 1;$ps_alert = "Not Present"}
						if ($reported_counter_value == 2 )
						{$final_status = 2;$ps_alert = "Failure"}						
						if ($reported_counter_value == 3 )
						{$final_status = 1;$ps_alert = "Not Supported"}						
						if ($powersupply_output ne "") {$powersupply_output.=", "}
						$powersupply_output.= "(".$reported_counter_name.": ".$ps_alert.")";
					}
	verb("Power Supply Check>> ".$reported_counter_name.": ".$reported_counter_value.", num_powersupply_ok: ".$num_powersupply_ok."/".$num_powersupply.", Status: ".$final_status);
				}
				# Fan speed threshold in RPM. Documentation is not clear about the thresholds.
				# Found issue where fan result is 0, skipping to prevent false error.
				if ($reported_counter_name =~ /Fan/ ) 
				{	if ($reported_counter_value != 0 )
					{	$num_fan++;
						if (($reported_counter_value > 5000 ) && ($reported_counter_value < 15000))
						{$num_fan_ok++}
						else
						{	if ($fan_output ne "") {$fan_output.=", ";}
							$fan_output.= "(" .$reported_counter_name.": ".$reported_counter_value." RPM)";
							$final_status = 2;
						}
					}
				$perf_outtmp.= $reported_counter_name."=".$reported_counter_value.", ";
	verb("Fan Check>> ".$reported_counter_name.": ".$reported_counter_value." RPM, num_fan_ok: ".$num_fan_ok."/".$num_fan.", Status: ".$final_status);
				}

				# CPU Temperatures
				# It looks like Citrix NetScaler devices are based on Intel XEON processors. 
				# Most of them appear to have a maximum operation temperature of 75 degrees Celsius.
				# Found wide range of possible values.  Values should be adjusted to suit your environment.
				if (($reported_counter_name =~ /CPU/ ) && ($reported_counter_name =~ /Temperature/ ))
				{	$num_temp++;
					if (($reported_counter_value > 35) && ($reported_counter_value < 81))
					{$num_temp_ok++}
					else
					{	if ($reported_counter_value > 82 && $reported_counter_value < 88)
						{$final_status = 1}
						else {$final_status = 2}
						if ($temp_output ne "") {$temp_output.=", ";}
						$temp_output.= "(" .$reported_counter_name.": ".$reported_counter_value." Celsius)";
					}
				$perf_outtmp.= $reported_counter_name."=".$reported_counter_value.", ";					
	verb("CPU Temp Check>> ".$reported_counter_name.": ".$reported_counter_value."C, num_temp_ok: ".$num_temp_ok."/".$num_temp.", Status: ".$final_status);
				}

				# Temperature sensors other than CPU in degrees Celsius.
				# Internal & Auxiliary temperatures have no defined threshold in documentation.
				# Values should be adjusted to suit your environment.
				# Found issue where temperature result is 0, skipping to prevent false error.
				if (($reported_counter_name =~ /Temperature/ ) && ($reported_counter_name !~ /CPU/ ))
				{	if ($reported_counter_value != 0 )				
					{	$num_temp++;
						if (($reported_counter_value > 20 ) && ($reported_counter_value < 42))
						{$num_temp_ok++}
						else
						{	if ($temp_output ne "") {$temp_output.=", ";}
						$temp_output.= "(" .$reported_counter_name.": ".$reported_counter_value." Celsius)";
						$final_status = 2;
						}
					}
				$perf_outtmp.= $reported_counter_name."=".$reported_counter_value.", ";
	verb("Int-Aux Temp Check>> ".$reported_counter_name.": ".$reported_counter_value."C, num_temp_ok: ".$num_temp_ok."/".$num_temp.", Status: ".$final_status);
				}	

			if ($final_status != 0){set_status()};
	verb("Bottom of Loop >>>>>>\n");
			}
		}
	verb("End of Loop >>>>>>>>>>>>>>>>>>>>>");
		

		if ($voltage_output ne "") {$voltage_output.=", ";}
		if ($powersupply_output ne "") {$powersupply_output.=", ";}
		if ($fan_output ne "") {$fan_output.=", ";}
		if ($temp_output ne "") {$temp_output.=", ";}
	}

	# Clear the SNMP Transport Domain and any errors associated with the object.
	$session->close;
	
	verb("End of Get SNMP Tables Session\nProcess Output Data");
	
	if ($num_voltage==0 && $num_fan==0 && $num_temp==0)
	{	print "No power/fan/temp found : UNKNOWN\n";
		exit $ERRORS{"UNKNOWN"};
	}

	$output = $voltage_output . $powersupply_output . $fan_output . $temp_output ;
	if ($output ne "") {$output.=" : ";}

	verb("Power Supply Check");
	if ($num_powersupply!=0) {
		if ($num_powersupply == $num_powersupply_ok) {
		$output.= $num_powersupply . " powersupply OK, ";
		} else {
		verb("Powers Supply Error: ".$powersupply_output);
		$output.= $num_powersupply_ok . "/" . $num_powersupply ." powersupply OK, ";
		}
	}

	verb("Voltage Check");
	if ($num_voltage!=0) {
		if ($num_voltage == $num_voltage_ok) {
		$output.= $num_voltage . " voltage OK, ";
		} else {
		verb ("Voltage Error: ".$voltage_output);
		$output.= $num_voltage_ok . "/" . $num_voltage ." voltage OK, ";
		}
	}

	verb("Fan Check");
	if ($num_fan!=0) {
		if ($num_fan == $num_fan_ok) {
		$output.= $num_fan . " fan OK, ";
		} else {
		verb("Fan Error: ".$fan_output);
		$output.= $num_fan_ok . "/" . $num_fan ." fan OK, ";
		}
	}

	verb("Temperatures Check");
	if ($num_temp!=0) {
		if ($num_temp == $num_temp_ok) {
		$output.= $num_temp . " temp OK";
		} else {
		verb("Temperatures Error: ".$temp_output);
		$output.= $num_temp_ok . "/" . $num_temp ." temp OK";
		}
	}

	$output.= $ha_state_and_ssl_engine;

	# If -f option is used display perfdata.
	if (defined($o_perf)) {
		$perf_output = $perf_outtmp."\n";
	verb ("-f Perfdata requested");
	}
	
	# Show results and alert status.
	verb("Output Results\n\n");
	
	if ($alert_status == 3) {
		print $output," : UNKNOWN".$perf_output;
		exit $ERRORS{"UNKNOWN"};
	}
	
	if ($alert_status == 2) {
		print $output," : CRITICAL".$perf_output;
		exit $ERRORS{"CRITICAL"};
	}

	if ($alert_status == 1) {
		print $output," : WARNING".$perf_output;
		exit $ERRORS{"WARNING"};
	}
	
	print $output," : OK".$perf_output;
	exit $ERRORS{"OK"};
}

# ============================================================================
# ============================== NO CHECK DEFINED ============================
# ============================================================================

print "Unknown check type : UNKNOWN\n";
exit $ERRORS{"UNKNOWN"};




