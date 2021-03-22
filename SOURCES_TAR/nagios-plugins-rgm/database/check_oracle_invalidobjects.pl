#!/usr/bin/perl
# writing policies
use strict;
use warnings;
# loading perl modules
use DBI;
use DBD::Oracle;
#use Switch;
use Getopt::Std;
use File::Basename;
my $prog = basename $0;
# option array
my %opts;
# my $TbsToCheck = '^.*$';
# Oracle default listener port
$opts{p}='1521';
my @RC=("OK", "WARNING", "CRITICAL", "");
my $output = "";
my $perfdata = "";
my $RC=0;
my $found=0;
my $objectType;
my $InvalidObjects;
my $objectName;
my $objectOwner;

# Help message
sub print_Usage {
	print "Usage $prog -H <hostname> [-p <port>] -S <SID> -U <username> -P <password> -w <warnLvl> -c <critLvl> [-m <connectMode>] [-z <srv_name>]\n";
	print "\t-H\tHostname/IP of the machine hosting the Oracle Service\n";
	print "\t-S\tSID of the oracle database\n";
	print "\t-U\tUsername able to connect to SID\n";
	print "\t-P\tUsername's password\n";
	print "\t-w\tWarning threshold number of invalid objects (ie: 30 or 10.1 or 0.1)\n";
	print "\t-c\tCritical threshold number of invalid objects (see -w)\n";
	print "\t-p\tListening port of the Oracle service (default 1521)\n";
	print "\t-m\tConnection mode (0=normal(default), 2=sysdba)\n";
	print "\t-z\tService Name (EZCONNEC)\n";
	print "\n";
	print "This plugin returns the current number of invalid objects ";
	print "\n";
exit 3;
}
sub exitStr(){
	print $_[0];
	exit $_[1];
}
# Parsing arguments
getopts("H:S:U:P:w:c:p:m:z:", \%opts) or print_Usage;
if (!$opts{w} or !$opts{c}){
	print "ERROR: Please provide Warning and Critical threshold\n";
	print_Usage;
	exit 3;
}

# check if threshold are floats
my $WarnLvl = sprintf("%f",$opts{w}) if $opts{w};
my $CritLvl = sprintf("%f",$opts{c}) if $opts{c};

if ($WarnLvl >= $CritLvl or $CritLvl <= $WarnLvl){
        print "ERROR: thresholds uncorrectly setted \n";
        print_Usage;
        exit 3;
}

# Connecting to listener exit on errors
my $dbh;
if ($opts{z}){
	$dbh = DBI->connect("dbi:Oracle://$opts{H}:$opts{p}/$opts{z}",$opts{U},$opts{P}, {ora_session_mode => $opts{m}, PrintError =>0}) || &exitStr("ERROR: ORA-$DBI::err\n$DBI::errstr\n",3) ;
}else{
	$dbh = DBI->connect("dbi:Oracle:host=$opts{H};sid=$opts{S};port=$opts{p}",$opts{U},$opts{P}, {ora_session_mode => $opts{m}, PrintError =>0}) || &exitStr("ERROR: ORA-$DBI::err\n$DBI::errstr\n",3);
}
# Connection ok, preparing SQL request
my $req = 'select count(*) from dba_objects where status = '."'INVALID'";
# preparing request or exit if error
my $hreq = $dbh->prepare($req) || &exitStr("ERROR : $DBI::errstr\n",3);
# execute the resquest
$hreq->execute() || &exitStr("ERROR: ORA-$DBI::err\n",3);
# Bind the output columns to vars name we'll fetch further

$hreq->bind_columns(\$InvalidObjects);
# processing checks
$hreq->fetchrow(); # here only one row, add check
my $tRC=0;
                  
if(($InvalidObjects >=  $WarnLvl) and ($InvalidObjects <  $CritLvl)) {
		$tRC=1;
	}elsif (($InvalidObjects >=  $CritLvl) and ($InvalidObjects >  $WarnLvl)) {
		$tRC=2;
	}else {
		$tRC=0;
	}
 
	if($tRC > $RC) {$RC = $tRC;}
	$output .= sprintf("Invalid Objects %.f",$InvalidObjects);
	#nagios performance data output 'label'=value[UOM];[warn];[crit];[min];[max] http://nagiosplug.sourceforge.net/developer-guidelines.html#AEN201
    $perfdata .= sprintf("invalid_objects=%.f;%.f;%.f",$InvalidObjects,$WarnLvl,$CritLvl);

# print output
&exitStr("$RC[$RC] - $output|$perfdata\n",$RC);

# Closing cursor
$hreq->finish();
# Finally disconnect if session is active
$dbh->disconnect if $dbh || &exitStr("ERROR: ORA-$DBI::err\n",3);
#EOF
