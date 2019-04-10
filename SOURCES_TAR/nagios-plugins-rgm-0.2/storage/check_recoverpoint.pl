#!/usr/bin/perl
#Monitor EMC RecoverPoint for operational indicators	S.Teeter   Aug-2010
#Send results to Nagios using nsca
#Print operations are for debugging; formal output goes to $dat
#See https://powerlink.emc.com/nsepn/webapps/btg548664833igtcuup4826/km/live1//en_US/Offering_Technical/Technical_Documentation/300-010-642.pdf
#Perl programmers, please forgive my perl; not my native language

#(1) Set required variables; alter as needed for local environment
$dir="/srv/rgm/nagios/plugins";		# location of components
$rpa="recoverpoint.cmd";	# file of commands to test
$dat="nsca_recoverpoint.dat";	# output file formatted for nsca
$msglen=200;		# max length of status information msg
$warn=85;               # yellow alert
$crit=95;               # red alert

my %status_list  = (  'UNKNOWN'  => '-1',
                      'OK'       => '0',
                      'WARNING'  => '1',
                      'CRITICAL' => '2'   );

my %i_status_list  = ('-1' => 'UNKNOWN',
                      '0'  => 'OK',
                      '1'  => 'WARNING',
                      '2'  => 'CRITICAL'  );

#(2) Process file of commands
#    Format is service \t command \t rpa-name
#    rpa-name is fully qualified, so use rpabbr for Nagios nsca
$timer=time();
open (DAT, ">$dir/$dat") or die "Failed on open $dat: $!\n";
open (RPA,"< $dir/$rpa") or die "Failed on open $rpa: $!\n";
my $status = 0;

@checks = ("get_group_state","get_monitored_parameters");
#@checks = ("get_system_status","get_group_state","get_monitored_parameters");
	
foreach (@checks) {
    @result=&check_rpa($ARGV[0],$_);
    if ($_ eq "get_system_status")	{ &get_system_status(); next; }
    if ($_ eq "get_volume_states")	{ &get_system_status(); next; }
    if ($_ eq "get_group_state")		{ &get_group_state(); next; }
    if ($_ eq "get_monitored_parameters")	{ &get_monitored_parameters(); next; }
    } 
	
printf ($status_list{'1'});
close (RPA);
close (DAT);
print ("\n\t *** Status: $i_status_list{$status} ***\n\n");
exit($status);




#(3) Subroutine to run CLI command
sub check_rpa {
    @cli_line=();		# array for CLI command output
    #print "Checking RPA $_[0] with $_[1]\n";
    open (TMP, "ssh -l monitor $_[0] $_[1] 2>&1 |") || die "Failed on ssh: $!\n";
    while ($line=<TMP>) {
	chomp($string=$line);
	push (@cli_line, $string); }
    close(TMP);
    return @cli_line;
    } # end subroutine

#(4) Subroutine to print formal and debugging outputs
sub print_results {
    #printf "%s\t%s\t%d\t%s\n\n",$_[0],$_[1],$_[2],$_[3];
    if ($_[2] eq 3) { foreach (@result) { print "... $_\n"; } }
    $_[3]=~ s/ +/ /g; # remove extra spaces from msg
#    if (length($_[3])>$msglen) {
#	$_[3]=substr($_[3],0,$msglen-10) . " (more...)"; }
    printf "%s\t%s\t%s\n",$_[1],$i_status_list{$_[2]},$_[3];
#    printf DAT "%s\t%s\t%d\t%s\n",$_[0],$_[1],$_[2],$_[3];
    } # end subroutine

#(5) Subroutine to handle 'get_system_status'
#    Sample command output:
#Sites: 
#  SC: 
#    RPAs: OK
#    Volumes: OK
#    Splitters: OK
#  SR: 
#    RPAs: 
#      ERROR: 1 timeout occurred during the past 60 minutes from hba_0 to 0x5006016841e07db1. Possible causes: slow storage, bad Fibre Channel cable, or other connectivity issue. ; SR ; RPA 1 in SR
#      WARNING: Degradation of outgoing RPA I/O speed occurred during the past 60 minutes. Possible causes: slow storage, bad Fibre Channel cable, or other connectivity issue. ; SR ; RPA 2 in SR
#    Volumes: OK
#    Splitters: OK
#WAN: OK
#System: OK
sub get_system_status {
    $msg="";
    $rc=-1;
    $site="";
    $attr="";
    foreach (@result) {
	@word=split(': ',$_);		# word count begins at 0, not 1
	if ($#word<0) { next; }				# blank line
        if ($word[0] eq "\r") { next; }			# last line ^M
	if ($word[0] eq "Sites") { $rc=0; next; }	# sites header
	if ($#word>0 && $word[1] eq "OK") { next; }	# status OK
	if ($#word==0 && $word[0] =~ m/^\s{2}\S+/) { 	# site name
	    $site=$word[0]; $site=~ s/^\s+//; next; }	# remove spaces & save
	if ($#word==0 && $word[0] =~ m/^\s{4}\S+/) { 	# site attribute
	    $attr=$word[0]; $attr=~ s/^\s+//; next; }	# remove spaces & save
	if ($#word==0 && $word[0] =~ m/^\S+/) { 	# WAN or System
	    $attr=$word[0]; $site=""; next; }		# clear site & save
	if ($#word<1) { $rc=-1; last; }	# anything else should be error message
#	There may be multiple ERROR or WARNING msgs for multiple attributes
	$word[0]=~ s/^\s+//;	# remove leading spaces from ERROR or WARNING
	if ($word[0] eq "ERROR") {
	    if ($rc<2) { $msg=""; }	# replace WARNING msg with ERROR msg
	    $rc=2; }
	elsif ($word[0] eq "WARNING") {
	    if ($rc>1) { next; } 	# don't add WARNING msg to ERROR msg
	    $rc=1; }
	else { $rc=-1; last; }		# unexpected message
	if ($msg ne "") { $msg = $msg . "\n"; }		# append to message
	if ($site ne "") { $msg = $msg . "Site $site "; }
		$msg = $msg . "$attr state is ";
	for ($i=0;$i<=$#word;++$i) { $msg = $msg . "$word[$i]: "; }
        } # end foreach
    if ($rc==0) {
        $msg="States of all components are valid"; }
    elsif ($rc<0) {
        $rc=3; $msg="Unexpected results from command " . $parm[1]; }
    $status = $rc > $status ? $rc : $status;
    &print_results($rpabbr,$parm[0],$rc,$msg);
    } # end subroutine

#(6) Subroutine to handle 'get_group_state'
#    Sample command output:
#Group: 
#  CG_SC_Exchange: 
#    Enabled: YES
#    Transfer source: SC_Exchange
#    Copy: 
#      DR_SC_Exchange: 
#        Enabled: YES
#        Data Transfer: ACTIVE
#        Sync mode: NO
#      SC_Exchange: 
#        Enabled: YES
#        Sync mode:N/A
#  CG_SR_VMWare_GN: 
#    Enabled: YES
#    Transfer source:N/A
#    Copy: 
#      DR_VMWare_GN: 
#        Enabled: YES
#        Data Transfer: PAUSED
#        Sync mode:N/A
#      VMWare_GN: 
#        Enabled: YES
#        Regulation Status: REGULATED
#        Sync mode:N/A
sub get_group_state {
    $msg=" ";
    $rc=-1;
    $ctr=0;
    $group="";
    $sourc="";
    $host="";
    foreach (@result) {
	$_ =~ s/:/: /g;		# This command oddly uses ':' instead of ': '
	$_ =~ s/:  /: /g;	# on some output lines, so fix it globally
        @word=split(': ',$_);           # word count begins at 0, not 1
        if ($#word<0) { next; }                         # blank line
        if ($word[0] eq "\r") { next; }                 # last line ^M
#	Collect names of group, source, and host
        if ($word[0] eq "Group") { $rc=0; next; }       # group header
        if ($#word==0 && $word[0] =~ m/^\s{2}\S+/) {    # group name
            $group=$word[0]; $group=~ s/^\s+//;		# remove spaces & save
	    ++$ctr; $sourc=""; $host=""; next; }	# initialize group
        if ($#word==1 && $word[0] =~ m/^\s{4}Tran.+/) {	# transfer-source
            $sourc=$word[1]; $sourc=~ s/^\s+//; next; }	# remove spaces & save
        if ($#word==0 && $word[0] =~ m/^\s{6}\S+/) {	# source or dest host
            $host=$word[0]; $host=~ s/^\s+//; next; }	# remove spaces & save
#	Check for error conditions
        if ($#word==1 && $word[0] =~ m/^\s+Enab.+/	# group | host enabled?
	    && $word[1] ne "YES" && $rc<2) {
            if ($msg ne "") { $msg = $msg . "\n"; }	# append to message
	    $msg = $msg . "Group $group $host $word[0] is $word[1]";
	    $rc=1; next; }
        if ($#word==1 && $word[0] =~ m/^\s{8}Data.+/	# transfer active?
	    && $word[1] ne "ACTIVE" && $rc<2 ) {
            if ($msg ne "") { $msg = $msg . "\n"; }	# append to message
	    $msg = $msg . "Group $group, source $sourc, copy $host $word[0] is $word[1]";
	    $rc=1; next; }
        if ($#word==1 && $word[0] =~ m/^\s{8}Regu.+/) {	# regulated?
            if ($rc<2) { $msg=""; }     # replace warning msg with error msg
            if ($msg ne "") { $msg = $msg . "\n"; }     # append to message
	    $msg = $msg . "Group $group, source $sourc, copy $host $word[0] is $word[1]";
            $rc=2; next; }
	next; 						# skip all others
        } # end foreach
    if ($rc==0) {
        $msg="States of $ctr groups are valid"; }
    elsif ($rc<0) {
        $rc=3; $msg="Unexpected results from command " . $parm[1]; }
    $status = $rc > $status ? $rc : $status;
    &print_results($rpabbr,$parm[0],$rc,$msg);
    } # end subroutine

#(7) Subroutine to handle 'get_monitored_parameters'
#    Sample command output:
#OK: 
#  Type: Number of consistency groups per RPA cluster
#  Value: 9
#  Limit: 128
#  Type: Number of CLARiiON-based splitters per RPA cluster
#  Site: SC
#  Value: 2
#  Limit: 10
#  Type: Remote replication capacity (TB) per site
#  Value: 13068026118144
#  Limit: 17484811862016
sub get_monitored_parameters {
    $msg="";
    $rc=-1;
    $ctr=0;
    $type="";
    $site="";
    $value=0;
    $limit=0;
    foreach (@result) {
        @word=split(': ',$_);           # word count begins at 0, not 1
        if ($#word<1) { next; }				# should have 2 words
	$word[0]=~ s/^\s+//;				# remove leading spaces
	if ($word[0] eq "Type") { 			# collect param data
	    $rc=0; $type=$word[1]; $site=""; ++$ctr; next; }
	if ($word[0] eq "Site") { $site=$word[1]; next; }
	if ($word[0] eq "Value") { $value=$word[1]; next; }
	if ($word[0] eq "Limit") { $limit=$word[1]; }	# finished param
	if ($value<=$limit) { next; }			# within limit
	$rc=1;		# not clear what severity should be
        if ($msg ne "") { $msg = $msg . ", "; }         # append to message
        if ($site ne "") { $msg = $msg . "Site $site "; }
        $msg = $msg . "$type ($value) exceeds limit ($limit)";
        } # end foreach
    if ($rc==0) {
        $msg="All $ctr parameters are within limits"; }
    elsif ($rc<0) {
        $rc=3; $msg="Unexpected results from command " . $parm[1]; }
    $status = $rc > $status ? $rc : $status;
    &print_results($rpabbr,$parm[0],$rc,$msg);
    } # end subroutine
