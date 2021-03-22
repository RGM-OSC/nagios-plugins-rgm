#!/usr/bin/perl

##################################################################################################################
# Description : Check Nutanix Cluster by SSH
# Date : 19 September 2016
# Author : Fabrice LE DORZE  
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#
##################################################################################################################

use strict;
use Net::OpenSSH;
use Getopt::Long;
use Date::Parse;
use Data::Dumper;

my $PROGNAME=`basename $0`;

#-----------------------------------------------------
# Usage function
#-----------------------------------------------------
sub Print_Usage() {
	print <<USAGE;

Usage: $PROGNAME -H <host> [-d] [-u <user>] [-p <password>] [-P <prompt>] [-t timeout] -T <status|alerts> 
                                            [-c <criticity_code>]

USAGE
}

#-----------------------------------------------------
# Help function
#-----------------------------------------------------
sub Print_Help() {
	print <<HELP;

This plugin executes different checks on Nutanix Clusters thanks to CLI command by SSH
HELP
	Print_Usage;
        print <<HELP;
Options :	
	-H <hostname> : the hostname.
	-u <user> :  user to connect to the host.
	-p <password> :  password to connect to the host.
        -T <test> : test to execute. Maybe status, alerts.
        -c <criticity> : Nagios status. Default is 1 (WARNING) 
        -r <regexp> : select only items matching the regular expression
        -e : exclude items matching the regular expression above
        -a <age in second>: for alerts test, max age of alerts.i Default is 300.
        -P <prompt> : prompt to wait for once connected. Default is '<.*>';
        -t <timeout> : timeout. Default is 10s
        -d : debug mode


 Example :
$0  -H cluster -u admin -p toto -C status -r snmpd -c 2

        
HELP
	exit 3;
}

#-----------------------------------------------------
# Print debug
#-----------------------------------------------------
sub Debug
{
    my $debug=shift;
    return unless ($debug);
    open(DEBUG,"<$::input_log");
    while (<DEBUG>)
    {
        print $_;
    }
    close DEBUG;
}

#-----------------------------------------------------
# Get user-given variables
#-----------------------------------------------------
my ($help, $host, $user, $password, $timeout, $test, $prompt, $regexp, $exclude, $max_age, $criticity, $debug);
Getopt::Long::Configure ("bundling");
GetOptions (
'H=s' => \$host,
'u=s' => \$user,
'p=s' => \$password,
'T=s' => \$test,
'c=s' => \$criticity,
'r=s' => \$regexp,
'e' => \$exclude,
'a=s' => \$max_age,
'd' => \$debug,
't=s' => \$timeout,
'P=s' => \$prompt,
'h' => \$help
);

($help) and Print_Help;

print "\nOption missing.\n" and Print_Help unless ($host && $user && $password && $test);
print "\nBad test.\n" and Print_Help unless ($test =~ /status|alerts/);
print "\n-a requires -T alerts.\n" and Print_Help if (($max_age) and $test ne "alerts");

my @ERRORS=('OK','WARNING','CRITICAL','UNKNOWN');
$criticity=2 unless ($criticity);
$max_age=300 unless ($max_age);
my %commands =
(
status => '/usr/local/nutanix/cluster/bin/cluster status',
alerts => '/home/nutanix/prism/cli/ncli alerts ls'
);

#-----------------------------------------------------
# Execute command
#-----------------------------------------------------
my $code=0;
$timeout=10 unless $timeout;
$prompt="<.*>" unless ($prompt);
my @a=getpwuid($<);
my $whoami=$a[0];
our $input_log="/tmp/ssh.$$";

# Connect
my @opts=('-o' => 'StrictHostKeyChecking no','-q');
if ($debug)
{
      $Net::ssh::debug |= 16;
      @opts=( @opts, '-v');
}
my %params = ( 'user'=>$user, ssh_cmd=>'/usr/bin/ssh', timeout=>$timeout, master_opts => \@opts);
%params = ( %params, 'password'=>$password) if ($password);
my $ssh;
$ssh = Net::OpenSSH->new($host,%params); 
unless ($?==0 and $ssh)
{
    print $ERRORS[3]. " : ".$ssh->error;
    exit 3;
}

# Execute command
my ($result,$error)=$ssh->capture2($commands{$test});
my @results=split(/\n/,$result);

#-----------------------------------------------------
# Close Connexion
#-----------------------------------------------------
#kill 9, $ssh->get_master_pid;

#-----------------------------------------------------
# Parse command result
#-----------------------------------------------------
# Cleanup
map {s/\r|\n//g} @results;
map {s/\s+/ /g} @results;
my %faults;
my @defaults;
my ($line, $state, $cvm);
my %comments;
$comments{'status'}="Cluster Status";
$comments{'alerts'}="Alerts since ".$max_age;

my @failed_services, my @unknown_services, my @ok_services;
my @warning_alerts, my @critical_alerts, my @alert_details, my %alerts, my $perfs;
my @details;

# Cluster services status
if ($test eq "status")
{
    while ($#results>-1)
    { 
        # Skip to next CVM
        unless ($line=~/CVM: (\d+\.\d+\.\d+\.\d+) (.*)/)
        {
            $line=shift @results;
            next;
        }
        push @details, $line;
        my $cvm=$1;
        my $cvm_state=$2;

        # Parse services of that CVM
        my @cvm_details;
        $line=shift @results;
	while ($line and $line !~ /CVM:/)
        {
            print "$line\n" if ($debug);
            if ($regexp)
            {
                $line=shift @results, next if ($line!~/$regexp/ and !$exclude);
                $line=shift @results, next if ($line=~/$regexp/ and $exclude);
            }
            my ($service,$state)=($line=~/(\w+)[\s\t]+(\w+)[\s\t]+\[/);
            push  @failed_services, $service." on CVM ".$cvm if ($state !~/UP/i);
            push @ok_services, $service unless (grep{/^$service$/} @ok_services);
            push  @cvm_details, $line;
            $line=shift @results;
        }
         push @unknown_services, $cvm unless (grep {/$regexp/} @cvm_details or $exclude);
        @details=(@details,@cvm_details,"");
    }
    if (@failed_services)
    {
        print "$ERRORS[$criticity], Faulty " . $comments{$test} . ", failed services : " . join(", ",@failed_services).". See details.";
        $code=$criticity
    }
    elsif (@unknown_services)
    {
        #print "$ERRORS[1], no service matching '$regexp' on CVMs : " . join(", ",@unknown_services).". See details.";
        #$code=1;
 print $ERRORS[0] . ", all services (".join(", ",@ok_services). ") are UP on all CVMs, see details.";
        $code=0;   
}
    else
    {
        print $ERRORS[0] . ", all services (".join(", ",@ok_services). ") are UP on all CVMs, see details.";
        $code=0;
    }
}

# last alerts
elsif ($test eq "alerts")
{
    # Parse output to build of hash table of alerts
    while ($#results>-1)
    { 
        # Skip to next ID
        unless ($line=~/ID.* : (.*)/)
        {
            $line=shift @results;
            next;
        }
        (my $id)=($line=~/ID : (.*)/);
        my ($key,$value)=($line=~/ +(.*) +: +(.*)/);
        $alerts{$id}->{$key}=$value;
        push @alert_details, $line;

        $line=shift @results;
	while ($line  and $line !~ /ID.* : /)
        {
            push @alert_details, $line;
            my ($key,$value)=($line=~/ +(.*) +: +(.*)/);
            $alerts{$id}->{$key}=$value;
            $line=shift @results;
        }
        @{$alerts{$id}->{'Details'}}=@alert_details;
        @alert_details=();
    }
 
    # Loop on alerts hash table
    foreach my $id (keys %alerts)
    {
        # Message
        if ($regexp)
        {
            $line=shift @results, next if ($alerts{$id}->{'Message'}!~/$regexp/ and !$exclude);
            $line=shift @results, next if ($alerts{$id}->{'Message'}=~/$regexp/ and $exclude);
        }

        # Created On
        my $age=time()-str2time($alerts{$id}->{'Created On'});
        next if ($age>$max_age);

        # Severity
        next unless ($alerts{$id}->{'Severity'}=~/warning|critical/i);
        push @warning_alerts, $id if ($alerts{$id}->{'Severity'}=~/warning/i);;
        push @critical_alerts, $id if ($alerts{$id}->{'Severity'}=~/critical/i);;

        # Acknownledgement 
        next if ($alerts{$id}->{'Acknowledged'}!~/false/i);

        # Resolved
         next if ($alerts{$id}->{'Resolved'}!~/false/i);
    
        # Details
        @details=(@details,"",@{$alerts{$id}->{'Details'}});
        
    } 
    my $nbc=0, my $nbw=0;
    if (@critical_alerts)
    {
        $nbc=$#critical_alerts+1;
        print "$ERRORS[$criticity], found ".$nbc." critical alerts since last $max_age seconds. See details.";
        $code=$criticity
    }
    elsif (@warning_alerts)
    {
        $nbw=$#warning_alerts+1;
        print "$ERRORS[1], found ".$nbw." warning alerts since last $max_age seconds. See Details.";
        $code=1;
    }
    else
    {
        print $ERRORS[0] . ", no alerts found since  last $max_age seconds.";
        $code=0;
    }
    $perfs="warning_alerts=".$nbw." critical_alerts=".$nbc;
}
print "\n".join("\n",@details);
print "|".$perfs if ($perfs);

#-----------------------------------------------------
# Cleanup
#-----------------------------------------------------
unlink $input_log;

exit $code;
