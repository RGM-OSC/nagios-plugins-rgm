#!/usr/bin/perl -w
############################################################
# Copyright or © or Copr. Anthony FOIGNANT
#
# antispameu-nagios@yahoo.fr
#
# This software is a computer program whose purpose is to CHECK THE FC
# PORTS STATES OF A BROCADE SWITCH AND RETURN IT TO NAGIOS
# 
# This software is governed by the CeCILL license under French law and
# abiding by the rules of distribution of free software.  You can  use, 
# modify and/ or redistribute the software under the terms of the CeCILL
# license as circulated by CEA, CNRS and INRIA at the following URL
# "http://www.cecill.info". 
#
# As a counterpart to the access to the source code and  rights to copy,
# modify and redistribute granted by the license, users are provided only
# with a limited warranty  and the software's author,  the holder of the
# economic rights,  and the successive licensors  have only  limited
# liability. 
# 
# In this respect, the user's attention is drawn to the risks associated
# with loading,  using,  modifying and/or developing or reproducing the
# software by the user in light of its specific status of free software,
# that may mean  that it is complicated to manipulate,  and  that  also
# therefore means  that it is reserved for developers  and  experienced
# professionals having in-depth computer knowledge. Users are therefore
# encouraged to load and test the software's suitability as regards their
# requirements in conditions enabling the security of their systems and/or 
# data to be ensured and,  more generally, to use and operate it in the 
# same conditions as regards security. 
# 
# The fact that you are presently reading this means that you have had
# knowledge of the CeCILL license and that you accept its terms.
#
##########################################################
# Author : FOIGNANT Anthony
#
# Date : 03/09/2008
#
# check_snmp_FCports_brocade
#
# supported types: Silkworm4900, Connectrix DS-4900B
#
##########################################################
#
# CHANGELOG :
# 1.0 : initial release
# 1.1 : Bug correction on the hostname's verification (Thanks to Sebastian Mueller :)
# 1.2 : Changing the verification of the type of the switch so it could work for a lot of brocade switch
##########################################################

#global variables:
use strict;
use SNMP;
use lib "/usr/local/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);
use Getopt::Long;
use vars qw($opt_h $opt_H $opt_C);
my ( $sess,         $IP,   $COMMUNITY );
my ( $NB_WARNING,   $MSG,  $type );
my ( $ports_number, $port, $FC_oper_port, $FC_adm_status, $FC_phys_status );

$PROGNAME = "check_snmp_FCports_brocade";
sub print_help ();
sub print_usage ();

# options definitions
Getopt::Long::Configure('bundling');
GetOptions(
            "h"           => \$opt_h,
            "help"        => \$opt_h,
            "H=s"         => \$opt_H,
            "hostname=s"  => \$opt_H,
            "C=s"         => \$opt_C,
            "community=s" => \$opt_C,
);

if ($opt_h) {
    print_help();
    exit $ERRORS{OK};
}

# verify the options

$opt_H = shift unless ($opt_H);
print_usage() unless ($opt_H);

# the help :-)
sub print_usage () {
    print "Usage: $PROGNAME -H <host> -C SNMPv1community\n";
    exit(3);
}

sub print_help () {
    print "\n";
    print_usage();
    print "\n";
    print
"The script compares the administrative state and the operationnal status of each FC port of the switch. If administrative status is online, operationnal status must be the same.\n";
    print "-H = IP of the host.\n";
    print "-C = SNMP v1 community string.\n\n";
    support();
}

# verification of parameters of the script
$IP = $1
  if ( $opt_H =~
m/^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z][-a-zA-Z0-9]+(\.[a-zA-Z][-a-zA-Z0-9]+)*)$/
  );
print_usage() unless ($IP);
$COMMUNITY = $opt_C;
print_usage() unless ($COMMUNITY);

# a variable in order to count the number of fault with sensors. if there is more than 2 problems with sensors, the script exists in CRITICAL STATE
$NB_WARNING = 0;

# try to get the type of switch. if it doesn't work, it may be an error in the IP or the Community string
$sess =
  new SNMP::Session( DestHost => $IP, Community => $COMMUNITY, Version => 1 )
  or die
"Unable to connect to $IP ! Please verify the IP or the community string : $COMMUNITY.\n";
$type = $sess->get('.1.3.6.1.2.1.1.1.0');
if ($type) {
	&verify_FCports;
}
else {
    print
"FC ports UNKNOWN : No response from the switch $IP ! Please verify the IP or the community string $COMMUNITY.\n";
    exit $ERRORS{UNKNOWN};
}

##function to verify the isl
sub verify_FCports {

    #get the number of FC ports
    $ports_number = $sess->get('.1.3.6.1.4.1.1588.2.1.1.1.6.1.0');
    if ($ports_number) {
        $ports_number =~ s/^(.*)(INTEGER: )+(.*)$/$3/g;
        $ports_number =~ s/\"//g;
        if ( $ports_number == 0 ) {
            print
              "FC ports UNKNOWN : There is no FC ports configurate on $IP!\n";
            exit $ERRORS{UNKNOWN};
        }
    }
    else {
        print
          "FC ports UNKNOWN : No response for the number of FC ports of $IP!\n";
        exit $ERRORS{UNKNOWN};
    }

    # for a port, get the port number, and the administrative status
    $MSG=" ";
    for ( $port = 1 ; $port <= $ports_number ; $port++ ) {

        # get the administrative status of the port
        $FC_adm_status = $sess->get(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.5.$port");
        $FC_adm_status =~ s/^(.*)(INTEGER: )+(.*)$/$3/g;
        $FC_adm_status =~ s/\"//g;

        # verify that the FC port is active (5)
        # # status results:
        # O unknown (only for operationnal)
        # 1 online
        # 2 offline
        # 3 testing
        # 4 faulty

        # Test only if the administrative status is online
        if ( $FC_adm_status == 1 ) {

            # Get the operationnal status of the port
            $FC_oper_port =
              $sess->get(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.4.$port");
            $FC_oper_port =~ s/^(.*)(INTEGER: )+(.*)$/$3/g;
            $FC_oper_port =~ s/\"//g;
	    
            $port = $port - 1;
	    $MSG = $MSG . "FC port $port has ";
            $port = $port + 1;
            if ( $FC_adm_status != $FC_oper_port ) {
                $NB_WARNING++;
                $MSG = $MSG . "a problem ! ";
	}
	
      # now we try to give more information on the FC port administrative status
                if ( $FC_adm_status == 1 ) {
                    $MSG = $MSG . "Administrative state is online, ";
                }
                elsif ( $FC_adm_status == 2 ) {
                    $MSG = $MSG . "Administrative state is offline, ";
                }
                elsif ( $FC_adm_status == 3 ) {
                    $MSG = $MSG . "Administrative state is testing, ";
                }
                elsif ( $FC_adm_status == 4 ) {
                    $MSG = $MSG . "Administrative state is faulty, ";
                }
                else {
                    $MSG = $MSG
                      . "a problem. Administrative state is impossible to understand, ";
                }

                # do the same with operationnal
                if ( $FC_oper_port == 0 ) {
                    $MSG = $MSG . "Operationnal state is unknown ";
                }
                elsif ( $FC_oper_port == 1 ) {
                    $MSG = $MSG . "Operationnal state is online ";
                }
                elsif ( $FC_oper_port == 2 ) {
                    $MSG = $MSG . "Operationnal state is offline ";
                }
                elsif ( $FC_oper_port == 3 ) {
                    $MSG = $MSG . "Operationnal state is testing ";
                }
                elsif ( $FC_oper_port == 4 ) {
                    $MSG = $MSG . "Operationnal state is faulty ";
                }
                else {
                    $MSG =
                      $MSG . "Operationnal state is impossible to understand ";
                }

                # and we get the Physical state of the FC port
                $FC_phys_status =
                  $sess->get(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3.$port");
                $FC_phys_status =~ s/^(.*)(INTEGER: )+(.*)$/$3/g;
                $FC_phys_status =~ s/\"//g;

                if ( $FC_phys_status == 1 ) {
                    $MSG = $MSG . "and Physical state is noCard.\n";
                }
                elsif ( $FC_phys_status == 2 ) {
                    $MSG = $MSG . "and Physical state is noTransceiver.\n";
                }
                elsif ( $FC_phys_status == 3 ) {
                    $MSG = $MSG . "and Physical state is LaserFault.\n";
                }
                elsif ( $FC_phys_status == 4 ) {
                    $MSG = $MSG . "and Physical state is noLight.\n";
                }
                elsif ( $FC_phys_status == 5 ) {
                    $MSG = $MSG . "and Physical state is noSync.\n";
                }
                elsif ( $FC_phys_status == 6 ) {
                    $MSG = $MSG . "and Physical state is inSync.\n";
                }
                elsif ( $FC_phys_status == 7 ) {
                    $MSG = $MSG . "and Physical state is portFault.\n";
                }
                elsif ( $FC_phys_status == 8 ) {
                    $MSG = $MSG . "and Physical state is diagFault.\n";
                }
                elsif ( $FC_phys_status == 9 ) {
                    $MSG = $MSG . "and Physical state is lockRef.\n";
                }
                else {
                    $MSG =
                      $MSG . "and Physical state is impossible to understand.\n";
                }
        }

    }
}

# return a critical state if there is more than 2 problems with FC ports
if ( $NB_WARNING >= 2 ) {
    print
"FC ports CRITICAL : FC port on switch $IP are NOT HEALTHY. $MSG To check the switch go to: http://$IP\n";
    exit $ERRORS{CRITICAL};
}

# only 1 problem with FC port, just return a Warning state
elsif ( $NB_WARNING == 1 ) {
    print
"FC ports WARNING : there is a problem with a FC Port : $MSG To check the switch go to: http://$IP\n";
    exit $ERRORS{WARNING};
}
else {
    print "FC ports OK : FC Ports on switch $IP are HEALTHY.\n $MSG";
    exit $ERRORS{OK};
}
