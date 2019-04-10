#!/usr/bin/perl

# File released under GPL V2 by Michael Aubertin ( michael.aubertin@apx.fr, michael.aubertin@gmail.com, michael.aubertin.external@airbus.com )
# This Script is desing to restart audit job of OpenScap from RedHat Satellite.
# Hope you'll enjoy it :)



# EDITABLE ZONE
my $user = 'admin';

my $pass = 'ManU,66';
my $debug = 0;
my $dumper = 0;
# DO NOT EDIT THE FOLLOWING (Or make sure first you know what you are going to do :P )
my $audited_server;
my $xccdf_profile;
use strict;
use warnings;
use POSIX qw(locale_h);
use POSIX qw(strftime);
use DateTime::Format::ISO8601;
use File::Basename;
use Frontier::Client;
use Data::Dumper;

use Getopt::Long;
use vars qw($opt_audited_server $opt_xccdf_profile $opt_host $opt_user $opt_pass $opt_debug $opt_dumper $opt_help $PROGNAME $warning);

use utils qw(%ERRORS &print_revision &support &usage);


setlocale(LC_CTYPE, "en_EN");
my $HOST;


sub Helper {
     print "usage: $0 -t <target RH Satellite Server> -a <audited server> -x <xccdf profile> -u <username> -P <password> -w WarningMinPCT [-d --debug] [-D --dump] [-h --help]\n";
}


# BEGIN OF MAIN
Getopt::Long::Configure('bundling');
GetOptions
        ("h"     => \$opt_help,           "help"         => \$opt_help,
         "D"     => \$opt_dumper,      "dump"         => \$opt_dumper,
         "d"     => \$opt_debug,       "debug"        => \$opt_debug,
         "a=s"   => \$opt_audited_server,          "audited_server=s"     => \$opt_audited_server,
         "x=s"   => \$opt_xccdf_profile,           "xccdf_profile=s"      =>  \$opt_xccdf_profile,
         "t=s"   => \$opt_host,                    "rhn-server-target=s"  =>  \$opt_host,
         "u=s"   => \$opt_user,                    "rhn-user=s"           =>  \$opt_user,
         "P=s"   => \$opt_pass,                    "rhn-passwd=s"         =>  \$opt_pass,
         "w=i"   => \$warning,         "warning=i"    => \$warning);


unless ($warning) {
        print "Missing WARNING % of minimum compliance level of SCAP Audit\n";
        Helper;
        exit $ERRORS{'UNKNOWN'};
}

if ($opt_debug) {
             $debug = 1;
}

if ( $opt_dumper) {
             $dumper = 1;
}

if ($opt_help) {
          print "Ask for help? Here it is...\n";
          Helper; 
          exit $ERRORS{'OK'};  
}

if ($opt_host) {
     if ( $opt_host ne "" ) {
          $HOST=$opt_host;
     }
     else {
          print "Can't determine rhn server option.\n";
          Helper;
          exit $ERRORS{'UNKNOWN'};
     }
} else {
     print "Unspecified rhn server option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
}

if ($opt_audited_server) {
     if( $opt_audited_server ne "" ) {
          $audited_server = $opt_audited_server;
     } else {
          print "Can't determine audited server option.\n";
          Helper;
          exit $ERRORS{'UNKNOWN'};
     }
} else {
     print "Unspecified audited server option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
}

if ($opt_xccdf_profile) {
     if( $opt_xccdf_profile ne "" ) {
          $xccdf_profile = $opt_xccdf_profile;
     } else {
          print "Can't determine XCCDF profile option.\n";
          Helper;
          exit $ERRORS{'UNKNOWN'};
     }
} else {
     print "Unspecified XCCDF profile option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
}

if ($opt_user) {
     if( $opt_user ne "" ) {
          $user = $opt_user;
     } else {
     print "Can't login user to RHN option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
     } 
} else {
     print "Unspecified login user to RHN option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
}

if ($opt_pass) {
      if( $opt_pass ne "" ) {
        if ( $opt_pass eq "default" ) {
          $pass = $pass;
        } else {
          $pass = $opt_pass;
        }
      } else {
     print "Can't password user to RHN option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
    }
} else {
     print "Unspecified password user to RHN option.\n";
     Helper;
     exit $ERRORS{'UNKNOWN'};
}


my $client = new Frontier::Client(url => "http://$HOST/rpc/api");
my $session = $client->call('auth.login',$user, $pass);
my $systems = $client->call('system.listUserSystems', $session);
my $lastsystem = @$systems[-1]->{'name'};
my $id_to_restart = '0';
my $id_to_compare = '0';
my $xid_to_check = '0';
my $xid_to_compare = '0';


print Dumper($systems) if $dumper;

# ********************************************************************************************
#
#
# ********************************************************************************************


foreach my $system (@$systems) {
     
     my $hostname = $system->{'name'};
     my @Arrayxid;
     my $Action_id;

     my $LastExecTime = 'vide';
     my $PreLastExecTime = 'vide';
     my $CurrentScanExecTime;


     if ( $hostname eq $audited_server) {

          my $listXccdfScans = $client->call('system.scap.listXccdfScans', $session, $system->{'id'});


          print "List of Scans: \n" if $debug;
          print Dumper($listXccdfScans) if $debug;
          foreach my $XccdfScan (@$listXccdfScans) {
            push @Arrayxid, $XccdfScan->{'xid'};
          }

          print Dumper(@Arrayxid) if $debug;
          foreach my $xid (@Arrayxid) {
            my $getXccdfScanDetails = $client->call('system.scap.getXccdfScanDetails', $session, $xid);
            print Dumper($getXccdfScanDetails) if $dumper;

            if ( $getXccdfScanDetails->{'profile'} eq $xccdf_profile ) {
              $Action_id = $getXccdfScanDetails->{'action_id'};
              my $listSystemEvents = $client->call('system.listSystemEvents', $session, $system->{'id'});
              foreach my $SystemEvent (@$listSystemEvents) {
                if ( $SystemEvent->{'id'} eq $Action_id ) {
                  print "Evaluting if study ".$Action_id."\n" if $debug;
                  if ( $SystemEvent->{'successful_count'} eq '1') {
                    my $tmp_endtime = $getXccdfScanDetails->{'end_time'};
                    my @EndDateStringChunk1 = split(',', $$tmp_endtime);
                    my $end_Perl_FuckingTime = $EndDateStringChunk1[0];
                    substr($end_Perl_FuckingTime, 4 , 0) = '-' ;
                    substr($end_Perl_FuckingTime, 7 , 0) = '-' ;
                    $CurrentScanExecTime = DateTime::Format::ISO8601->parse_datetime($end_Perl_FuckingTime);
                    print "Studying CurrentScanExecTime:".$CurrentScanExecTime."\n" if $debug;
                    print "Studying $Action_id:".$Action_id."\n" if $debug;


                    if ( $LastExecTime eq 'vide' ) {
                      $LastExecTime = $CurrentScanExecTime;
                      $PreLastExecTime = $LastExecTime; 
                      $id_to_restart = $Action_id;
                      $id_to_compare = $id_to_restart;
                      $xid_to_check = $xid;
                      $xid_to_compare = $xid_to_check;
                      print "Cond 1\n" if $debug;
                      print "\t Now LastExecTime:".$LastExecTime."\n" if $debug;
                      print "\t Now PreLastExecTime:".$PreLastExecTime."\n" if $debug;
                      print "\t Now id_to_restart:".$id_to_restart."\n" if $debug;
                      print "\t Now id_to_compare:".$id_to_compare."\n" if $debug;
                      print "\t Now xid_to_check:".$xid_to_check."\n" if $debug;
                      print "\t Now xid_to_compare:".$xid_to_compare."\n\n\n" if $debug;
                    } 
                    if ( $LastExecTime < $CurrentScanExecTime ) {
                        $PreLastExecTime = $LastExecTime; 
                        $id_to_compare = $id_to_restart;
                        $xid_to_compare = $xid_to_check;

                        $LastExecTime = $CurrentScanExecTime;
                        $id_to_restart = $Action_id;
                        $xid_to_check = $xid;

                        print "Cond 2\n" if $debug;
                        print "\t Now LastExecTime:".$LastExecTime."\n" if $debug;
                        print "\t Now PreLastExecTime:".$PreLastExecTime."\n" if $debug;
                        print "\t Now id_to_restart:".$id_to_restart."\n" if $debug;
                        print "\t Now id_to_compare:".$id_to_compare."\n" if $debug;
                        print "\t Now xid_to_check:".$xid_to_check."\n" if $debug;
                        print "\t Now xid_to_compare:".$xid_to_compare."\n\n\n" if $debug;
                    } 
                    if ( ( $PreLastExecTime < $CurrentScanExecTime ) && ( $CurrentScanExecTime < $LastExecTime ) ) {
                        $PreLastExecTime = $CurrentScanExecTime;
                        $id_to_compare = $Action_id;
                        $xid_to_compare = $xid;

                        print "Cond 3\n" if $debug;
                        print "\t Now LastExecTime:".$LastExecTime."\n" if $debug;
                        print "\t Now PreLastExecTime:".$PreLastExecTime."\n" if $debug;
                        print "\t Now id_to_restart:".$id_to_restart."\n" if $debug;
                        print "\t Now id_to_compare:".$id_to_compare."\n" if $debug;
                        print "\t Now xid_to_check:".$xid_to_check."\n" if $debug;
                        print "\t Now xid_to_compare:".$xid_to_compare."\n\n\n" if $debug;
                    }
                    if ( ( $PreLastExecTime > $CurrentScanExecTime ) && ( $PreLastExecTime eq $LastExecTime ) ) {
                        $PreLastExecTime = $CurrentScanExecTime;
                        $id_to_compare = $Action_id;
                        $xid_to_compare = $xid;

                        print "Cond 4\n" if $debug;
                        print "\t Now LastExecTime:".$LastExecTime."\n" if $debug;
                        print "\t Now PreLastExecTime:".$PreLastExecTime."\n" if $debug;
                        print "\t Now id_to_restart:".$id_to_restart."\n" if $debug;
                        print "\t Now id_to_compare:".$id_to_compare."\n" if $debug;
                        print "\t Now xid_to_check:".$xid_to_check."\n" if $debug;
                        print "\t Now xid_to_compare:".$xid_to_compare."\n\n\n" if $debug;
                    }
                  }
                }
              }
            }
          }
     }
}

print "\n\n\nId to restart is: ".$id_to_restart."\n" if $debug;
print "Id to compare is: ".$id_to_compare."\n" if $debug;
print "xid_to_check:".$xid_to_check."\n" if $debug;
print "xid_to_compare:".$xid_to_compare."\n\n\n" if $debug;

my $ListOfResultOfCheckedScan = $client->call('system.scap.getXccdfScanRuleResults', $session, $xid_to_check);
my $ListOfResultOfComparedScan = $client->call('system.scap.getXccdfScanRuleResults', $session, $xid_to_compare);

print "\n\n\nDumper xid_to_compare: ".Dumper($ListOfResultOfComparedScan)."\n" if $dumper;

my $count_test_to_compare = @$ListOfResultOfComparedScan;
my $count_test_to_check = @$ListOfResultOfCheckedScan;

my $count_of_passed_to_compare = 0;
my $count_of_passed_to_check = 0;
my $count_of_notselected_to_check = 0;
my $pct_success_to_check = 0;
my @Test_Passed_idref_to_compare;
my @Test_Passed_idref_to_check;


foreach my $test_to_check (@$ListOfResultOfCheckedScan) {
  if ( $test_to_check->{'result'} eq 'pass') {
    $count_of_passed_to_check = $count_of_passed_to_check + 1;
    push @Test_Passed_idref_to_check, $test_to_check->{'idref'};
  }
  if ( $test_to_check->{'result'} eq 'notselected') {
    $count_of_notselected_to_check = $count_of_notselected_to_check + 1;
  }
}

foreach my $test_to_compare (@$ListOfResultOfComparedScan) {
  if ( $test_to_compare->{'result'} eq 'pass') {
    $count_of_passed_to_compare = $count_of_passed_to_compare + 1;
    push @Test_Passed_idref_to_compare, $test_to_compare->{'idref'};
  }
}

print "\n\nCount of test in scan to compare with: ".$count_test_to_compare."\n" if $debug;
print "Count of test in scan to check: ".$count_test_to_check."\n" if $debug;
print "Count of PASSED test in scan to compare with: ".$count_of_passed_to_compare."\n" if $debug;
print "Count of PASSED test in scan to check: ".$count_of_passed_to_check."\n\n\n" if $debug;

my %Diff_From_Compared;
@Diff_From_Compared{ @Test_Passed_idref_to_compare } = @Test_Passed_idref_to_compare;
delete @Diff_From_Compared{ @Test_Passed_idref_to_check };

my %Diff_From_Check;
@Diff_From_Check{ @Test_Passed_idref_to_check } = @Test_Passed_idref_to_check;
delete @Diff_From_Check{ @Test_Passed_idref_to_compare };

my @List_Diff;
@List_Diff = (keys %Diff_From_Compared, keys %Diff_From_Check);

print "Test result (idref) diff: ".Dumper(@List_Diff)."\n" if $debug;

$pct_success_to_check = int((( 100 / ( $count_test_to_check - $count_of_notselected_to_check )) * $count_of_passed_to_check ) + 0.5 );
print "% of sucess: ".$pct_success_to_check."\n" if $debug;

if (@List_Diff) {
  print "CRITICAL: There is some difference since last check. Click for detail.\n";
  foreach (@List_Diff) {
    print "Test: '$_' differ, \n"; 
  }
  print " | pct_compliance=".$pct_success_to_check."%;$warning;0\n";
  $client->call('auth.logout', $session); 
  exit $ERRORS{'CRITICAL'};
} 

if ( $pct_success_to_check < $warning ) {
  print "WARNING: Too low level of security hardening compliance. | pct_compliance=".$pct_success_to_check."%;$warning;0\n";
  $client->call('auth.logout', $session); 
  exit $ERRORS{'WARNING'};
}


print "OK: There is $count_test_to_check in $xccdf_profile on server audited_server. | pct_compliance=".$pct_success_to_check."%;$warning;0\n";
$client->call('auth.logout', $session); 
exit $ERRORS{'OK'};
