#!/usr/bin/perl

# FILE: check_telnet.pl
# SYNOPSIS: nagios-compatible script to check telnet port.  Supports expect-like 
# passing of commands/arguments and returning data.
# RESPONSIBLE_PARTY: eli
# LICENSE: GPL, Copyright 2006 Eli Stair <eli.stair {at} gmail {dot} com>


use Getopt::Long;
use Net::Telnet ();


########################################################################
# begin program flow:
# get cmdline args and parse them:

my ($host, $port, $output);
my ($hostname, $line, $passwd, $telnet, $username);

&processargs;

#if ($netdev) {
#  print "RUNNING netcmd \n";
#  &netcmd;
#  print "RAN netcmd \n";
#}

if ($match) {
  &connect;
  &hostmatch;
} elsif ($cmd) {
  &connect;
  &runcmd
}
#} elsif ($netdev) {
#  &netcmd;
#}

&end;

########################################################################

### FUNC: getargs
sub processargs {

GetOptions (
    "H|host=s" => \$host,
    "P|port=i" => \$port, 
    "C|command=s" => \$cmd, 
    "M|match=s" => \$match,
    "user=s" => \$user,
    "password=s" => \$password,
);

# quick cmdarg lint:
unless ($host) { &cmdusage ; exit 1 };

$port = "23" unless defined($port);

if ($cmd) {
  unless ($user && $password) { 
    &cmdusage;
    exit 1;
  }
}

}
### /FUNC: processargs

### FUNC: cmdusage
sub cmdusage {
    print "\n";
    print "\t-H\t hostname/IP: of host to connect to gmetad/gmond on ","\n";
    print "\t-P\t Port: to connect to and retrieve XML ","\n";
    print "\t-O\t Output:  \n";
    print "\t-M\t Match: String to match";
    print "\n\n";

}
### /FUNC: cmdusage


### FUNC: connect
sub connect {

#print "in connect \n";
$telnet = new Net::Telnet (
Telnetmode => 0,
Timeout => 5,
);

# set up object
unless ($telnet->open(Host => $host, Port => $port)) {
  die "Can't connect to ($host) ($port)! ";
}

} #/sub connect


### FUNC: hostmatch
sub hostmatch {
$telnet->print("");
@banner = $telnet->waitfor('/login:.*$/');
foreach (@banner) {
    if ( "$_" =~ /.*$match.*/ ) {
      print "OK: regex-string ($match) matches login banner.\n";
      $telnet->close;
      exit 0;
    } else {
      print "CRITICAL: regex-string ($match) did not match login banner.\n";
      $telnet->close;
      exit 2;
    }
}
} #/sub

### FUNC: end
sub end {
$telnet->close;
exit 0
}

sub runcmd {
$telnet->print("");
unless ($telnet->login($user, $password)) {
    print "Can't connect to ($host) as ($user):($password)! \n";
    exit 1;
}

@cmdout = ($telnet->cmd($cmd));
foreach (@cmdout) {
    print $_;
}

#this unsuccessful (timing out) logout clears the socket... dunno
$telnet->print("logout");
$telnet->close;
}




