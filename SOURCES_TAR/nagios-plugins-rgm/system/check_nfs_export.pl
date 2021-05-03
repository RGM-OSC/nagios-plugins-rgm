#!/usr/bin/perl -w
##
##
#
use strict;
my $version = '0.9';
my $host;
my $path;
my $showmount;
use Getopt::Long;

####################################################################
# get commandline options
my $result = GetOptions 
	('H|host=s'    => \$host,
	'p|path=s'    => \$path,
	'c|command=s' => \ ($showmount = '/usr/sbin/showmount'));

$result || usage();
($host && $path) or usage();

###################################################################
# make sure showmount is executable
-x $showmount || finish(3, "$showmount not executable");

###################################################################
# run showmount and check output
open(SHOWMOUNT, "$showmount -e $host|") || finish(3, "Could NOT run $showmount $!");
while (my $line = <SHOWMOUNT>) {
	if ($line =~ /^$path\s+/) {
		close SHOWMOUNT;
		##########################################################
		# mount is ok, exit OK
		finish(0, "NFS mount $host:$path");
	}
}

###################################################################
# if we get here, showmount didn't find the command 
finish(2,"NFS mount $host:$path is NOT available!");

###################################################################
sub finish {
	my $exitcode = shift;
	my $message  = shift;

	my @ERRORS = qw(OK WARNING CRITICAL UNKNOWN);
	print "$ERRORS[$exitcode]: $message\n";
	exit $exitcode;
}
sub usage {
	my $usage = "Usage error!\n\n$0 -H <hostname> -p <path> [-c <showmount_command>]
		-H hostname to check
		-p path that is supposed to be exported
		-c showmount command, defaults to /usr/sbin/showmount\n\nVersion $version\n";
	finish(3, $usage);
}
