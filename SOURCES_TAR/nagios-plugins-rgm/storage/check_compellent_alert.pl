#!/usr/bin/env perl

# Show Alert from Compellent

use strict;
use Getopt::Long;
Getopt::Long::Configure('bundling');
use Date::Simple('date', 'today');

my $opt_hostname = '';
my $opt_user = '';
my $opt_password = '';
my $date = today()->format("%m/%d/%Y");
#my $date = Date::Simple->new('2013-09-18')->format("%m/%d/%Y");



my $dateM1 = (today() - 1)->format("%m/%d/%Y");
my $dateM2 = (today() - 2)->format("%m/%d/%Y");

GetOptions
(  "host|host=s" => \$opt_hostname,
   "user|user=s" => \$opt_user,
   "password|password=s" => \$opt_password,
);

my $compHost = $opt_hostname;
my $compUser = $opt_user;
my $compPwd = $opt_password;
my $compCmd = "alert show";

#print "/usr/lib/jvm/java-6-openjdk/bin/java -jar /opt/Compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\"";
my $javaCmd = "/usr/lib/jvm/java-1.6.0-openjdk-1.7.0.161.x86_64/jre/bin/java -jar /srv/eyesofnetwork/nagios/plugins/check_compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\" -xmloutputfile /tmp/Compellent_alert.xml 2>&1";

#print $javaCmd;
open(CMD, "$javaCmd|");


my $stroutput;
while (<CMD>) {
    next if  /^-----/;
    next if  /^====/;
    next if  /^$/;
    next if  /^User/;
    next if  /^Compe/;
    next if  /^Host/;
    next if  /^Single/;
    next if  /^Running/;
    next if  /^Connecting/;
    next if  /^Controller/;
    next if  /^Successfully/;
    next if  /^Saving/;
    next if  /Informational/;
    next if  /true/;
	

    $stroutput .= $_;
} 

my $sorted_cmd = "echo \"$stroutput\" \| awk \'\{print \$3\" \"\$4\" \"\$5\" \"\$6\" \"\$7\" \"\$8\" \"\$9\" \"\$10\" \"\$11\" \"\$12\" \"\$13\}\'";
open(CMD, "$sorted_cmd|");

$stroutput ="";
my $isToday = "";

while (<CMD>) {
	next if /^ /;
	$stroutput .= $_;
    if ($stroutput =~ $date || $stroutput =~ $dateM1 || $stroutput =~ $dateM2 ) {
        $isToday = "1";
    }
}

if ($stroutput ne "" && $isToday eq "1") {
print "CRITICAL: $stroutput\n";
exit(2);
}
else {
print "OK : no Alert today (Critical or Down)\n";
exit(0);
}

# Pascal Pucci - Janvier 2012
# From Website DSMI publication : April 2012
