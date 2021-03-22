#!/usr/bin/perl

#    Pan !


	use lib ('/srv/eyesofnetwork/nagiosbp-0.9.6/lib');
        use strict;
	use DBI;

	my $settings = getSettings();
	my %state_to_rc = ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);
	my $timeout = 10;



#get command line parameters
	if (@ARGV == 1 && $ARGV[0] !~ m/^-/)
	{
		$borne = $ARGV[0];
	}
	else
	{
		for ($i=0; $i<@ARGV; $i++)
		{
			if ($ARGV[$i] eq "-b") { $borne = $ARGV[++$i] }
			if ($ARGV[$i] eq "-u") { $ssh_user = $ARGV[++$i] }
			if ($ARGV[$i] eq "-p") { $ssh_pass = $ARGV[++$i] }
			if ($ARGV[$i] eq "-h" || $ARGV[$i] eq "--help") { help() }
			if ($ARGV[$i] eq "-V" || $ARGV[$i] eq "--version") { version() }
			if ($ARGV[$i] eq "-t" || $ARGV[$i] eq "--timeout") { $timeout = $ARGV[++$i] }
		}
	}

	# missing parameters
	help("You did not give any parameters!\n") if ($bp eq "");

	$SIG{ALRM} = sub 
	{
		print "The plugin execution timed out\n";
		exit(3);
	};
	alarm($timeout);



# online help
	sub help
	{
		#               1         2         3         4         5         6         7         8
		#      12345678901234567890123456789012345678901234567890123456789012345678901234567890
		print $_[0];
		print "\nuse as follows:\n";
		print "$0 -b <BusinessProcess> [-f <config_file>] [-t <timeout>]\n";
		print "or\n";
		print "$0 -h|--help\n\n";
		print "or\n";
		print "$0 -v|--version\n\n";
		print "where\n\n";
		print "<BusinessProcess>   is the short name of the business process\n";
		print "                    you want to check (see Your business process config file to\n";
		print "                    find the name)\n";
		print "<config_file>       is the name of the file where the <BusinessProcess> is\n";
		print "                    defined\n";
		print "                    if it starts with a / it is considered to be a absolut path\n";
		print "                    otherwise it is looked for in $settings->{'NAGIOSBP_ETC'}\n";
		print "                    default is $settings->{'NAGIOSBP_ETC'}/nagios-bp.conf\n";
		print "<timeout>           the plugin execution times out after this number of seconds\n";
		print "                    defaults to 10 seconds\n";
		print "-h or --help        to display this help message\n\n";
		print "-V or --version     to display version information\n\n";
		exit(3);
	}

# online help
	sub version
	{
		print "Version " . getVersion() . "\n";
		print "This program is free software licensed under the terms of the GNU General Public\n";
		print "License version 2.\n";
		exit(3);
	}
