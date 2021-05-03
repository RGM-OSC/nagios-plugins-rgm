#!/usr/bin/perl

#===================================================================================================================
#
#         FILE: check_basicauth.pl
#
#        USAGE: check_basicauth.pl -u <url> -l <username> -p <password> (-c <critical> -w <warning> -e <expect> -v)
#
#  DESCRIPTION: Authenticates against a web page using basic auth 
#
#      OPTIONS: ---
# REQUIREMENTS: LWP::UserAgent and Crypt::SSLeay if https support is required
#         BUGS:	If the webpage is not using basic auth you may get false positives 
#        NOTES: ---
#       AUTHOR: Tim Pretlove 
#      VERSION: 0.7
#      CREATED: 16-06-2010
#     REVISION: ---
#      LICENCE: GNU
#      CHANGES:
#           0.7 Status now shows header for easier debugging
#      
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#===================================================================================================================

use strict;
use warnings;

use LWP::UserAgent;
use Getopt::Long;
use Time::HiRes qw(gettimeofday tv_interval);
use lib "/usr/local/nagios/libexec";
use utils qw(%ERRORS);

my ($status,$debug,$login,$crit,$warn,$ver,$expect,$url,$passwd);

GetOptions(
	'crtitical=s'	=> \$crit,
	'warning=s'		=> \$warn,
	debug			=> \$debug,
	status			=> \$status,
	verbose			=> \$ver,
	'url=s'			=> \$url,
	'login=s'		=> \$login,
	'password=s'	=> \$passwd,
	'expect=s'		=> \$expect) or HELP_MESSAGE();
	
$SIG{__DIE__} = \&nagios_die;

sub nagios_die {
    my $str = "HTTPAUTH: Critical - @_";
    chomp $str;
    print "$str";
    exit 2;    
}
	
sub testauth {
    my ($status,$debug,$login,$crit,$warn,$ver,$expect,$url,$passwd) = @_;
    my $elapsed;
    my $startsec;
	my $ua = new LWP::UserAgent;
	$ua->cookie_jar ( {} );
	$ua->requests_redirectable;
    my $timeout = $crit + 1;
    $ua->timeout($timeout);
	$startsec = [gettimeofday()];
	my $httpchk = substr $url, 0, 4; 
	if ($httpchk ne "http") { $url = "http://" . $url }
	my $req = new HTTP::Request GET => ($url);
	$req->authorization_basic($login,$passwd);
	print $req->content;
	my $response = $ua->request($req);
	$elapsed = tv_interval ($startsec, [gettimeofday]);
	if ($debug) {
		my $str = $response->content;
		print "$str\n";
	}
	if ($status) {
		my $str = $response->status_line;
		print "$str\n";
        print $response->headers()->as_string(), "\n";
	}

	if ($response->is_success) { 
		if (defined $expect) {
			my $str = $response->content;
			if ($str !~ /$expect/) {
				return (4,$elapsed);
			}
		}
		if ((defined $crit) && (defined $warn)) {
			if ($crit <= $elapsed) { return 3,$elapsed }
			if ($warn <= $elapsed) { return 2,$elapsed }
		}
		return 0,$elapsed;
	} else { return 1,$elapsed }
}

sub HELP_MESSAGE {
	print "$0 -u <url> -l <username> -p <password> -e <expect> (-c <critical> -w <warning> -v)\n";
	print "\t -u <url> # url string to run basic auth against\n";
	print "\t -l <username> # username to login with\n";
	print "\t -p <password> # password to login with\n";
	print "\t -c <seconds> # the number of seconds to wait before a going critical\n";
	print "\t -w <seconds> # the number of seconds to wait before a flagging a warning\n";
	print "\t -v # displays nagios performance information\n";
	print "\t -e <expect> # string to query on the authenticated page\n";
	print "\t -s prints status line (debugging info)\n";
	print "\t -d prints page contents (debugging info)\n";
	print "\t e.g $0 -u https://foobar.com -l testuser -p testpasswd -c 10 -w 3 -v -e \"Hello sweetie\"\n";
	exit 0;
}

sub checkopts {
    my ($status,$debug,$login,$crit,$warn,$ver,$expect,$url,$passwd) = @_;
	if ((!defined $url) || (!defined $login) || (!defined $passwd)) {
		HELP_MESSAGE();
		exit 4;
	}

	if ((defined $ver) && ((!defined $crit) || (!defined $warn))) {
		print "-v needs -c and -w values to be specified\n";
		HELP_MESSAGE();
		exit 4;
	}
	if (((defined $warn) && (!defined $crit)) || ((defined $crit) && (!defined $warn))) {
		print "Both -w and -c need to be specified\n";
		HELP_MESSAGE();
		exit 4;
	}
    if (!defined $expect) {
		print "-e <string> need to be specified\n";
		HELP_MESSAGE();
		exit 4;
    
    }
}
checkopts($status,$debug,$login,$crit,$warn,$ver,$expect,$url,$passwd);
my ($rc,$eltime) = testauth($status,$debug,$login,$crit,$warn,$ver,$expect,$url,$passwd);
my @mess = qw(OK CRITICAL WARNING CRITICAL CRITICAL);
my @mess2 = ("host authenticated successfully","authentication failed","is slow responding","host critical response time","failed to retrieve expect string");
print "HTTPAUTH $mess[$rc]: $mess2[$rc]";
if (defined $ver) {
	print "|time=$eltime" . "s;$warn;$crit;0;$crit";
}
print "\n";	
exit $ERRORS{$mess[$rc]};
