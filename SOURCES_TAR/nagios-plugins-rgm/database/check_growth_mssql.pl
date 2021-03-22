#!/usr/bin/perl -w
use strict;
#
use DBI;
use Getopt::Long;

my $server;
my $user;
my $password;

use vars qw($critical $warning);

Getopt::Long::Configure('bundling');
GetOptions
         ("S=s"   => \$server,          "server=s"     => \$server,
         "u=s"   => \$user,          "user=s"     => \$user,
         "p=s"   => \$password,          "password=s"     => \$password,
         "w=i"   => \$warning,         "warning=i"    => \$warning,
         "c=i"   => \$critical,        "critical=i"   => \$critical);

my $data_source = "dbi:Sybase:$server";
## Connect to the data source and get a handle for that connection.
my $dbh = DBI->connect($data_source, $user, $password)
    or die "Can't connect to $data_source: $DBI::errstr";
#
#    # This query generates a result set with one record in it.
my $sql = "SELECT sys.databases.name, sys.master_files.type_desc, ROUND(CAST(size AS FLOAT) / CAST(max_size AS FLOAT) * 100,0) AS used_space FROM sys.databases JOIN sys.master_files ON sys.databases.database_id=sys.master_files.database_id WHERE max_size > 0 AND sys.databases.name <> 'master' AND sys.databases.name <> 'model' AND sys.databases.name <> 'msdb' AND sys.databases.name <> 'tempdb'";
    my $sth = $dbh->prepare($sql)
        or die "Can't prepare statement: $DBI::errstr";
        $sth->execute();
	my @row;
	my $output;
	my $value;
	my $error = "OK";
	my $final_error;
	my $error_code = 0;

	while (@row = $sth->fetchrow_array) {
          $value = $row[2];
	  if($value > $critical){
	    $error = "CRITICAL";
	    $final_error = "CRITICAL";
	    $error_code = 2;
	  }
	  elsif($value > $warning){
	    $error = "WARNING";
	    $error_code = 1;
	  }
	  $output .= join(", ", @row). "\n";

        }
	if($final_error){
	  $error = $final_error;
	  $error_code = 2;
	}

 	print "$error, Click for details\n$output";
	$sth->finish();
        $dbh->disconnect;
	exit $error_code;
