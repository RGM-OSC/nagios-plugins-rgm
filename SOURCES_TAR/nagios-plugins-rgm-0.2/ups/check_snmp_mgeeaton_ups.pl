#!/usr/bin/perl -w
# nagios: -epn

#    check_snmp_mgeeaton_ups
#
#    For perl 5.12.0 and higher
#
#    DATE : APRIL 18 2013
#    AUTHOR : Jordi Montanard ( jmontanard at free.fr )
#    THANKS TO : Mohand, for making the script compatible with versions earlier than perl 5.10.0
#
#    LICENCE : GPL - http://www.fsf.org/licenses/gpl.txt
#    
#    Help : ./ check_snmp_mgeeaton_ups.pl -h
#

use strict;
use Net::SNMP;
use Getopt::Long;
use Switch 'Perl6';

my $script = "check_snmp_mgeeaton_ups.pl";
my $Version = '1.3.5';

my $status = 0;
my $returnstring = undef;

# Nagios specific
my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);


my $o_timeout = undef;          # Timeout (Default 5)
my $o_host = undef;
my $o_version = undef;
my $o_verb = undef;
my $o_help = undef;
my $o_option = undef;
my $o_community = undef;
# SNMP Datas

# For UPS MGE MIB Environment Sensor compliant
# see http://download.mgeops.com/emb/66102/mgeops_mib17_ad.mib
# .1.3.6.1.4.1.705.1 = .iso.org.dod.internet.private.enterprises.merlingerin.upsmg

## Management and Configuration groups of the MIB
# upsmgIdent 1
my $oid_upsmgIdentFamilyName = ".1.3.6.1.4.1.705.1.1.1.0";
my $oid_upsmgIdentModelName = ".1.3.6.1.4.1.705.1.1.2.0";
my $oid_upsmgIdentFirmwareVersion = ".1.3.6.1.4.1.705.1.1.4.0";
my $oid_upsmgIdentSerialNumber = ".1.3.6.1.4.1.705.1.1.7.0";

# upsmgManagement 2
# upsmgReceptacle 3
# upsmgConfig 4
## Only for information
my $oid_upsmgConfigLowBatteryTime = ".1.3.6.1.4.1.705.1.4.7.0";     # To set remaining time value for low battery condition
my $oid_upsmgConfigLowBatteryLevel = ".1.3.6.1.4.1.705.1.4.8.0";    # To set remaining level value for low battery condition
my $oid_upsmgConfigVARating = ".1.3.6.1.4.1.705.1.4.12.0";          # The UPS nominal VA rating

#$oid_upsmgConfigEnvironmentTable = ".1.3.6.1.4.1.705.1.4.34."	
#$oid_upsmgConfigEnvironmentEntry = ".1.3.6.1.4.1.705.1.4.34.1."
my $oid_upsmgConfigSensorIndex = ".1.3.6.1.4.1.705.1.4.34.1.1.1";
my $oid_upsmgConfigSensorName = ".1.3.6.1.4.1.705.1.4.34.1.2.1";
my $oid_upsmgConfigTemperatureLow = ".1.3.6.1.4.1.705.1.4.34.1.3.1";
my $oid_upsmgConfigTemperatureHigh = ".1.3.6.1.4.1.705.1.4.34.1.4.1";
my $oid_upsmgConfigHumidityLow = ".1.3.6.1.4.1.705.1.4.34.1.6.1";
my $oid_upsmgConfigHumidityHigh = ".1.3.6.1.4.1.705.1.4.34.1.7.1";


## UPS Monitoring groups of the MIB
# upsmgBattery 5
my $oid_upsmgBatteryRemainingTime = ".1.3.6.1.4.1.705.1.5.1.0";	# sec
my $oid_upsmgBatteryLevel = ".1.3.6.1.4.1.705.1.5.2.0";		# % 
my $oid_upsmgBatteryVoltage = ".1.3.6.1.4.1.705.1.5.5.0";		# dV
my $oid_upsmgBatteryFault = ".1.3.6.1.4.1.705.1.5.9.0";		# 1 = Yes; 2 = no;
my $oid_upsmgBatteryReplacement = ".1.3.6.1.4.1.705.1.5.11.0";	# 1 = Yes; 2 = no;
my $oid_upsmgBatteryLowBattery = ".1.3.6.1.4.1.705.1.5.14.0";	# 1 = Yes; 2 = no;
my $oid_upsmgBatteryChargerFault = ".1.3.6.1.4.1.705.1.5.15.0";	# 1 = Yes; 2 = no;
my $oid_upsmgBatteryLowCondition = ".1.3.6.1.4.1.705.1.5.16.0";	# 1 = Yes; 2 = no;

# upsmgInput 6
my $oid_upsmgInputPhaseNum = ".1.3.6.1.4.1.705.1.6.1.0";		# Number of input phases : 1 or 3

#$oid_upsmgInputPhaseTable  = ".1.3.6.1.4.1.705.1.6.2."		# The table of input phases 
#$oid_upsmgInputPhaseEntry  = ".1.3.6.1.4.1.705.1.6.2.1."	# The description of an input phase

#$oid_upsmgInputVoltage = ".1.3.6.1.4.1.705.1.6.2.1.2."		# The input phase voltage
my $oid_upsmgInputVoltage1 = ".1.3.6.1.4.1.705.1.6.2.1.2.1.0";	# The input phase 1 voltage
my $oid_upsmgInputVoltage2 = ".1.3.6.1.4.1.705.1.6.2.1.2.2.0";        # The input phase 2 voltage
my $oid_upsmgInputVoltage3 = ".1.3.6.1.4.1.705.1.6.2.1.2.3.0";        # The input phase 3 voltage

#$oid_upsmgInputFrequency = ".1.3.6.1.4.1.705.1.6.2.1.3."		# The input phase frequency
my $oid_upsmgInputFrequency1 = ".1.3.6.1.4.1.705.1.6.2.1.3.1.0";	# The input phase 1 frequency
my $oid_upsmgInputFrequency2 = ".1.3.6.1.4.1.705.1.6.2.1.3.2.0";      # The input phase 2 frequency
my $oid_upsmgInputFrequency3 = ".1.3.6.1.4.1.705.1.6.2.1.3.3.0";      # The input phase 3 frequency

my $oid_upsmgInputBadStatus = ".1.3.6.1.4.1.705.1.6.3.0";		# 1 = Yes; 2 = no;
my $oid_upsmgInputLineFailCause = ".1.3.6.1.4.1.705.1.6.4.0";	# 1 = no; 2 = voltage out of tolerance; 3 = frequency out of tolerance; 4 = no voltage at all;


# upsmgOutput 7
my $oid_upsmgOutputPhaseNum = ".1.3.6.1.4.1.705.1.7.1.0";          # Number of output phases : 1 or 3

#$oid_upsmgOutputPhaseTable  = ".1.3.6.1.4.1.705.1.7.2."        # The table of output phases
#$oid_upsmgOutputPhaseEntry  = ".1.3.6.1.4.1.705.1.7.2.1."      # The description of an output phase

#$oid_upsmgOutputVoltage = ".1.3.6.1.4.1.705.1.7.2.1.2."           # The output phase voltage
my $oid_upsmgOutputVoltage1 = ".1.3.6.1.4.1.705.1.7.2.1.2.1";       # The output phase 1 voltage
my $oid_upsmgOutputVoltage2 = ".1.3.6.1.4.1.705.1.7.2.1.2.2";       # The output phase 2 voltage
my $oid_upsmgOutputVoltage3 = ".1.3.6.1.4.1.705.1.7.2.1.2.3";       # The output phase 3 voltage

#$oid_upsmgOutputFrequency = ".1.3.6.1.4.1.705.1.7.2.1.3."         # The output phase frequency
my $oid_upsmgOutputFrequency1 = ".1.3.6.1.4.1.705.1.7.2.1.3.1";     # The output phase 1 frequency
my $oid_upsmgOutputFrequency2 = ".1.3.6.1.4.1.705.1.7.2.1.3.2";     # The output phase 2 frequency
my $oid_upsmgOutputFrequency3 = ".1.3.6.1.4.1.705.1.7.2.1.3.3";     # The output phase 3 frequency

#$oid_upsmgOutputLoadPerPhase = ".1.3.6.1.4.1.705.1.7.2.1.4."      # The output load per phase
my $oid_upsmgOutputLoadPerPhase1 = ".1.3.6.1.4.1.705.1.7.2.1.4.1";  # The output phase 1 load
my $oid_upsmgOutputLoadPerPhase2 = ".1.3.6.1.4.1.705.1.7.2.1.4.2";  # The output phase 2 load
my $oid_upsmgOutputLoadPerPhase3 = ".1.3.6.1.4.1.705.1.7.2.1.4.3";  # The output phase 3 load

my $oid_upsmgOutputOnBattery = ".1.3.6.1.4.1.705.1.7.3.0";		# 1 = Yes; 2 = no;
my $oid_upsmgOutputOnByPass = ".1.3.6.1.4.1.705.1.7.4.0";		# 1 = Yes; 2 = no;
my $oid_upsmgOutputUtilityOff = ".1.3.6.1.4.1.705.1.7.7.0";	# 1 = Yes; 2 = no;
my $oid_upsmgOutputInverterOff = ".1.3.6.1.4.1.705.1.7.9.0";	# 1 = Yes; 2 = no;
my $oid_upsmgOutputOverLoad = ".1.3.6.1.4.1.705.1.7.10.0";		# 1 = Yes; 2 = no;
my $oid_upsmgOutputOverTemp = ".1.3.6.1.4.1.705.1.7.11.0";		# 1 = Yes; 2 = no;


# upsmgEnviron 8
my $oid_upsmgEnvironAmbientTemp = ".1.3.6.1.4.1.705.1.8.1.0";	# dCel
my $oid_upsmgEnvironAmbientHumidity = ".1.3.6.1.4.1.705.1.8.2.0";	# d%

## UPS Controlling groups of the MIB
# upsmgControl 9
# upsmgTest 10
# upsmgTraps 11

# upsmgAgent 12
# For Network Management Card Minislot 66102 & 66103
my $oid_upsmgAgentMibVersion = ".1.3.6.1.4.1.705.1.12.11.0";	# The version of the MIB implemented in agent
my $oid_upsmgAgentFirmwareVersion = ".1.3.6.1.4.1.705.1.12.12.0";	# The agent firmware version

# upsmgRemote 13

my $upsmgIdentFamilyName = undef;
my $upsmgIdentModelName = undef;
my $upsmgIdentFirmwareVersion = undef;
my $upsmgIdentSerialNumber = undef;
my $upsmgConfigLowBatteryTime = undef;
my $upsmgConfigLowBatteryLevel = undef;
my $upsmgConfigVARating = undef;
my $upsmgConfigTemperatureLow = undef;
my $upsmgConfigTemperatureHigh = undef;
my $upsmgConfigHumidityLow = undef;
my $upsmgConfigHumidityHigh = undef;
my $upsmgBatteryRemainingTime = undef;
my $upsmgBatteryLevel = undef;
my $upsmgBatteryVoltage = undef;
my $upsmgBatteryFault = undef;
my $upsmgBatteryReplacement = undef;
my $upsmgBatteryLowBattery = undef;
my $upsmgBatteryChargerFault = undef;
my $upsmgBatteryLowCondition = undef;
my $upsmgInputPhaseNum = undef;
my $upsmgInputVoltage1 = undef;
my $upsmgInputVoltage2 = undef;
my $upsmgInputVoltage3 = undef;
my $upsmgInputFrequency1 = undef;
my $upsmgInputFrequency2 = undef;
my $upsmgInputFrequency3 = undef;
my $upsmgInputBadStatus = undef;
my $upsmgInputLineFailCause = undef;
my $upsmgOutputPhaseNum = undef;
my $upsmgOutputVoltage1 = undef;
my $upsmgOutputVoltage2 = undef;
my $upsmgOutputVoltage3 = undef;
my $upsmgOutputFrequency1 = undef;
my $upsmgOutputFrequency2 = undef;
my $upsmgOutputFrequency3 = undef;
my $upsmgOutputLoadPerPhase1 = undef;
my $upsmgOutputLoadPerPhase2 = undef;
my $upsmgOutputLoadPerPhase3 = undef;
my $upsmgOutputOnBattery = undef;
my $upsmgOutputOnByPass = undef;
my $upsmgOutputUtilityOff = undef;
my $upsmgOutputInverterOff = undef;
my $upsmgOutputOverLoad = undef;
my $upsmgOutputOverTemp = undef;
my $upsmgEnvironAmbientTemp = undef;
my $upsmgEnvironAmbientHumidity = undef;
my $upsmgAgentMibVersion = undef;
my $upsmgAgentFirmwareVersion = undef;

my $oid_sysDescr = ".1.3.6.1.2.1.1.1.0";

###

sub p_version { print "check_snmp_mgeeaton_ups version : $Version\n"; }

sub print_usage {
    print "Usage: $script -H <hostname> -C <snmp_community> -O <option>";
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
        't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
        'O:s'   => \$o_option,          'option:s'      => \$o_option
    ); 
    if (!defined($o_timeout) && !defined($o_verb) && !defined($o_help) && !defined($o_host) && !defined($o_community) && !defined($o_version) && !defined($o_option)) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60)))
       { 
	print "Timeout must be >1 and <60 !\n"; 
	print_usage(); 
	exit $ERRORS{"UNKNOWN"}
    }
    if (!defined($o_timeout)) {$o_timeout=5;}
}

sub help {
    print "SNMP MGE-EATON UPS Monitor for Nagios version ",$Version,"\n";
    print "GPL licence, (c)2011 Jordi Montanard\n\n";
    print_usage();
    print <<EOT;
-H, --hostname=HOST
  name or IP address of host to check
-C, --community=COMMUNITY NAME
  community name for the host's SNMP agent (implies v1 protocol)
-O, --option=OPTION
  only one option among the following list :
     information
     va_rating			* 
     battery_remaining_time
     battery_replacement
     battery_fault
     battery_level
     battery_voltage		*
     battery_low_battery
     battery_charger_fault
     battery_low_condition
     input_voltage		*
     input_frequency		*
     input_line_fail_cause	*
     input_bad_status		*
     output_load
     output_voltage
     output_frequency		*
     output_on_battery
     output_on_by_pass
     output_over_load
     output_over_temp		*
     output_utility_off
     output_inverter_off	*
     ambient_temperature	**
     ambient_humidity		**
     agent_firmware_version	*
     agent_mib_version		*

  *  only with Network Management Card 66102
  ** only with the Environment Sensor 66846 and NMC 66102
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

########### MAIN ##############

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
        verb("Alarm at $TIMEOUT + 5");
        alarm($TIMEOUT+5);
} else {
        verb("no timeout defined : $o_timeout + 10");
        alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session, $error);

# SNMPV1 login
verb("SNMP v1 login");
($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
        -community => $o_community,
        -timeout   => $o_timeout
);

if (!defined($session)) {
        printf("ERROR opening session: %s.\n", $error);
        exit $ERRORS{"UNKNOWN"};
}


        given ($o_option) {
                when "information"              { information(); }
                when "va_rating"                { va_rating(); }
                when "battery_remaining_time"   { battery_remaining_time(); }
                when "battery_level"            { battery_level(); }
                when "battery_replacement"      { battery_replacement(); }
                when "battery_fault"            { battery_fault(); }
                when "battery_voltage"          { battery_voltage(); }
                when "battery_low_battery"      { battery_low_battery(); }
                when "battery_charger_fault"    { battery_charger_fault(); }
                when "battery_low_condition"    { battery_low_condition(); }
                when "input_voltage"            { input_voltage(); }
                when "input_frequency"          { input_frequency(); }
                when "input_line_fail_cause"    { input_line_fail_cause(); }
                when "input_bad_status"         { input_bad_status(); }
                when "output_load"              { output_load(); }
                when "output_voltage"           { output_voltage(); }
                when "output_frequency"         { output_frequency(); }
                when "output_on_battery"        { output_on_battery(); }
                when "output_on_by_pass"        { output_on_by_pass(); }
                when "output_over_load"         { output_over_load(); }
                when "output_over_temp"         { output_over_temp(); }
                when "output_utility_off"       { output_utility_off(); }
                when "output_inverter_off"      { output_inverter_off(); }
                when "ambient_temperature"      { ambient_temperature(); }
                when "ambient_humidity"         { ambient_humidity(); }
                when "agent_firmware_version"   { agent_firmware_version(); }
                when "agent_mib_version"        { agent_mib_version(); }
                else                            { $returnstring = "Option error"; $status = 3; }
        }

$session->close;

if (!defined($returnstring)) { exit $ERRORS{"UNKNOWN"}; }

if ($status == 0) {
    print "$returnstring\n";
    exit $ERRORS{"OK"};
} elsif ($status == 1) {
    print "WARNING - $returnstring\n";
    exit $ERRORS{"WARNING"};
} elsif ($status == 2) {
    print "CRITICAL - $returnstring\n";
    exit $ERRORS{"CRITICAL"};
} else {
    print "UNKNOWN - $returnstring\n";
    exit $ERRORS{"UNKNOWN"};
}
 

####################################################################
# This is where we gather data via SNMP and return results         #
####################################################################

sub va_rating {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        va_rating_test();
    }
}


sub va_rating_test {
    if (!defined($session->get_request($oid_upsmgConfigVARating))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgConfigVARating = $session->var_bind_list()->{$_};
    }
    verb("upsmgConfigVARating OID response : $upsmgConfigVARating");

    $returnstring = "VA rating : $upsmgConfigVARating";
}


sub ambient_temperature {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        ambient_temperature_test();
    }
}


sub ambient_temperature_test {
    agent_firmware_version_test();
    if ($upsmgAgentFirmwareVersion eq "AA" or
        $upsmgAgentFirmwareVersion eq "BA" or
        $upsmgAgentFirmwareVersion eq "CA" or
        $upsmgAgentFirmwareVersion eq "CB" or
        $upsmgAgentFirmwareVersion eq "DA" or
        $upsmgAgentFirmwareVersion eq "EA" or
        $upsmgAgentFirmwareVersion eq "EB" or
        $upsmgAgentFirmwareVersion eq "EC" or
        $upsmgAgentFirmwareVersion eq "EE")
    {
        $upsmgConfigTemperatureLow = 15;
        $upsmgConfigTemperatureHigh = 30;
    } else {
        if (!defined($session->get_request($oid_upsmgConfigTemperatureLow))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgConfigTemperatureLow = $session->var_bind_list()->{$_};
        }
        verb("upsmgConfigTemperatureLow OID response : $upsmgConfigTemperatureLow");

        if (!defined($session->get_request($oid_upsmgConfigTemperatureHigh))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
             $upsmgConfigTemperatureHigh = $session->var_bind_list()->{$_};
        }
        verb("upsmgConfigTemperatureHigh OID response : $upsmgConfigTemperatureHigh");
    }

    if (!defined($session->get_request($oid_upsmgEnvironAmbientTemp))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgEnvironAmbientTemp = $session->var_bind_list()->{$_};
    }
    verb("upsmgEnvironAmbientTemp OID response : $upsmgEnvironAmbientTemp");

    output_over_temp_test();

    $upsmgEnvironAmbientTemp = $upsmgEnvironAmbientTemp / 10;
    $returnstring = "Temperature : $upsmgEnvironAmbientTemp °C";
    if ($upsmgEnvironAmbientTemp <= $upsmgConfigTemperatureLow) { $status = 1; }
    if ($upsmgEnvironAmbientTemp >= $upsmgConfigTemperatureHigh) { $status = 1; }
    if ($upsmgOutputOverTemp == 1) { $status = 2; }
}


sub ambient_humidity {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        ambient_humidity_test();
    }
}


sub ambient_humidity_test {
    agent_firmware_version_test();
    if ($upsmgAgentFirmwareVersion eq "AA" or
        $upsmgAgentFirmwareVersion eq "BA" or
        $upsmgAgentFirmwareVersion eq "CA" or
        $upsmgAgentFirmwareVersion eq "CB" or
        $upsmgAgentFirmwareVersion eq "DA" or
        $upsmgAgentFirmwareVersion eq "EA" or
        $upsmgAgentFirmwareVersion eq "EB" or
        $upsmgAgentFirmwareVersion eq "EC" or
        $upsmgAgentFirmwareVersion eq "EE") 
    {
        $upsmgConfigHumidityLow = 20;
        $upsmgConfigHumidityHigh = 80;
    } else {
        if (!defined($session->get_request($oid_upsmgConfigHumidityLow))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgConfigHumidityLow = $session->var_bind_list()->{$_};
        }
        verb("upsmgConfigHumidityLow OID response : $upsmgConfigHumidityLow");

        if (!defined($session->get_request($oid_upsmgConfigHumidityHigh))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgConfigHumidityHigh = $session->var_bind_list()->{$_};
        }
        verb("upsmgConfigHumidityHigh OID response : $upsmgConfigHumidityHigh");
    }

    if (!defined($session->get_request($oid_upsmgEnvironAmbientHumidity))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgEnvironAmbientHumidity = $session->var_bind_list()->{$_};
    }
    verb("upsmgEnvironAmbientHumidity OID response : $upsmgEnvironAmbientHumidity");

    $upsmgEnvironAmbientHumidity = $upsmgEnvironAmbientHumidity / 10;
    $returnstring = "Humidity : $upsmgEnvironAmbientHumidity %";
    if ($upsmgConfigHumidityLow >= $upsmgEnvironAmbientHumidity) { 
        $status = 1; 
        $returnstring = $returnstring . " - Humidity is below $upsmgConfigHumidityLow %"; 
    }
    if ($upsmgConfigHumidityHigh <= $upsmgEnvironAmbientHumidity) { 
        $status = 1;
        $returnstring = $returnstring . " - Humidity is above $upsmgConfigHumidityHigh %"; 
    }    
}



sub battery_remaining_time {
    if (!defined($session->get_request($oid_upsmgBatteryRemainingTime))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryRemainingTime = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryRemainingTime OID response : $upsmgBatteryRemainingTime");

    if (!defined($session->get_request($oid_upsmgConfigLowBatteryTime))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgConfigLowBatteryTime = $session->var_bind_list()->{$_};
    }
    verb("upsmgConfigLowBatteryTime OID response : $upsmgConfigLowBatteryTime");

    if ((6 * $upsmgConfigLowBatteryTime) >= $upsmgBatteryRemainingTime) { $status = 1; }
    if ((2 * $upsmgConfigLowBatteryTime) >= $upsmgBatteryRemainingTime) { $status = 2; }

    my $heure = int($upsmgBatteryRemainingTime / 3600);
    my $minute = int(($upsmgBatteryRemainingTime - ($heure * 3600)) / 60);
    my $seconde = $upsmgBatteryRemainingTime - ($heure * 3600) - ($minute * 60);

    $returnstring = sprintf "Remaining time : %dh%02dm%02ds", $heure, $minute, $seconde;
}



sub battery_level {
    if (!defined($session->get_request($oid_upsmgBatteryLevel))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryLevel = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryLevel OID response : $upsmgBatteryLevel");

    if (!defined($session->get_request($oid_upsmgConfigLowBatteryLevel))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgConfigLowBatteryLevel = $session->var_bind_list()->{$_};
    }
    verb("upsmgConfigLowBatteryLevel OID response : $upsmgConfigLowBatteryLevel");

    if (((3 * $upsmgConfigLowBatteryLevel) / 2) >= $upsmgBatteryLevel) { $status = 1; }
    if ($upsmgConfigLowBatteryLevel >= $upsmgBatteryLevel) { $status = 2; }
    $returnstring = "Battery level : $upsmgBatteryLevel %";
}


sub battery_voltage {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        battery_voltage_test();
    }
}


sub battery_voltage_test {
    if (!defined($session->get_request($oid_upsmgBatteryVoltage))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryVoltage = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryVoltage OID response : $upsmgBatteryVoltage");

    $upsmgBatteryVoltage = $upsmgBatteryVoltage /10;
    $returnstring = "Battery voltage : $upsmgBatteryVoltage V";
}



sub battery_fault {
    if (!defined($session->get_request($oid_upsmgBatteryFault))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryFault = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryFault OID response : $upsmgBatteryFault");

    if ($upsmgBatteryFault == 1) {
        $status = 2; 
        $returnstring = "Battery fault status";
    }
    $returnstring = "OK";
}



sub battery_replacement {
    if (!defined($session->get_request($oid_upsmgBatteryReplacement))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryReplacement = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryReplacement OID response : $upsmgBatteryReplacement");

    if ($upsmgBatteryReplacement == 1) {
        $status = 2;
        $returnstring = "The UPS battery must be replaced";
    }
    $returnstring = "OK";
}



sub battery_low_battery {
    if (!defined($session->get_request($oid_upsmgBatteryLowBattery))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryLowBattery = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryLowBattery OID response : $upsmgBatteryLowBattery");
    if ($upsmgBatteryLowBattery == 1) {
        $status = 1;
        $returnstring = "The UPS battery is low";
    }
    $returnstring = "OK";
}



sub battery_charger_fault {
    if (!defined($session->get_request($oid_upsmgBatteryChargerFault))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryChargerFault = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryChargerFault OID response : $upsmgBatteryChargerFault");

    if ($upsmgBatteryChargerFault == 1) {
        $status = 2;
        $returnstring = "The UPS battery is not charging";
    }
    $returnstring = "OK";
}



sub battery_low_condition {
    if (!defined($session->get_request($oid_upsmgBatteryLowCondition))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgBatteryLowCondition = $session->var_bind_list()->{$_};
    }
    verb("upsmgBatteryLowCondition OID response : $upsmgBatteryLowCondition");

    if ($upsmgBatteryLowCondition == 1) {
        $status = 2;
        $returnstring = "The UPS is at low condition";
    } else { $returnstring = "OK"; }
}



sub input_phase_num {
    if (!defined($session->get_request($oid_upsmgInputPhaseNum))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputPhaseNum = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputPhaseNum OID response : $upsmgInputPhaseNum");
}


sub input_voltage {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        input_voltage_test();
    }
}


sub input_voltage_test {
    input_phase_num();

    if (!defined($session->get_request($oid_upsmgInputVoltage1))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgInputVoltage1 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputVoltage1 OID response : $upsmgInputVoltage1");

    if (!defined($session->get_request($oid_upsmgInputVoltage2))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputVoltage2 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputVoltage2 OID response : $upsmgInputVoltage2");

    if (!defined($session->get_request($oid_upsmgInputVoltage3))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputVoltage3 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputVoltage3 OID response : $upsmgInputVoltage3");

    $upsmgInputVoltage1 = $upsmgInputVoltage1 / 10;
    $upsmgInputVoltage2 = $upsmgInputVoltage2 / 10;
    $upsmgInputVoltage3 = $upsmgInputVoltage3 / 10;

    if ($upsmgInputPhaseNum == 1) { $returnstring = "Input voltage = $upsmgInputVoltage1 V"; }
    if ($upsmgInputPhaseNum == 3) { $returnstring = "Input 1 voltage = $upsmgInputVoltage1 V - Input 2 voltage = $upsmgInputVoltage2 V - Input 3 voltage = $upsmgInputVoltage3 V"; }
}


sub input_frequency {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        input_frequency_test();
    }
}


sub input_frequency_test {
    input_phase_num();
    if (!defined($session->get_request($oid_upsmgInputFrequency1))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputFrequency1 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputFrequency1 OID response : $upsmgInputFrequency1");

    if (!defined($session->get_request($oid_upsmgInputFrequency2))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputFrequency2 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputFrequency2 OID response : $upsmgInputFrequency2");

    if (!defined($session->get_request($oid_upsmgInputFrequency3))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputFrequency3 = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputFrequency3 OID response : $upsmgInputFrequency3");

    $upsmgInputFrequency1 = $upsmgInputFrequency1 /10;
    $upsmgInputFrequency2 = $upsmgInputFrequency2 /10;
    $upsmgInputFrequency3 = $upsmgInputFrequency3 /10;

    if ($upsmgInputPhaseNum == 1) { $returnstring = "Input frequency = $upsmgInputFrequency1 Hz"; }
    if ($upsmgInputPhaseNum == 3) { $returnstring = "Input 1 frequency = $upsmgInputFrequency1 Hz - Input 2 frequency = $upsmgInputFrequency2 Hz - Input 3 frequency = $upsmgInputFrequency3 Hz"; }
}


sub input_bad_status {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        input_bad_status_test();
    }
}


sub input_bad_status_test {
    if (!defined($session->get_request($oid_upsmgInputBadStatus))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputBadStatus = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputBadStatus OID response : $upsmgInputBadStatus");

    if ($upsmgInputBadStatus == 1) {
        $status = 2;
        $returnstring = "Input is bad";
    } else { $returnstring = "OK"; }

}


sub input_line_fail_cause {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        input_line_fail_cause_test();
    }
}


sub input_line_fail_cause_test {
    if (!defined($session->get_request($oid_upsmgInputLineFailCause))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgInputLineFailCause = $session->var_bind_list()->{$_};
    }
    verb("upsmgInputLineFailCause OID response : $upsmgInputLineFailCause");

        given ($upsmgInputLineFailCause) {
            when "1"    { $returnstring = "OK"; }
            when "2"    { $returnstring = "Voltage out of tolerance"; $status = 1; }
            when "3"    { $returnstring = "Frequency out of tolerance"; $status = 1; }
            when "4"    { $returnstring = "No voltage at all"; $status = 1; }
        }
}



sub output_phase_num {
    if (!defined($session->get_request($oid_upsmgOutputPhaseNum))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputPhaseNum = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputPhaseNum OID response : $upsmgOutputPhaseNum");
}



sub output_voltage {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $oid_upsmgOutputVoltage1 = ".1.3.6.1.4.1.705.1.7.2.1.2.1.0";
        $upsmgAgentFirmwareVersion = "00"; # The upsmqAgentFirmWareVersion doesn't exist for Protection Station UPS
    } else {
        agent_firmware_version_test();
    }
    if (!defined($session->get_request($oid_upsmgOutputVoltage1))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgOutputVoltage1 = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputVoltage1 OID response : $upsmgOutputVoltage1");

    if ($upsmgAgentFirmwareVersion eq "AA" or
        $upsmgAgentFirmwareVersion eq "BA" or
        $upsmgAgentFirmwareVersion eq "CA" or
        $upsmgAgentFirmwareVersion eq "CB" or
        $upsmgAgentFirmwareVersion eq "DA" or
        $upsmgAgentFirmwareVersion eq "EA" or
        $upsmgAgentFirmwareVersion eq "EB" or
        $upsmgAgentFirmwareVersion eq "EC" or
        $upsmgAgentFirmwareVersion eq "EE" or
        $upsmgIdentFamilyName eq "Protection Station") {
        $upsmgOutputVoltage1 = $upsmgOutputVoltage1 / 10;
        $returnstring = "Output phase voltage : $upsmgOutputVoltage1 V";
    }
    else {
        if (!defined($session->get_request($oid_upsmgOutputVoltage2))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputVoltage2 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputVoltage2 OID response : $upsmgOutputVoltage2");

        if (!defined($session->get_request($oid_upsmgOutputVoltage3))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputVoltage3 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputVoltage3 OID response : $upsmgOutputVoltage3");

        $upsmgOutputVoltage1 = $upsmgOutputVoltage1 / 10;
        $upsmgOutputVoltage2 = $upsmgOutputVoltage2 / 10;
        $upsmgOutputVoltage3 = $upsmgOutputVoltage3 / 10;
        $returnstring = "Output phase voltage- phase 1 : $upsmgOutputVoltage1 V, phase 2 : $upsmgOutputVoltage2 V,phase 3 : $upsmgOutputVoltage3 V";    
    }
}

sub output_frequency {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        output_frequency_test();
    }
}

sub output_frequency_test {
    agent_firmware_version_test();
    if (!defined($session->get_request($oid_upsmgOutputFrequency1))) {
            if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgOutputFrequency1 = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputFrequency1 OID response : $upsmgOutputFrequency1");

    if ($upsmgAgentFirmwareVersion eq "AA" or
        $upsmgAgentFirmwareVersion eq "BA" or
        $upsmgAgentFirmwareVersion eq "CA" or
        $upsmgAgentFirmwareVersion eq "CB" or
        $upsmgAgentFirmwareVersion eq "DA" or
        $upsmgAgentFirmwareVersion eq "EA" or
        $upsmgAgentFirmwareVersion eq "EB" or
        $upsmgAgentFirmwareVersion eq "EC" or
        $upsmgAgentFirmwareVersion eq "EE") {
        $upsmgOutputFrequency1 = $upsmgOutputFrequency1 / 10;
        $returnstring = "Output phase frequency : $upsmgOutputFrequency1 Hz";
    }
    else {
        if (!defined($session->get_request($oid_upsmgOutputFrequency2))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputFrequency2 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputFrequency2 OID response : $upsmgOutputFrequency2");

        if (!defined($session->get_request($oid_upsmgOutputFrequency3))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputFrequency3 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputFrequency3 OID response : $upsmgOutputFrequency3");

        $upsmgOutputFrequency1 = $upsmgOutputFrequency1 / 10;
        $upsmgOutputFrequency2 = $upsmgOutputFrequency2 / 10;
        $upsmgOutputFrequency3 = $upsmgOutputFrequency3 / 10;
        $returnstring = "Output load per phase - phase 1 : $upsmgOutputFrequency1 Hz, phase 2 : $upsmgOutputFrequency2 Hz, phase 3 : $upsmgOutputFrequency3 Hz";
    }

}



sub output_load {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $oid_upsmgOutputLoadPerPhase1 = ".1.3.6.1.4.1.705.1.7.2.1.4.1.0";
        $upsmgAgentFirmwareVersion = "00"; # The upsmqAgentFirmWareVersion doesn't exist for Protection Station UPS
    } else {
        agent_firmware_version_test();
    }
    if (!defined($session->get_request($oid_upsmgOutputLoadPerPhase1))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgOutputLoadPerPhase1 = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputLoadPerPhase1 OID response : $upsmgOutputLoadPerPhase1");

    if ($upsmgAgentFirmwareVersion eq "AA" or 
        $upsmgAgentFirmwareVersion eq "BA" or 
        $upsmgAgentFirmwareVersion eq "CA" or 
        $upsmgAgentFirmwareVersion eq "CB" or 
        $upsmgAgentFirmwareVersion eq "DA" or 
        $upsmgAgentFirmwareVersion eq "EA" or 
        $upsmgAgentFirmwareVersion eq "EB" or 
        $upsmgAgentFirmwareVersion eq "EC" or 
        $upsmgAgentFirmwareVersion eq "EE" or
        $upsmgIdentFamilyName eq "Protection Station") {
        $returnstring = "Output load per phase : $upsmgOutputLoadPerPhase1 %";
    }
    else {

        if (!defined($session->get_request($oid_upsmgOutputLoadPerPhase2))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist 1";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputLoadPerPhase2 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputLoadPerPhase2 OID response : $upsmgOutputLoadPerPhase2");

        if (!defined($session->get_request($oid_upsmgOutputLoadPerPhase3))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgOutputLoadPerPhase3 = $session->var_bind_list()->{$_};
        }
        verb("upsmgOutputLoadPerPhase3 OID response : $upsmgOutputLoadPerPhase3");

        $returnstring = "Output load per phase - phase 1 : $upsmgOutputLoadPerPhase1 %, phase 2 : $upsmgOutputLoadPerPhase2 %, phase 3 : $upsmgOutputLoadPerPhase3 %";
    }
}



sub output_on_battery {
    if (!defined($session->get_request($oid_upsmgOutputOnBattery))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputOnBattery = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputOnBattery OID response : $upsmgOutputOnBattery");

    if ($upsmgOutputOnBattery == 1) {
        $status = 2;
        $returnstring = "The UPS is on battery";
    } else { $returnstring = "OK"; }
}



sub output_on_by_pass {
    if (!defined($session->get_request($oid_upsmgOutputOnByPass))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputOnByPass = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputOnByPass OID response : $upsmgOutputOnByPass");

    if ($upsmgOutputOnByPass == 1) {
        $status = 2;
        $returnstring = "The UPS is on by-pass";
    } else { $returnstring = "OK"; }
}



sub output_utility_off{
    if (!defined($session->get_request($oid_upsmgOutputUtilityOff))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputUtilityOff = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputUtilityOff OID response : $upsmgOutputUtilityOff");

    if ($upsmgOutputUtilityOff == 1) {
        $status = 2;
        $returnstring = "The UPS utility is off";
    } else { $returnstring = "OK"; }
}


sub output_inverter_off {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        output_inverter_off_test();
    }
}


sub output_inverter_off_test {
    if (!defined($session->get_request($oid_upsmgOutputInverterOff))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputInverterOff = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputInverterOff OID response : $upsmgOutputInverterOff");

    if ($upsmgOutputInverterOff == 1) {
        $status = 2;
        $returnstring = "The UPS inverter is off";
    } else { $returnstring = "OK"; }
}



sub output_over_load {
    if (!defined($session->get_request($oid_upsmgOutputOverLoad))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputOverLoad = $session->var_bind_list()->{$_};
    }

    verb("upsmgOutputOverLoad OID response : $upsmgOutputOverLoad");
    if ($upsmgOutputOverLoad == 1) {
        $status = 2;
        $returnstring = "The output is over load";
    } else { $returnstring = "OK"; }
}


sub output_over_temp {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        output_over_temp_test();
    }
}


sub output_over_temp_oidtest {
    if (!defined($session->get_request($oid_upsmgOutputOverTemp))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgOutputOverTemp = $session->var_bind_list()->{$_};
    }
    verb("upsmgOutputOverTemp OID response : $upsmgOutputOverTemp");
}



sub output_over_temp_test {
    output_over_temp_oidtest();
    if ($upsmgOutputOverTemp == 1) { 
        $status = 2; 
        $returnstring = "Temperature is over";
    } else {
        $returnstring = "OK";
    }
}


sub agent_mib_version {
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        agent_mib_version_test();
    }
}


sub agent_mib_version_test {
    if (!defined($session->get_request($oid_upsmgAgentMibVersion))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgAgentMibVersion = $session->var_bind_list()->{$_};
    }
    verb("upsmgAgentMibVersion OID response : $upsmgAgentMibVersion");

    $upsmgAgentMibVersion = $upsmgAgentMibVersion / 100;
    $returnstring = "Agent MIB version : $upsmgAgentMibVersion";
}



sub agent_firmware_version_test {
    if (!defined($session->get_request($oid_upsmgAgentFirmwareVersion))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgAgentFirmwareVersion = $session->var_bind_list()->{$_};
    }
    verb("upsmgAgentFirmwareVersion OID response : $upsmgAgentFirmwareVersion");
}



sub agent_firmware_version {
    agent_firmware_version_test();
    ident_family_name();
    if ($upsmgIdentFamilyName eq "Protection Station") {
        $status = 0;
        $returnstring = "SNMP IOD does not exist for Protection Station family";
    } else {
        if ($status == 0) {
            $returnstring = "$upsmgAgentFirmwareVersion";
        }
    }    
}



sub information {
    ident_family_name();
    if (!defined($session->get_request($oid_upsmgIdentModelName))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
    foreach ($session->var_bind_names()) {
        $upsmgIdentModelName = $session->var_bind_list()->{$_};
    }
    verb("upsmgIdentModelName OID response : $upsmgIdentModelName");

    if ($upsmgIdentFamilyName ne "Protection Station") {
        if (!defined($session->get_request($oid_upsmgIdentFirmwareVersion))) {
            if (!defined($session->get_request($oid_sysDescr))) {
                $returnstring = "SNMP agent not responding";
                $status = 1;
                return 1;
            }
            else {
                $returnstring = "SNMP OID does not exist";
                $status = 1;
                return 1;
            }
        }
        foreach ($session->var_bind_names()) {
            $upsmgIdentFirmwareVersion = $session->var_bind_list()->{$_};
        }
        verb("upsmgIdentFirmwareVersion OID response : $upsmgIdentFirmwareVersion");
    }

    if (!defined($session->get_request($oid_upsmgIdentSerialNumber))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgIdentSerialNumber = $session->var_bind_list()->{$_};
    }
    verb("upsmgIdentSerialNumber OID response : $upsmgIdentSerialNumber");

    if ($upsmgIdentFamilyName eq "Protection Station") {
        $returnstring = sprintf "$upsmgIdentFamilyName $upsmgIdentModelName - S/N : $upsmgIdentSerialNumber";
    } else {
        $returnstring = sprintf "$upsmgIdentFamilyName $upsmgIdentModelName - Firmware : $upsmgIdentFirmwareVersion - S/N : $upsmgIdentSerialNumber";
    }
}

sub ident_family_name {
    if (!defined($session->get_request($oid_upsmgIdentFamilyName))) {
        if (!defined($session->get_request($oid_sysDescr))) {
            $returnstring = "SNMP agent not responding";
            $status = 1;
            return 1;
        }
        else {
            $returnstring = "SNMP OID does not exist";
            $status = 1;
            return 1;
        }
    }
     foreach ($session->var_bind_names()) {
         $upsmgIdentFamilyName = $session->var_bind_list()->{$_};
    }
    verb("upsmgIdentFamilyName OID response : $upsmgIdentFamilyName");
}

