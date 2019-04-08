#!/usr/bin/perl

#    Nagios Business Process View and Nagios Business Process Analysis
#    Copyright (C) 2003-2010 Sparda-Datenverarbeitung eG, Nuernberg, Germany
#    Bernd Stroessreuther <berny1@users.sourceforge.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; version 2 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


#Load modules
	use lib ('/srv/eyesofnetwork/nagiosbp-0.9.6/lib');
        #require a good programming
        use strict;
	#db connection module
	use DBI;
        #functions for getting states from the ndo database
        use ndodb;
        #functions for parsing nagios_bp_config file
        use nagiosBp;
	#get installation specific parameters: path variables and so on
	use settings;

	use Data::Dumper;




#some Variables
	my $settings = getSettings();
	my %state_to_rc = ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);
	my $timeout = 10;

	my ($nagios_bp_conf, $bp, $hardstates, $statusinfos, $display, $display_status, $script_out, $info_url, $components, $key, $i);


#get command line parameters
	if (@ARGV == 1 && $ARGV[0] !~ m/^-/)
	{
		# old style of calling this plugin
		# $0 <BusinessProcess>
		$bp = $ARGV[0];
	}
	else
	{
		for ($i=0; $i<@ARGV; $i++)
		{
			if ($ARGV[$i] eq "-b") { $bp = $ARGV[++$i] }
			if ($ARGV[$i] eq "-f") { $nagios_bp_conf = $ARGV[++$i] }
			if ($ARGV[$i] eq "-h" || $ARGV[$i] eq "--help") { help() }
			if ($ARGV[$i] eq "-V" || $ARGV[$i] eq "--version") { version() }
			if ($ARGV[$i] eq "-t" || $ARGV[$i] eq "--timeout") { $timeout = $ARGV[++$i] }
		}
	}

	# missing parameters
	help("You did not give any parameters!\n") if ($bp eq "");

# timeout
	$SIG{ALRM} = sub 
	{
		print "The plugin execution timed out\n";
		exit(3);
	};
	alarm($timeout);

# defaults
	if ($nagios_bp_conf eq "")
	{
		$nagios_bp_conf = "$settings->{'NAGIOSBP_ETC'}/nagios-bp.conf";
	}
	elsif ($nagios_bp_conf !~ m#^/#)
	{
		$nagios_bp_conf = "$settings->{'NAGIOSBP_ETC'}/$nagios_bp_conf";
	}

#read the status data from the db
	($hardstates, $statusinfos) = &getStates();
#	foreach $key (keys %$hardstates)
#	{
#		if ( $hardstates->{$key} ne "OK")
#		{
#			print "$key $hardstates->{$key}\n";
#		}
#	}

#parse nagios-bp.conf (our own config file)
	($display, $display_status, $script_out, $info_url, $components) = &getBPs($nagios_bp_conf, $hardstates, "false");

# timeout test
	#for ($i=0; $i<500; $i++)
	#{
	#        system("cat /var/log/messages >/dev/null");
	#        print "$i ";
	#}

# reset timeout
	alarm(0);

# evaluating business process
	if ($hardstates->{$bp} eq "" || $display->{$bp} eq "")
	{
		print "Business Process UNKNOWN: Business Process $bp is not defined\n";
		exit(3);
	}
	else
	{
		if ( $hardstates->{$bp} eq "OK")
		{######################
			print "$hardstates->{$bp}: $display->{$bp}\n";
		}
		else
		{
			my $bp_Component = $components->{$bp};
			$bp_Component =~ s/\&//g;
			$bp_Component =~ s/  / /g;
		######################
			print "$hardstates->{$bp} ON ($display->{$bp}) cause ";
			foreach( split( / /, $bp_Component ) )
			{
				if ( $hardstates->{$_} ne "OK" )
				{
					print "$hardstates->{$_} on $_ ";
					my $sub_bp_Component = $components->{$_};
					$sub_bp_Component =~ s/\&//g;
					$sub_bp_Component =~ s/  / /g;
					foreach( split( / /, $sub_bp_Component ) )
					{
						if ( $hardstates->{$_} ne "OK" )
						{
							print "---> Composant:$_ ";
						}
					}
				}
			}
			print "\n";
		}
		exit($state_to_rc{$hardstates->{$bp}});
	}

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
