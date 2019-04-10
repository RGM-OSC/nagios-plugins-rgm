#!/usr/bin/env perl

# show volume status...

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
my $compCmd = "volume show";

#print "/usr/lib/jvm/java-6-openjdk/bin/java -jar /opt/Compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\"";
my $javaCmd = "/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre/bin/java -jar /srv/eyesofnetwork/nagios/plugins/check_compellent/CompCU.jar -host \"$compHost\" -user \"$compUser\" -password \"$compPwd\" -c \"$compCmd\" -xmloutputfile /tmp/Compellent_volume.xml 2>&1";

#print $javaCmd;
open(CMD, "$javaCmd|");
#$res = <CMD>;

my $error=0;
my $stroutput;
while (<CMD>) {

    next if  /^-----/;
    next if  /^====/;
    next if  /^$/;
    next if  /^User/;
    next if  /^Compe/;
    next if  /^Host/;
    next if  /^Single/;
    next if  /^Index/;
    next if  /^Running/;
    next if  /^Connecting/;
    next if  /^Controller/;
    next if  /^Successfully/;
    next if  / Up /;
    next if  / Recycled /;
    $stroutput .= $_;
   
} 
if (($stroutput ne "") or ($error == 2)) {
print "CRITICAL: $stroutput\n";
close(CMD);
exit(2);
}
else {
print "OK : volumes are all UP\n";
close(CMD);
exit(0);
}

# Pascal Pucci - Janvier 2012
# From Website DSMI publication : April 2012
