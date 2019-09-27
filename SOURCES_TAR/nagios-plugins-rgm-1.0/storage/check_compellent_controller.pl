#!/usr/bin/perl

# Show status from Controller

use strict;
use Getopt::Long;
Getopt::Long::Configure('bundling');

my $opt_hostname = '';
my $opt_user = '';
my $opt_password = '';

GetOptions
(  "host|host=s" => \$opt_hostname,
   "user|user=s" => \$opt_user,
   "password|password=s" => \$opt_password,
);

my $compHost = $opt_hostname;
my $compUser = $opt_user;
my $compPwd = $opt_password;
my $compCmd = "controller show";

#print "/usr/lib/jvm/java-6-openjdk/bin/java -jar /opt/Compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\"";
my $javaCmd = "/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre/bin/java -jar /srv/eyesofnetwork/nagios/plugins/check_compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\" -xmloutputfile /tmp/Compellent.xml 2>&1";

#print $javaCmd;
open(CMD, "$javaCmd|");
#$res = <CMD>;

my $error=0;
my $stroutput;
while (<CMD>) {
    
    my @ctl;
    next if not / SN /;
   
    my @values = split(/ /, $_);
    foreach my $val (@values) {
        $val =~ s/^\s+//;
	$val =~ s/\s+$//;
	next if !$val;
	#print "$val\n";
        push(@ctl,$val);
    }
    $error = 2 if ($ctl[4] ne 'Up');
    $stroutput .= ": Controller: $ctl[9] status: $ctl[4] Leader: $ctl[3] LocalPortCondition: $ctl[5]";

} 
if (($stroutput eq "") or ($error == 2)) {
print "CRITICAL$stroutput\n";
close(CMD);
exit(2);
}
else {
print "OK$stroutput\n";
close(CMD);
exit(0);
}

# Pascal Pucci - Janvier 2012
# From Website DSMI publication : April 2012
