#!/usr/bin/perl

# Original version written by ken.mckinlay@curtisswright.com
# Parameter checks and SNMP v3 based on code by Christoph Kron
# and S. Ghosh (check_ifstatus)
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
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# (above directly taken from Ken's original script
# This version was created by Erik Welch (ewelch@taos.com)
# Many of the concepts were created by Ken, I just redid the logic and
# made it so I only had to edit one location to add a new variable to check
# Bugs and updates can be sent to me.
# I have not tested any of the snmp v2c or v3 functions
# they may be horribly broken or implemented badly, I redid some of Ken's
# logic to fit my simple mind, but haven't utilized it yet...
#
# Wed  6 Aug 2008 15:46:14 BST
# James Beal (james_@catbus.co.uk)
# 
# I have added support for 64 bit values allowing greater than 2Gig volumes
# I emailed this to Erik and he was happy that I release it, I am sure either
# or us will be happy to try and maintain it.
# As it walks a large part of the tree it is searching for values its pretty 
# Inefficant and our Nagios person has disabled it on our system until I make
# it more efficant, Hi Pete :) 
#
# $Id: check_netapp2,v 2.3 2006/06/05 19:04:05 root Exp $
use warnings;
use strict;
use lib "/usr/local/nagios/libexec";
use utils qw/$TIMEOUT %ERRORS &print_revision &support/;
use Net::SNMP;
use Getopt::Long;
use constant KB_PER_MB => 1024;
use constant KB_PER_GB => KB_PER_MB*KB_PER_MB;
use constant OK => 'OK';
use constant WARNING => 'WARNING';
use constant CRITICAL => 'CRITICAL';
use constant UNKNOWN => 'UNKNOWN';
Getopt::Long::Configure('bundling');

my $PROGNAME = $0;
my $PROGREVISION = '3.0';
my %stats2chk;

##########
#I don't recommend editing the following vars
##########
my $state = UNKNOWN;
my $maxmsgsize = 1472; #Net::SNMP default
my $port = 161;
my $result;            #connection to Net::SNMP result
##########
#Editable variables
##########
my %opts = (
  'snmp_version' => 1,
  'community' => 'public',
  'timeout' => $TIMEOUT,
  'port' => 161,
);

%stats2chk = (
    #Primary key:
    #The variable name from the command line
    #Secondary keys:
    #oid is the base oid to be monitored
    #answer string to pass to sprintf (Status Information)
    #perfdata string to pass to sprintf (Performance Data)
    #help string that is used in the help output (-h)
    #
    #if you have a specialized routine to process the data you get from
    #the oid use the "sub" key
    #sub name of the key in the special_subs hash
    #  this was the only way I could reference a sub without it calculating
    #  the sub...
    #other secondary keys (I would recommend naming similar to subopts)
    #can be created as needed. Use DISKUSED as an example
    'FAILEDDISK' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.6.4.7',
        'answer' => 'Disks failed: %d',
        'perfdata' => 'faileddisk=%d',
        'help' => '%s - disk failed state',
      },
    'FAN' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.4.2',
        'answer' => 'Fans failed: %d',
        'perfdata' => 'failedfans=%d',
        'help' => '%s - fan failed state',
      },
    'PS' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.4.4',
        'answer' => 'Power supplies failed: %d',
        'perfdata' => 'failedpowersupplies=%d',
        'help' => '%s - Power Supply failed state',
      },
    'UPTIME' =>
      { 'oid' => '.1.3.6.1.2.1.1.3',
        'answer' => 'System uptime: %s',
        'perfdata' => 'uptime=%s',
        'help' => '%s - up time',
      },
    'CPULOAD' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.1.3',
        'answer' => 'CPU load: %d%%',
        'perfdata' => 'cpuload=%d%%',
        'help' => '%s - CPU load',
      },
    'CACHEAGE' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.2.23',
        'answer' => 'Cache Age: %d',
        'perfdata' => 'cache_age=%d',
        'help' => '%s - Cache Age',
      },
    'CPTIME' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.6.6',
        'answer' => 'Cp Full  Time: %d',
        'perfdata' => 'cp_full_time=%dc',
        'help' => '%s - Consistency Full Time',
      },
    'CPBACK' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.6.7',
        'answer' => 'Cp Back Time: %d',
        'perfdata' => 'cp_back_time=%dc',
        'help' => '%s - Back to Back Consistency Time',
      },
    'GLOBALSTATUS' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.2.4',
        'answer' => 'Global Status: %d',
        'perfdata' => 'globalstatus=%d',
        'help' => '%s - Global Status',
      },

    'NDMPSESSIONS' =>
      { 'oid' => '1.3.6.1.4.1.789.1.10.2',
        'answer' => 'NDMP Sessions: %d',
        'perfdata' => 'ndmpsessions=%d',
        'help' => '%s - NDMP Sessions',
      },
    'TEMP' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.4.1',
        'answer' => 'Over temperature: %s',
        'perfdata' => 'overtemperature=%s',
        'help' => '%s - over temperature check',
      },
    'NVRAM' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.2.5.1',
        'answer' => 'NVRAM battery status: %d',
        'perfdata' => 'nvrambatterystatus=%d',
        'help' => '%s - nvram battery status',
      },
    'SNAPSHOT' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.5.8',
        'answer' => '%s Snapshots disabled',
        'perfdata' => '',
        'help' => '%s - volume snapshot status',
        'sub' => 'check_oidvals',
        'subopts' => [".1.3.6.1.4.1.789.1.5.8",".1.2",".1.7"],
      },
    'DISKUSED' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.5.4.1',
        'answer' => 'Kb Used : %d',
        'perfdata' => '%s',
        'help' => '%s - disk space avail',
        'sub' => 'check_oidvals',
        'subopts' => [".1.3.6.1.4.1.789.1.5.4.1",".2",".5"],
        'subminval' => 30*KB_PER_GB, #GBytes
        'subskip' => "snapshot", #skip volumes with this at the end of name
      },
    'DISKUSED64' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.5.4.1',
        'answer' => 'Kb used : %d',
        'perfdata' => 'du_%s = %d',
        'help' => '%s - disk space avail',
        'sub' => 'check_oidvals_64',
        'subopts' => [".1.3.6.1.4.1.789.1.5.4.1",".2",".16",".17"],
        'subminval' => 0, #GBytes
        'subskip' => "snapshot", #skip volumes with this at the end of name
      },
    'PERINODE' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.5.4.1',
        'answer' => 'Percent Inode : %d',
        'perfdata' => 'percent_inode_%s = %d%%',
        'help' => '%s - percentage inode space avail',
        'sub' => 'check_oidvals_64',
        'subopts' => [".1.3.6.1.4.1.789.1.5.4.1",".2","NONE",".9"],
        'subminval' => 0, #GBytes
        'subskip' => "snapshot", #skip volumes with this at the end of name
      },
    'PERUSED' =>
      { 'oid' => '.1.3.6.1.4.1.789.1.5.4.1',
        'answer' => 'Percent Used : %d',
        'perfdata' => 'percent__%s = %d%%',
        'help' => '%s - percentage  space used',
        'sub' => 'check_oidvals_64',
        'subopts' => [".1.3.6.1.4.1.789.1.5.4.1",".2","NONE",".6"],
        'subminval' => 0, #GBytes
        'subskip' => "snapshot", #skip volumes with this at the end of name
      },
    'NETRCVD' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Recieved : %d',
        'perfdata' => 'Bytes_Recieved = %dc',
        'help' => '%s - Net In',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".11",".12"],
      },
    'NETSENT' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Sent : %d',
        'perfdata' => 'Bytes_Sent = %dc',
        'help' => '%s - Net Out',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".13",".14"],
      },
    'DISKREAD' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Disk Read : %d',
        'perfdata' => 'Bytes_Disk_Read = %dc',
        'help' => '%s - Bytes Disk Read',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".15",".16"],
      },
    'DISKWRITE' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Disk Write : %d',
        'perfdata' => 'Bytes_Disk_Write = %dc',
        'help' => '%s - Bytes Disk Write',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".17",".18"],
      }, 
    'TAPEREAD' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Tape Read : %d',
        'perfdata' => 'Bytes_Tape_Read = %dc',
        'help' => '%s - Bytes Tape Read',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".19",".20"],
      },
    'TAPEWRITE' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'Bytes Tape Write : %d',
        'perfdata' => 'Bytes_Tape_Write = %dc',
        'help' => '%s - Bytes Tape Write',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".21",".22"],
      },
    'NFSOPS' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'NFS OPS : %d',
        'perfdata' => 'nfs_ops = %dc',
        'help' => '%s - NFS Operations',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".5",".6"],
      },
    'CIFSOPS' =>
      { 'oid' => '1.3.6.1.4.1.789.1.2.2',
        'answer' => 'CIFS OPS : %d',
        'perfdata' => 'cifs_ops = %dc',
        'help' => '%s - CIFS  Operations',
        'sub' => 'check_oidvals_64',
        'subopts' => ["1.3.6.1.4.1.789.1.2.2","NONE",".7",".8"],
      },
   );
##########
sub usage {
  #prints usage and dies
  print <<EOU;
  Missing or incorrect arguments!

  (SNMP v1, v2c)
  $PROGNAME -H ip_address -v variable
      [ -P snmp_version ] [ -c community ] [ -p port_number ]

  (SNMP v3)
  $PROGNAME -H ip_address -v variable -L sec_level -U sec_name
      [ -w warn_range ]  [ -c crit_range ]  [ -c community ] [ -t timeout ]
      [ -p port_number ] [ -P 3 ] [ -a auth_proto ]
      [ -A auth_passwd ] [ -X priv_passwd ] [-o volume ]

  $PROGNAME -h, --help

EOU
  support();
  exit $ERRORS{UNKNOWN};
}

sub print_help {
  #prints more usage info and dies
  print <<EOH;
  check_netapp plugin for Nagios monitors the status of a NetApp system

  Usage:
    -H, --hostname
      hostname to query (required)
    -C, --community
      SNMP read community (defaults to public)
    -t, --timeout
      seconds before the plugin times out (default=$TIMEOUT)
    -p, --port
      SNMP port (default 161)
    -P, --snmp_version
      1 for SNMP v1 (default),
      2 for SNMP v2c
      3 for SNMP v3 (requires -U & -L)
    -L, --seclevel
      "noAuthNoPriv"
      "authNoPriv" (requires -a & -A)
      "authpriv"   (requires -a -x & -A)
    -U, --secname
      user name for SNMPv3 context
    -a, --authproto
      authentication protocol (MD5 or SHA1)
    -A, --authpass
      authentication password
    -X, --privpass
      privacy password in hex with 0x prefix generated by snmpkey
    -V, --version
      plugin version
    -w, --warning
      warning level
    -c, --critical
      critical level
    -o, --volume
      volume to query (defaults to all)
    -h, --help
      usage help
    -v, --variable
      variable to query, can be:
EOH
  #print the help line from the %stats2chk hash
  for (sort keys %stats2chk) { printf "\t$stats2chk{$_}{'help'}\n", $_ }
  print "\n";
  print_revision($PROGNAME,"\$Revision: 3.0 $PROGREVISION\$");
  exit $ERRORS{UNKNOWN};
}

#the specialized subs that may bee needed based on a variable on the
#command line.  See comments above for mor info
my %special_subs = (
  'check_oidvals' => sub {
      my($result, $oids, $stats2chk, $var2check) = @_;
      my $base_oid = shift @$oids;
      my($oidName, $oidOpts) = map { $base_oid . $_ }@$oids;

      my $mystate = OK;
      my $myanswer = $stats2chk->{$var2check}{'answer'};
      my $myperfdata = $stats2chk->{$var2check}{'perfdata'};

      my $volume;
      if (defined $opts{'volume'}) { $volume = $opts{'volume'} }

      ############
      my $minVal;
      if (defined $stats2chk->{$var2check}{'subminval'} ) {
        $minVal = $stats2chk->{$var2check}{'subminval'};
        $minVal = ($opts{'critical'}*KB_PER_GB) if defined $opts{'critical'};
      }
      my $subskip;
      if (defined $stats2chk->{$var2check}{'subskip'}) {
        $subskip = $stats2chk->{$var2check}{'subskip'};
      }
      ############

      my @oidkey2name;
      for (sort keys %$result) {
        #create a array - key last digit(s) from oid - value volume name
        if ($_ =~ /^$oidName\.(\d+)/) {
          next if $volume && $volume ne $result->{$_};
          next if $subskip && $result->{$_} =~ /$subskip$/;
          $oidkey2name[$1] = $result->{$_};
        }

        if ( $_ =~ /^$oidOpts\.(\d+)/ ) {
          #tempkey is the last digit from the current oid
          my($tempkey) = $1;
          next if $volume && !defined $oidkey2name[$tempkey];
          next if $subskip && !defined $oidkey2name[$tempkey];

          if ($minVal && ($result->{$_} < $minVal )) {
            $mystate       = WARNING;
            #$result->{$_} is kbytes avail
            my $f_answer   = sprintf($myanswer,   $result->{$_});
            my $f_perfdata = sprintf($myperfdata, $oidkey2name[$tempkey]);
            report_exit($var2check, $mystate, $f_answer, $f_perfdata);
          } elsif ( grep /nosnap=on/, $result->{$_} ) {
            #format_answers($mystate, $myanswer, $myperfdata);
            $mystate       = WARNING;
            my $f_answer   = sprintf($myanswer,   $oidkey2name[$tempkey]);
            my $f_perfdata = sprintf($myperfdata, $oidkey2name[$tempkey]);
            report_exit($var2check, $mystate, $f_answer, $f_perfdata);
          }
        }

      }
      my $f_answer   = " Checks OK";
      if ($volume) {
        $volume .= $f_answer;
        report_exit($var2check, $mystate, $volume, "");
      } else {
        report_exit($var2check, $mystate, $f_answer, "");
      }
    },
  'check_oidvals_64' => sub {
      my($result, $oids, $stats2chk, $var2check) = @_;
      my $base_oid = shift @$oids;

      my($oidName_,   $highb_ ,  $lowb_) =@$oids;

      my $oidName=$base_oid .$oidName_;
      my $lowb=$base_oid .$lowb_ ;
      my $highb=$base_oid .$highb_ ;
      my $mystate = OK;
      my $myanswer = $stats2chk->{$var2check}{'answer'};
      my $myperfdata = $stats2chk->{$var2check}{'perfdata'};

      my $volume;
      if (defined $opts{'volume'}) { $volume = $opts{'volume'} }

      ############
      my $warnVal;
      my $critVal;
      my $high=0;
      my $low=0;
      my $index=".0";
      my $f_perfdata="";

      if (defined $stats2chk->{$var2check}{'subminval'} ) {
        $warnVal = $stats2chk->{$var2check}{'subminval'};
        $warnVal = ($opts{'warning'}) if defined $opts{'warning'};
      }
      if (defined $stats2chk->{$var2check}{'subminval'} ) {
        $critVal = $stats2chk->{$var2check}{'subminval'};
        $critVal = ($opts{'critical'}) if defined $opts{'critical'};
      }
      my $subskip;
      if (defined $stats2chk->{$var2check}{'subskip'}) {
        $subskip = $stats2chk->{$var2check}{'subskip'};
      }
      ############

      if  ( $oidName_ ne "NONE" )
     {
      for (sort keys %$result) {
	  #create a array - key last digit(s) from oid - value volume name
	  if ($_ =~ /^$oidName\.(\d+)/) {
	      next if $volume && $volume ne $result->{$_};
	      next if $subskip && $result->{$_} =~ /$subskip$/;
	      $index=".".$1 ;
	      last ;
	   }
      }
     }

	      $low=$result->{$lowb.$index} ;
	      # I can't get translate to do the right thing (tm) so this is a horrible hack.
	      if ( $low < 0 ) 
	      	{
	  	 $low=$low+(1<<32);
		}
	      if ( $highb_ ne "NONE" ) {
	      	$high=$result->{$highb.$index}<<32;
		}
	      my $res=$low+$high ;
		
	      if ($warnVal && ($res >= $warnVal )) {
		  $mystate       = WARNING;
	      }
	      if ($critVal && ($res >= $critVal )) {
		  $mystate       = CRITICAL;
	      }
	      my $f_answer   = sprintf($myanswer,   $res);
	      if  ( $oidName_ ne "NONE" )
		{
		 $volume =~ s#/#_#g ;
	         $f_perfdata = sprintf($myperfdata, $volume , $res );
		}
		else
		{
		$f_perfdata = sprintf($myperfdata,  $res );
		}

	      report_exit($var2check, $mystate, $f_answer, $f_perfdata);
  }
,
      #an example of a simple sub that you can use for a new variable
  #'foo' => sub {
  #  print "foo\n";
  #},
);

sub report_exit ($$$$) {
  #accepts 4 variables
  # var    -variable checked (i.e., FAN)
  # state  -exit status
  # answer -formatted answer string
  # perf   -formatted performance data string
  #prints a string for nagios
  #exits with status $state
  my($var, $state, $answer, $perf) = @_;
  print "$var $state - $answer|$perf\n";
  exit $ERRORS{$state};
}

sub process_arguments {
  #process the command line args
  #$opts is a referene to a hash
  my $opts = shift;
  my($session, $error);

  my $status = GetOptions ( $opts,
    'version|V',
    'help|h',
    'snmp_version|P=i',
    'community|C=s',
    'seclevel|L=s',
    'authproto|a=s',
    'secname|U=s',
    'authpass|A=s',
    'privpass|X=s',
    'hostname|H=s',
    'timeout|t=i',
    'variable|v=s',
    'warning|w=i',
    'critical|c=i',
    'volume|o=s',
  );

  #print each %$opts, "\n";
  usage unless $status;
  print_help if defined $opts->{'help'};
  usage  unless defined $opts->{'variable'};
  usage  unless defined $opts->{'hostname'};
  #usage if $opts->{'snmp_version'} !~ /[123]/;
  usage  unless $opts->{'snmp_version'} == (1||2||3);
  $opts->{'variable'} = uc $opts->{'variable'};

  usage unless grep { $opts->{'variable'} eq $_ } keys %stats2chk;

  if ( $opts->{'snmp_version'} == (1||2) ) {
    ($session,$error) = Net::SNMP->session(
          -hostname  => $opts->{'hostname'},
          -port      => $opts->{'port'},
          -version   => $opts->{'snmp_version'},
          -timeout   => $opts->{'timeout'},
          -community => $opts->{'community'},
        );
  }

  if ( $opts->{'snmp_version'} == 3 ) {
    usage unless defined $opts->{'seclevel'} && defined $opts->{'secname'};
    usage unless ( $opts->{'seclevel'} eq \
        ('noAuthNoPriv'||'authNopriv'||'authPriv') );
    my($auth, $priv);

    if ( $opts->{'seclevel'} eq 'noAuthNoPriv' ) {
      ($session,$error) = Net::SNMP->session(
            -hostname  => $opts->{'hostname'},
            -community => $opts->{'community'},
            -port      => $opts->{'port'},
            -version   => $opts->{'snmp_version'},
            -username  => $opts->{'secname'},
            -timeout   => $opts->{'timeout'},
          );
    } elsif ( $opts->{'seclevel'} eq ('authNoPriv' || 'authPriv' ) ) {
      usage unless ( $opts->{'authproto'} eq ('MD5' || 'SHA1') );
      usage unless ( defined $opts->{'authpass'} );
      if ( $opts->{'authpass'} =~ /^0x/ ) {
        $auth = "-authkey => $opts->{'authpass'}";
      } else {
        $auth = "-authpassword => $opts->{'authpass'}";
      }
      if ( $opts->{'seclevel'} eq 'authPriv' ) {
        usage unless ( defined $opts->{'privpass'} );
        if ( $opts->{'privpass'} -~ /^0x/ ) {
          $priv = "-privkey => $opts->{'privpass'}";
        } else {
          $priv = "-privpassword => $opts->{'privpass'}";
        }
      }
      ($session,$error) = Net::SNMP->session(
            -hostname  => $opts->{'hostname'},
            -community => $opts->{'community'},
            -port      => $opts->{'port'},
            -version   => $opts->{'snmp_version'},
            -username  => $opts->{'secname'},
            -timeout   => $opts->{'timeout'},
            -authprotocol => $opts->{'authproto'},
            $auth,
            $priv,
          );
    }
  }

  if ( ! defined $session ) {
    $state = UNKNOWN;
    print "$state:$error";
    exit $ERRORS{$state};
  }

  return $session;
}

##########

$SIG{'ALRM'} = sub {
  print "ERROR: No snmp response from $opts{'hostname'} (alarm timeout)\n";
  exit $ERRORS{UNKNOWN};
};

my $session = process_arguments \%opts;

my $var2check = $opts{'variable'};
my $mycritical = $opts{'critical'};
my $mywarn = $opts{'warning'};

my $myoid = $stats2chk{$var2check}{'oid'};
#my $mystate = $stats2chk{$var2check}{'state'};
my $myanswer = $stats2chk{$var2check}{'answer'};
my $myperfdata = $stats2chk{$var2check}{'perfdata'};

alarm $opts{'timeout'};

if ( ! defined ( $result = $session->get_table(-baseoid => $myoid) ) ) {
  my $answer = $session->error;
  $session->close;
  my $state = CRITICAL;
  print "$state:$answer for $myoid with snmp version $opts{'snmp_version'}\n";
  exit $ERRORS{$state};
}
$session->close;
alarm(0);

if (defined (my $mysub = $stats2chk{$var2check}{'sub'}) ){
  my $subopts = $stats2chk{$var2check}{'subopts'};

  &{$special_subs{$mysub}}($result, $subopts, \%stats2chk, $var2check);
  #just in case the special_sub doesn't exit (a bug)
  exit $ERRORS{$state};
} else {
  #set state to WARNING if this is true
  $state = ( ( defined $mywarn ) && ($result->{$myoid . ".0"} >= $mywarn) )?
      WARNING:
      #set state to CRITICAL if this is true
      ( ( defined $mycritical ) && ($result->{$myoid . ".0"} >= $mycritical) ) ?
          CRITICAL :
          #set state to OK if none are true
          OK;
  my $f_answer = sprintf($myanswer, $result->{$myoid . ".0"});
  my $f_perfdata = sprintf($myperfdata, $result->{$myoid . ".0"});
  report_exit($var2check, $state, $f_answer, $f_perfdata);
}

#print "$var2check $state - $myanswer|$myperfdata\n";
exit $ERRORS{$state};
