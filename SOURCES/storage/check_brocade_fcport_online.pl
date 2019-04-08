#!/usr/bin/perl -w
# check_brocade_fcport is a Nagios plugin to monitor the status of
# a single fc-port on a Brocade (labeled or original) fibre-channel
# switch (eg. IBM 2045 F40).

# Copyright (c) 2009, Christian Thomas Heim <christian.heim@barfoo.org>
#
# This module is free software; you can redistribute it and/or modify it
# under the terms of GNU General Public License (GPL) version 3.

use strict;
use warnings;

use SNMP;
use Nagios::Plugin;
use Nagios::Plugin::Functions;

use vars qw($VERSION $PROGNAME $result $hostname $community);

$VERSION = '0.1';

use File::Basename;
$PROGNAME = basename($0);

my $plugin = Nagios::Plugin->new(
    usage=> "Usage: %s [ -H <host> ] [ -t <timeout> ]
    [ -C|--community=<community> ] [ -P|--fc-port=<fcport-number> ]
    [ -N|--noperformancedata ]",
    version => $VERSION,
    blurb => 'This plugin check the selected FC-port of a Brocade (branded or unbranded) fibrechannel switch',
    extra => "

    Examples:

       $PROGNAME -H 10.0.0.35 -t 20 -C public -P 5
    "
);

$plugin->add_arg(
  spec => 'hostname|H=s',
  help => qq{-H, --hostname=STRING
  Hostname/IP-Adress to use for the check.},
);

$plugin->add_arg(
  spec => 'community|C=s',
  help => qq{-C, --community=STRING
  SNMP community that should be used to access the switch.},
);

$plugin->add_arg(
  spec => 'fcport|P=s',
  help => qq{-P, --fc-port=INTEGER
  Port number as shown in the output of \`switchshow\`.},
);

$plugin->add_arg(
  spec => 'noperformancedata|N',
  help => qq{-N|--noperformancedata
  Don't print performance data of the selected FC port.},
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$plugin->getopts;

unless ( defined $plugin->opts->community ) {
  $plugin->nagios_exit(UNKNOWN, 'No community string supplied' );
}

unless ( defined $plugin->opts->fcport ) {
  $plugin->nagios_exit(UNKNOWN, 'No fibre-channel port supplied' );
}

my $hostname = $plugin->opts->hostname;
my $community = $plugin->opts->community;
my $enable_performance_data;

if ( defined $plugin->opts->noperformancedata ) {
  $enable_performance_data = "false";
} else {
  $enable_performance_data = "true";
}

my $snmpget = sub {
  # $_[0]: OID
  # $_[1]: Message to return in case the OID retrieve fails

  my ( $value, $oid, $msg, $session );

  $oid = "$_[0]";
  $msg = "$_[1]";

  $session = new SNMP::Session( DestHost => $hostname, Community => $community, Version => 1 )
    or nagios_exit(CRITICAL, "Couldn't establish a connection to FC switch.");

  $value = $session->get($oid);
  if ( ! defined $value ) {
    nagios_exit(CRITICAL, "Unable to retrieve $msg value for $oid");
  }

  #$session->close();

  $value =~ s/^(.*)(INTEGER: )+(.*)$/$3/g;
  $value =~ s/\"//g;

  return $value;
};

my $check_port_status = sub {
  # arguments:
  # $_[0]: status check to perform (phy, adm, opr)
  # $_[1]: fc-port number to check on

  my $port_state;

  if ( $_[0] =~ "phy" ) {
    # check the physical port status
    # result values from the switch:
    # 1: noCard,      2: noTransceiver, 3: LaserFault
    # 4: noLight,     5: noSync,        6: inSync,
    # 7: portFault,   8: diagFault,     9: lockRef

    $port_state = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.3.$_[1]", "swFCPortPhyState (fcport $_[1])");
    return $port_state;

  } elsif ( $_[0] =~ "opr" ) {
    # check the operational port status
    # result values from the switch:
    # 0: unknown,    1: online,   2: offline
    # 3: testing,    4: faulty

    $port_state = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.4.$_[1]", "swFCPortOpStatus (fcport $_[1])");

  } elsif ( $_[0] =~ "adm" ) {
    # check the administrative port status
    # result values from the switch:
    # 0: unknown,    1: online,   2: offline
    # 3: testing,    4: faulty

    $port_state = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.5.$_[1]", "swFCPortAdmStatus (fcport $_[1])");
    return $port_state;

  } else {
    $plugin->nagios_exit(UNKNOWN, 'Internal script error');
  }
};

my $get_port_perfdata = sub {
  # arguments:
  # $_[0]: fc-port number for which we need to gather performance data

  # for the output we need the following:
  # stats:
  # stat_wtx (words out), stat_wrx (words in),
  # stat_ftx (frames out), stat_wtx (frames in),
  #
  # errors:
  # er_enc_in (encoding err), er_crc, er_trunc,
  # er_toolong, er_bad_eof, er_bad_eof, er_c3_timeout,
  # er_link_fail, er_loss_sync, er_loss_sig

  my ( $stat_wtx, $stat_wrx, $stat_ftx, $stat_frx );
  my ( $er_enc_in, $er_crc, $er_trunc, $er_toolong );
  my ( $er_bad_eof, $er_enc_out, $er_c3_timeout );
  my ( $er_link_fail, $er_loss_sync, $er_loss_sig );

  $stat_wtx      = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.11.$_[0]", "swFCPortTxWords (fcport $_[0])");
  $stat_wrx      = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.12.$_[0]", "swFCPortRxWords (fcport $_[0])");
  $stat_ftx      = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.13.$_[0]", "swFCPortTxFrames (fcport $_[0])");
  $stat_frx      = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.14.$_[0]", "swFCPortRxFrames (fcport $_[0])");
  $er_enc_in     = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.21.$_[0]", "swFCPortRxEncInFrs (fcport $_[0])");
  $er_crc        = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.22.$_[0]", "swFCPortRxCrcs (fcport $_[0])");
  $er_trunc      = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.23.$_[0]", "swFCPortRxTruncs (fcport $_[0])");
  $er_toolong    = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.24.$_[0]", "swFCPortRxTooLongs (fcport $_[0])");
  $er_bad_eof    = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.25.$_[0]", "swFCPortRxBadEofs (fcport $_[0])");
  $er_enc_out    = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.26.$_[0]", "swFCPortRxEncOutFrs (fcport $_[0])");
  $er_c3_timeout = $snmpget->(".1.3.6.1.4.1.1588.2.1.1.1.6.2.1.28.$_[0]", "swFCPortC3Discards (fcport $_[0])");

  $er_link_fail  = $snmpget->(".1.3.6.1.3.94.4.5.1.39.16.0.0.5.30.52.240.185.0.0.0.0.0.0.0.0.$_[0]", "connUnitPortStatCountLinkFailures (port $_[0])");
  $er_loss_sig   = $snmpget->(".1.3.6.1.3.94.4.5.1.43.16.0.0.5.30.52.240.185.0.0.0.0.0.0.0.0.$_[0]", "connUnitPortStatCountLossofSignal (port $_[0])");
  $er_loss_sync  = $snmpget->(".1.3.6.1.3.94.4.5.1.44.16.0.0.5.30.52.240.185.0.0.0.0.0.0.0.0.$_[0]", "connUnitPortStatCountLossofSynchronization (port $_[0])");

#  print "\$er_link_fail: \"$er_link_fail\"\n";
#  print " \$er_loss_sig: \"$er_loss_sig\"\n";
#  print "\$er_loss_sync: \"$er_loss_sync\"\n";

  my $result = "|stat_wtx=$stat_wtx;0;0;0;0";
  $result .= " stat_wrx=$stat_wrx;0;0;0;0";
  $result .= " stat_ftx=$stat_ftx;0;0;0;0";
  $result .= " stat_frx=$stat_frx;0;0;0;0";
  $result .= " er_enc_in=$er_enc_in;0;0;0;0";
  $result .= " er_crc=$er_crc;0;0;0;0";
  $result .= " er_trunc=$er_trunc;0;0;0;0";
  $result .= " er_toolong=$er_toolong;0;0;0;0";
  $result .= " er_bad_eof=$er_bad_eof;0;0;0;0";
  $result .= " er_enc_out=$er_enc_out;0;0;0;0";
  $result .= " er_c3_timeout=$er_c3_timeout;0;0;0;0";

  return $result;
};

my $fc_port = $plugin->opts->fcport;
$fc_port = $fc_port + 1;
my $port_adm_status = $check_port_status->('adm', $fc_port);
my $port_opr_status = $check_port_status->('opr', $fc_port);
my $port_phy_status = $check_port_status->('phy', $fc_port);
my $port_phy_msg;
my $port_performance_counters;

if ( $enable_performance_data =~ "true" ) {
  $port_performance_counters = $get_port_perfdata->($fc_port);
} else {
  $port_performance_counters = "";
}

my $er_link_fail = $snmpget->(".1.3.6.1.3.94.4.5.1.39.16.0.0.5.30.52.240.185.0.0.0.0.0.0.0.0.$fc_port", "connUnitPortStatCountLinkFailures (port $fc_port)");
# Check the port only if it configured 'UP'
$fc_port = $fc_port - 1;
if ( defined $port_adm_status && $port_adm_status == 1 ) {

  # If the ports operational status isn't 'UP', check further.
  if ( $port_opr_status != 1 ) {

    # Check the physical interface status too
    # makes diagnosing troubles a bit easier.

    if ( $port_phy_status == 1 ) {
      $port_phy_msg = "noCard";
    } elsif ( $port_phy_status == 2 ) {
      $port_phy_msg = "noTransceiver";
    } elsif ( $port_phy_status == 3 ) {
      $port_phy_msg = "LaserFault";
    } elsif ( $port_phy_status == 4 ) {
      $port_phy_msg = "noLight";
    } elsif ( $port_phy_status == 5 ) {
      $port_phy_msg = "noSync";
    } elsif ( $port_phy_status == 7 ) {
      $port_phy_msg = "portFault";
    } elsif ( $port_phy_status == 8 ) {
      $port_phy_msg = "diagFault";
    } elsif ( $port_phy_status == 9 ) {
      $port_phy_msg = "lockRef";
    }

    $plugin->nagios_exit(CRITICAL, "Port 0/$fc_port\'s swFCPortPhyState is $port_phy_msg");
  }

  if ( $port_opr_status == 1 && $port_phy_status == 6 ) {
    $port_phy_msg = "inSync";
  }
  $plugin->nagios_exit(OK, "FC port 0/$fc_port\'s swFCPortPhyState is $port_phy_msg$port_performance_counters");
} elsif ( $port_adm_status == 2 ) {
  $plugin->nagios_exit(CRITICAL, "FC port 0/$fc_port\'s swFCPortAdmStatus is offline");
} elsif ( $port_adm_status == 4 ) {
  $plugin->nagios_exit(CRITICAL, "FC port 0/$fc_port\'s swFCPortAdmStatus is faulty");
}
