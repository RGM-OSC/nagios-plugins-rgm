#!/usr/bin/perl
use strict;
use warnings;
use lib "/srv/rgm/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use LWP 5.64;
use Getopt::Long;
use LWP::UserAgent;

my $o_host = undef;     # hostname
my $o_port = undef;     # port
my $o_appl = undef;	# application
my $o_secs = 20;	# 20 secondes de timeout
my $url = "";
my $path_supp = "/probe/monitor/supervisionReport";


GetOptions('host|h=s' => \$o_host,
	   'port|p=i' => \$o_port,
           'url|app|u=s' => \$o_appl,
	   'timeout|t=i' => \$o_secs);

if (!defined($o_host) || !defined($o_port) ) {
  print "Erreur - Paramètres non fournis\n";
  exit $ERRORS{'UNKNOWN'};
}

if ( defined($o_appl) ) {
  $url="http://" . $o_host . ":" . $o_port . $path_supp . "App.htm?webapp=/" . $o_appl ;
} else {
  $url="http://" . $o_host . ":" . $o_port . $path_supp . ".htm";
}

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0");
$ua->timeout( $o_secs );
my $req = HTTP::Request->new(GET => $url );
$req->header(Accept => "text/html, */*;q=0.1");
my $res = $ua->request($req);

if ($res->is_success) {
	print $res->content;
	if ( $res->content =~ m/^OK / ) {
		exit $ERRORS{'OK'};
	} elsif ( $res->content =~ m/^WARNING /) {
		exit $ERRORS{'WARNING'};
	} else {
		exit $ERRORS{'CRITICAL'};
        }
 } else {
     print $res->status_line, "\n";
     exit $ERRORS{'CRITICAL'};
 }
exit $ERRORS{'UNKNOWN'};
