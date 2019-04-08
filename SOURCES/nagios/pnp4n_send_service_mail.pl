#!/usr/bin/perl -w 
#
# First we explicitly switch off the Nagios embbeded Perl Interpreter
# nagios: -epn
# ######################### pnp4n_send_service_mail.pl ################ #
# Date    : May 29, 2012                                                #
# Purpose : Script to send out Nagios service e-mails.\n";              #
# Author  : Frank Migge (support at frank4dd dot com), Robert Becht     #
# Help    : http://nagios.frank4dd.com/howto                            #
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt                   #
#           Written for and verified with Nagios version 3.3.1          #
# Help    : ./pnp4n_send_service_mail.pl -h                             #
#                                                                       #
# Version : 1.0 initial release                                         #
# Version : 1.1 add multipart MIME and logo                             #
# Version : 1.2 cleanup mail body generation code                       #
# Version : 1.3 use environment variables for Nagios data handoff       #
# Version : 1.4 add the performance graph image if available            #
#           this has been implemented for Nagiosgraph v0.9.1            #
# Version : 1.5 add -g for using $CONTACTGROUPMEMBERS$ macro            #
#           multi-language support for en|de|fr|jp, extendable          #
#           enhanced debug, version by Robert Becht                     #
#           the script now reads logo's from file                       #
# Version : 1.6 Finally worked with PNP4Nagios by pulling the graphs    #
#           from the web. Enhancements in debug, language support, etc  #
# Version : 1.7 Dedicating the script to PNP4Nagios only, removing code #
#           for Nagiosgraph + adding authentication and documentation.  #
#                                                                       #
# Depends : perl-Mail-Sendmail (Mail::Sendmail)                         #
#           perl-MIME-tools (MIME::Base64)                              #
#           perl-libwww-perl-6.03-2.1.2.noarch (LWP)                    #
#           libnetpbm (conversion png-to-jpg, this is optional)         #
#           netpbm (see above)                                          #
# ##################################################################### #
use Getopt::Long;
use Mail::Sendmail;
use Digest::MD5 qw(md5_hex);
use MIME::Base64;
use File::Temp;
use strict;
use warnings;
use vars qw( $logo_id $graph_id $tmpfile $land $tbl $var
             %param_vars $elapse $tstamp $tstart $img_get);

# The version of this script
my $Version            ='1.7.3';
# the sender e-mail address to be seen by recipients
my $mail_sender        = "EyesOfNetwork Monitoring <eyesofnetwork\@eyesofnetwork.com>";
# The Nagios CGI URL for integrated service links
my $nagios_cgiurl      = "http://supervision/thruk/cgi-bin";
# Here we define a simple HTML stylesheet to be used in the HTML header.
my $html_style         = "body {text-align: center; font-family: Verdana, sans-serif; font-size: 10pt;}\n"
                       . "img.logo {float: left; margin: 10px 10px 10px; vertical-align: middle}\n"
                       . "span {font-family: Verdana, sans-serif; font-size: 12pt;}\n"
                       . "table {text-align:center; margin-left: auto; margin-right: auto;}\n"
                       . "th {white-space: nowrap;}\n"
                       . "th.even {background-color: #D9D9D9;}\n"
                       . "td.even {background-color: #F2F2F2;}\n"
                       . "th.odd {background-color: #F2F2F2;}\n"
                       . "td.odd {background-color: #FFFFFF;}\n"
                       . "th,td {font-family: Verdana, sans-serif; font-size: 10pt; text-align:left;}\n"
                       . "th.customer {width: 600px; background-color: #004488; color: #ffffff;}";
my $table_size         = "600px";
my $header_size        = "180px";
my $data_size          = "420px";
my $debugtables        = "<br>\n";

# ########################################################################
# For tests using the -t/--test option, if we want to see PNP4Nagios
# graphs we need to set a valid host name and service name below.
# ########################################################################
my $test_host          = "susie114";    # existing host in PNP4Nagios
my $test_service       = "os_cpu_load"; # existing services in PNP4nagios

# ########################################################################
# Here we set the URL to pick up the RRD data files for the optional graph
# image generation. Modified by Robert Becht for use with PNP4Nagios.
# The PNP4Nagios URL : if not used we can set $pnp4nagios_url = undef;
# ########################################################################
my $pnp4nagios_url     = "http://supervision/pnp4nagios";
my $graph_history      = 48; # in hours, a good range is between 12...48

# ########################################################################
# If web authentication is needed, configure the access parameters below:
# ########################################################################
my $pnp4nagios_auth    = undef; # $pnp4nagios_auth    = "true";
my $server_port        = undef; # $server_port        = "nagios.frank4dd.com:80";
my $auth_name          = undef; # $auth_name          = "pnp4nagios";
my $web_user           = undef; # $web_user           = "pnp4nget";
my $web_pass           = undef; # $web_pass           = "mypass";

# ########################################################################
# SMTP related data: If the commandline argument -H/--smtphost was not
# given, we use the provided value in $o_smtphost below as the default.
# If the mailserver requires auth, an example is further down the code.
# ########################################################################
my $o_smtphost         = "192.168.1.64";
my $domain 	       = "\@frank4dd.com"; # this is only for -g groups
my @listaddress        = ();

# ########################################################################
# This is the logo image file, the path must point to a valid JPG, GIF or
# PNG file, i.e. the nagios logo. Best size is rectangular up to 160x80px.
# example: [nagioshome]/share/images/NagiosEnterprises-whitebg-112x46.png
# ########################################################################
my $logofile = "";

# ########################################################################
# Because our mail system being Lotus Notes, which is not supporting PNG
# images, we must convert them from PNG to JPG before we can continue.
# Set $jpg_workaround = true if your mail client has the same trouble.
# ########################################################################
my $jpg_workaround = undef;

# ########################################################################
# Here I define the HTML color values for each Nagios notification type.
# There is one extra called TEST for sending a test e-mail from the cmdline
# outside of Nagios. The color values are used for highlighting the
# background of the notification type cell.
# ########################################################################
my %NOTIFICATIONCOLOR=('PROBLEM'=>'#FF8080','RECOVERY'=>'#80FF80','ACKNOWLEDGEMENT'=>'FFFF80',
                       'DOWNTIMESTART'=>'80FFFF','DOWNTIMEEND'=>'80FF80','DOWNTIMECANCELLED'=>'FFFF80',
                       'FLAPPINGSTART'=>'#FF8080','FLAPPINGSTOP'=>'#80FF80',' FLAPPINGDISABLED'=>'FFFF80',
                       'TEST'=>'80FFFF');

# ########################################################################
# language translated message text: $language{$land}{'A'}  (=Customer)
# You can simply add here your translation...
# ########################################################################
my %language = ('en' => { 'A' => 'Customer',
                          'B' => 'Notification Type',
                          'C' => 'Service Name',
                          'D' => 'Service Status',
                          'E' => 'Service Group',
                          'F' => 'Service Data',
                          'G' => 'Hostname',
                          'H' => 'Hostalias',
                          'I' => 'IP Address',
                          'J' => 'Hostgroup',
                          'K' => 'Event Time',
                          'L' => 'Author',
                          'M' => 'Comment',
                          'N' => 'EyesOfNetwork Monitoring System Notification',
                          'O' => 'Generated by EyesOfNetwork, the OpenSource monitoring solution' },
                'fr' => { 'A' => 'Utilisateur',
                          'B' => 'Type de notification',
                          'C' => 'Nom du service',
                          'D' => 'Statut du service',
                          'E' => 'Groupe du service',
                          'F' => 'Données',
                          'G' => 'Nom d\'hôte',
                          'H' => 'Alias d\'hôte',
                          'I' => 'Adresse IP',
                          'J' => 'Groupe d\'hôte',
                          'K' => 'Heure de la notification',
                          'L' => 'Auteur',
                          'M' => 'Commentaire',
                          'N' => 'Notification de la surveillance EyesOfNetwork',
                          'O' => 'Généré par EyesOfNetwork, le système de surveillance OpenSource' },
                'de' => { 'A' => 'Anwender',
                          'B' => 'Nachrichtentyp',
                          'C' => 'Dienstname',
                          'D' => 'Dienstzustand',
                          'E' => 'Dienstgruppe',
                          'F' => 'Dienstinformationen',
                          'G' => 'Systemname',
                          'H' => 'Systemalias',
                          'I' => 'System IP Adresse',
                          'J' => 'Systemgruppe',
                          'K' => 'Meldungsdatum',
                          'L' => 'Author',
                          'M' => 'Kommentar',
                          'N' => 'EyesOfNetwork Überwachungssytem Meldung',
                          'O' => 'Erstellt mit EyesOfNetwork, dem OpenSource Überwachungssytem' },
                'jp' => { 'A' => '顧客名',
                          'B' => '通知の種類',
                          'C' => 'サービス名',
                          'D' => 'サービスの状態',
                          'E' => 'サービスグループ',
                          'F' => 'サービスデータ出力',
                          'G' => 'ホスト名',
                          'H' => 'ホストの別名',
                          'I' => 'IPアドレス',
                          'J' => 'ホストグループ',
                          'K' => 'イベントの日付と時刻',
                          'L' => '投稿者',
                          'M' => 'コメント',
                          'N' => 'EyesOfNetwork 監視システムの通知',
                          'O' => 'このメッセージはオープンソースの監視システムEyesOfNetworkで生成されています。' });

####### Global Variables - No changes necessary below this line ##########
my $o_hostfunction     = $ENV{NAGIOS__HOSTSERVERFUNCTION};
# Nagios notification type, i.e. PROBLEM
my $o_notificationtype = $ENV{NAGIOS_NOTIFICATIONTYPE};
# Nagios notification author (if avail.)
my $o_notificationauth = $ENV{NAGIOS_NOTIFICATIONAUTHOR};
# Nagios notification comment (if avail.)
my $o_notificationcmt  = $ENV{NAGIOS_NOTIFICATIONCOMMENT};
# Nagios service description
my $o_servicedesc      = $ENV{NAGIOS_SERVICEDESC};
# Nagios service state
my $o_servicestate     = $ENV{NAGIOS_SERVICESTATE};
# Nagios service group the service belongs to
my $o_servicegroup     = $ENV{NAGIOS_SERVICEGROUPNAME};
# Nagios monitored host name
my $o_hostname         = $ENV{NAGIOS_HOSTNAME};
# Nagios monitored host alias
my $o_hostalias        = $ENV{NAGIOS_HOSTALIAS};
# Nagios host group the host belongs to
my $o_hostgroup        = $ENV{NAGIOS_HOSTGROUPNAME};
# Nagios monitored host IP address
my $o_hostaddress      = $ENV{NAGIOS_HOSTADDRESS};
# Nagios service check output data
my $o_serviceoutput    = $ENV{NAGIOS_SERVICEOUTPUT};
# Nagios date when the event was recorded
my $o_datetime         = $ENV{NAGIOS_LONGDATETIME};
# The recipients defined in $CONTACTEMAIL$
my $o_to_recipients    = $ENV{NAGIOS_CONTACTEMAIL};
# Modified by Robert Becht for using $CONTACTGROUPEMEMBERS$ in nagios.conf
my $recipient_group    = $ENV{NAGIOS_CONTACTGROUPMEMBERS};

# The next variables are provided through args
my $o_to_group         = undef; # this flag is only set with the -g option
my $o_cc_recipients    = undef; # The recipients defined in $CONTACTADDRESS1$
my $o_bcc_recipients   = undef; # The recipients defined in $CONTACTADDRESS2$
my $o_format           = "text";# The e-mail output format (default: text)
my $o_addurl           = undef; # flag to add Nagios GUI URLs to HTML e-mails
my $o_language         = undef; # The e-mail output language
my $o_lang_def         = "en";  # The e-mail output language default
my $o_customer         = undef; # Company name and contract number for service providers
my $o_help             = undef; # We want help
my $o_verb             = undef; # verbose mode
my $o_version          = undef; # print version
my $o_test             = undef; # generate a test message

# These variables are used in various subroutines
my $text_msg           = undef; # the plaintext notification
my $html_msg           = undef; # the HTML-formatted notification
my $graphfile          = undef; # if we generate graphs, the tmp file location
my $logo_img           = undef; # base64-encoded logo
my $logo_type          = undef; # logo image file format (jpg, gif, or png)
my $graph_img          = undef; # base64-encoded graph
my $graph_type         = undef; # graph image file format (jpg, gif, or png)
my $boundary           = undef; # unique string for multi-part emails
my %mail;

# $empty_img is a base64-encoded, white 1x1 pixel gif image, we
# use it if the logo or the pnp4nagios graph cannot be found.
my $empty_img          = "R0lGODlhAQABAJEAAAAAAP///////wAAACH5BAEAAAIALAAAAAABAAEAAAICTAEAOw==";

# ########################################################################
# subroutine defintions below
# ########################################################################

# ########################################################################
# p_version returns the program version
# ########################################################################
sub p_version { print "$0 nagios_send_service_mail.pl version : $Version\n"; }

# ########################################################################
# print_usage returns the program usage
# ########################################################################
sub print_usage {
    print "Usage: $0 [-v] [-V] [-h] [-t] [-H <SMTP host>] [-p <customername>]
       [-r <to_recipients> or -g <to_group>] [-c <cc_recipients>] [-b <bcc_recipients>] 
       [-f <text|html|multi|graph>] [-u] [-l <en|jp|fr|de|(or other languages if added)]\n";
}

# ########################################################################
# help returns the program help message
# ########################################################################
sub help {
   print "\nNagios e-mail notification script for service events, version ",$Version,"\n";
   print "This version was developed for inclusion of PNP4Nagios performance graphs.\n";
   print "GPL licence, (c)2012 Frank Migge\n\n";
   print_usage();
   print <<EOT;

This script takes over Nagios e-mail notifications by receiving the Nagios state
information, formatting the e-mail and sending it out through an SMTP gateway.

-v, --verbose
    print extra debugging information 
-V, --version
    prints version number
-h, --help
    print this help message
-t, --test
    generates a test message together with -r, --to-recipients
-H, --smtphost=HOST
    name or IP address of SMTP gateway
-p, --customer="customer name and contract #"
  optionally, add the customer name and contract for service providers
-r, --to-recipients
   override the Nagios-provided \$CONTACTEMAIL\$ list of to: recipients
-g, --to-group-recipients \$CONTACTGROUPMEMBERS\$
    instead of -r, use the list of contactgroup members and complete the mail
    address with the hard defined \$domain in this script. This is only possible
    when the contact name "abcd" works under the address "abcd\@domain".
-c, --cc-recipients
    the Nagios-provided \$CONTACTADDRESS1\$ list of cc: recipients
-b, --bcc-recipients
    the Nagios-provided \$CONTACTADDRESS2\$ list of bcc: recipients
-f, --format='text|html|multi|graph'
    the email format to generate: plain ASCII text, HTML, multipart S/MIME with
    a logo, or multipart S/MIME - adding the PNP4Nagios performance graph image
-u, --addurl
   this adds URL's to the Nagios web GUI for check status, host and hostgroup
   views into the html mail, requires -f html, multi or graph
-l, --language='en|jp|fr|de|(or what you defined in this script)'
    the prefered e-mail language. The content-type header is hard-coded to UTF-8.
    Check if your recipients require a different characterset encoding.

Extra: Additional debug output can be generated. Within Nagios, select a host
       and choose "Send custom host notification". Entering text, including the
       keyword "email-debug" into the "Comment" field will add additional tables
       containing a list of values for important Nagios and script variables.

EOT
}

# ########################################################################
# verb creates verbose output
# ########################################################################
sub verb { my $t=shift; print $t,"\n" if defined($o_verb); }

# ########################################################################
# unique content ID are needed for multipart messages with inline logos
# ########################################################################
sub create_content_id {
  my $unique_string  = rand(100);
  $unique_string     = $unique_string . substr(md5_hex(time()),0,23);
  $unique_string     =~ s/(.{5})/$1\./g;
  my $content_id     = qq(part.${unique_string}\@) . "MAIL";
  $unique_string     = undef;
  return $content_id;
}

# ########################################################################
# create_boundary creates the S/MIME multipart boundary strings
# ########################################################################
sub create_boundary {
  my $unique_string  = substr(md5_hex(time()),0,24);
  $boundary          = '======' . $unique_string ;
  $unique_string     = undef;
}

sub unknown_arg {
  print_usage();
  exit -1;
}

# ########################################################################
# create_address from the groupmembers list (Add by Robert Becht)
# ########################################################################
sub create_address {
  chomp($recipient_group);
  my @mlist = split(",",$recipient_group);
  foreach (@mlist) {
    my $maddress = "$_"."$domain";
    push(@listaddress,$maddress);
  }
  $recipient_group = join(",",@listaddress);
  return ($recipient_group);
}

# ########################################################################
# check_options checks and processes the commandline options given
# ########################################################################
sub check_options {
  Getopt::Long::Configure ("bundling");
  GetOptions(
      'v'     => \$o_verb,            'verbose'           => \$o_verb,
      'V'     => \$o_version,         'version'           => \$o_version,
      'h'     => \$o_help,            'help'              => \$o_help,
      't'     => \$o_test,            'test'              => \$o_test,
      'H:s'   => \$o_smtphost,        'smtphost:s'        => \$o_smtphost,
      'p:s'   => \$o_customer,        'customer:s'        => \$o_customer,
      'r:s'   => \$o_to_recipients,   'to-recipients:s'   => \$o_to_recipients,
      'g:s'   => \$o_to_group,	    'to-group-recipients' => \$o_to_group,
      'c:s'   => \$o_cc_recipients,   'cc-recipients:s'   => \$o_cc_recipients,
      'b:i'   => \$o_bcc_recipients,  'bcc-recipients:s'  => \$o_bcc_recipients,
      'f:s'   => \$o_format,          'format:s'          => \$o_format,
      'u'     => \$o_addurl,          'addurl'            => \$o_addurl,
      'l:s'   => \$o_language,        'language:s'        => \$o_language
  ) or unknown_arg();

  # Basic checks
  if (defined ($o_help)) { help(); exit 0};
  if (defined($o_version)) { p_version(); exit 0};
  if ((! defined($o_to_recipients)) && (! defined($o_to_group))) { # no recipients provided
    print "Error: no recipients have been provided\n"; print_usage(); exit -1}
  else {
    if (! defined($o_to_group)) {
      %mail = ( To     => $o_to_recipients,
                From   => $mail_sender,
                Sender => $mail_sender ); }
    else { 
      &create_address;
      %mail = ( To     => $recipient_group,
                From   => $mail_sender,
                Sender => $mail_sender ); }
  }

  if ( $o_format ne "text"  && $o_format ne "html"
    && $o_format ne "multi" && $o_format ne "graph") # wrong mail format
    { print "Error: wrong e-mail format.\n"; print_usage(); exit -1}

  if (defined($o_addurl) && $o_format eq "text")
    { print "Error: cannot add URL's to text.\n"; print_usage(); exit -1}
  if (defined($o_test)) { create_test_data(); };

  # Modified by Robert Becht to support additional languages
  # if no language has been requested, try to determine default from OS
 if (! defined($o_language)) {
    # if environment $LANG is set, try to extract the first two country chars, i.e. "en|de|fr"
    if ($ENV{LANG} eq "C" || $ENV{LANG} eq "POSIX") { $land = "en"; }
    else { ($land, my $rem) = split('_',$ENV{LANG}, 2); }
  } else { $land = $o_language; }
  # Last resort: Set "English" if the requested language is not supported by our script
  if (! $language{$land}{'A'}) { $land = $o_lang_def; }
}

# ########################################################################
# if -t or --test, we need to create sample test data to for sending out.
# Most data is hardcoded. For graph generation, host and service names
# must be valid so the script can pick up the graph image from PNP4Nagios.
# ########################################################################
sub create_test_data {
  if (! defined($o_customer)){         $o_customer         = "ACME Corporation";}
  if (! defined($o_notificationtype)){ $o_notificationtype = "TEST";}
  if (! defined($o_servicestate)){     $o_servicestate     = "UNKNOWN";}
  if (! defined($o_hostname)){         $o_hostname         = $test_host;}
  if (! defined($o_hostalias)){        $o_hostalias        = "Test host alias (placeholder)";}
  if (! defined($o_hostaddress)){      $o_hostaddress      = "127.0.0.1";}
  if (! defined($o_hostgroup)){        $o_hostgroup        = "Linux Servers";}
  if (! defined($o_servicedesc)){      $o_servicedesc      = $test_service;}
  if (! defined($o_servicegroup)){     $o_servicegroup     = "performance checks";}
  if (! defined($o_datetime)){         $o_datetime         = `date`;}
  if (! defined($o_serviceoutput)){    $o_serviceoutput    = "Test output for this service";}
  if (! defined($o_notificationauth)){ $o_notificationauth = "John Doe";}
  # Setting the keyword "email-debug" in the notification comment below triggers the creation of debug tables
  if (! defined($o_notificationcmt)){  $o_notificationcmt  = "Service notification test message including email-debug";} 
}

# ########################################################################
# Create a plaintext message -> $text_msg
# ########################################################################
sub create_message_text {
  $text_msg = $language{$land}{'N'}."\n"
            . "=====================================\n\n";

  # if customer name was given for service providers, display it here
  if ( defined($o_customer)) {
    $text_msg .= $language{$land}{'A'} . ": $o_customer\n";
  }

  $text_msg .=$language{$land}{'B'} . ": $o_notificationtype\n"
            . $language{$land}{'C'} . ": $o_servicedesc\n"
            . $language{$land}{'D'} . ": $o_servicestate\n"
            . $language{$land}{'E'} . ": $o_servicegroup\n"
            . $language{$land}{'F'} . ": $o_serviceoutput\n\n"
            . $language{$land}{'G'} . ": $o_hostname\n"
            . $language{$land}{'H'} . ": $o_hostalias\n"
            . $language{$land}{'I'} . ": $o_hostaddress\n"
            . $language{$land}{'J'} . ": $o_hostgroup\n"
            . $language{$land}{'K'} . ": $o_datetime\n\n";

  # if author and comment data has been passed from Nagios
  # and these variables have content, then we add two more columns
  if ( ( defined($o_notificationauth) && defined($o_notificationcmt) ) &&
       ( ($o_notificationauth ne "") && ($o_notificationcmt ne "") ) ) {
    $text_msg .= $language{$land}{'L'} . ": $o_notificationauth\n"
              .  $language{$land}{'M'} . ": $o_notificationcmt\n\n";
    
  }

  $text_msg .= "-------------------------------------\n"
            . $language{$land}{'O'} . "\n";
}

# ########################################################################
# Create a HTML message -> $html_msg, per flags include URL's and IMG's
# ########################################################################
sub create_message_html {
  # Start HTML message definition
  $html_msg = "<html><head><style type=\"text/css\">$html_style</style></head><body>\n"
            . "<table width=$table_size><tr>\n";

  if ($o_format eq "multi" || $o_format eq "graph") {
    $logo_id  = create_content_id();
    $html_msg .= "<td><img class=\"logo\" src=\"cid:$logo_id\"></td>"
              .  "<td><span>$language{$land}{'N'}</span></td></tr><tr>\n";
  } else {
    $html_msg .= "<th colspan=2><span>$language{$land}{'N'}</span></th></tr><tr>\n"; }

  if ( defined($o_customer)) {
    $html_msg .= "<th colspan=2 class=customer>$o_customer</th></tr><tr>\n"; }

  $html_msg .= "<th width=$header_size class=even>$language{$land}{'B'}:</th>\n"
            . "<td bgcolor=$NOTIFICATIONCOLOR{$o_notificationtype}>\n"
            . "$o_notificationtype</td></tr>\n"
            . "<tr><th class=odd>$language{$land}{'C'}:</th><td>$o_servicedesc</td></tr>\n"
            . "<tr><th class=even>$language{$land}{'E'}:</th><td class=even>\n";

  # The Servicegroup URL http://<nagios-web>/cgi-bin/status.cgi?servicegroup=$SERVICEGROUPNAME$&style=overview
  # This URL shows the service group table listing ofthe hosts that have this service
  if (defined($o_addurl)) {
    $html_msg .= "<a href=\"$nagios_cgiurl/status.cgi?servicegroup=" 
              . urlencode($o_servicegroup) . "&style=overview\">$o_servicegroup</a>";
  }
  else { $html_msg  .= $o_servicegroup; }

  $html_msg .= "</td></tr>\n"
            . "<tr><th class=odd>$language{$land}{'D'}:</th><td>$o_servicestate</td></tr>\n"
            . "<tr><th class=even>$language{$land}{'F'}:</th><td class=even>\n";

  # The ServiceOutput URL http://<nagios-web>/cgi-bin/extinfo.cgi?type=2&host=$HOSTNAME$&service=$SERVICEDESC$
  # This URL shows the full service details and commands for service management (ack, re-check, disable, etc)
  if (defined($o_addurl)) {
    $html_msg .= "<a href=\"$nagios_cgiurl/extinfo.cgi?type=2&host=" . urlencode($o_hostname) 
              . "&service=" . urlencode($o_servicedesc) . "\">$o_serviceoutput</a>\n";

    # If the graph image wasn't empty, We add an additional link for PNP4Nagios
    if ($o_format eq "graph" && $graph_type ne "gif") {
      $html_msg .=  ", see also <a href=\"$pnp4nagios_url/graph?host=" . urlencode($o_hostname)
                . "&srv=" . urlencode($o_servicedesc) . "\">PNP4Nagios</a>\n"; }
  }
  else { $html_msg .= $o_serviceoutput; }
  
  $html_msg .= "</td></tr>\n"
            .  "<tr><th class=odd>$language{$land}{'G'}:</th><td>\n";

  # The Hostname URL http://<nagios-web>/cgi-bin/status.cgi?host=$HOSTNAME$&style=detail
  # this URL shows the host and all services underneath it
  if (defined($o_addurl)) {
    $html_msg .= "<a href=\"$nagios_cgiurl/status.cgi?host=" . urlencode($o_hostname) 
              . "&style=detail\">$o_hostname</a>";
  }
  else { $html_msg .= $o_hostname; }
  
  $html_msg .= "</td></tr>\n"
            . "<tr><th class=even>$language{$land}{'H'}:</th><td class=even>$o_hostalias</td></tr>\n"
            . "<tr><th class=odd>$language{$land}{'I'}:</th><td>$o_hostaddress</td></tr>\n"
            . "<tr><th class=even>$language{$land}{'J'}:</th><td class=even>\n";
  
  # The Hostgroup URL http://<nagios-web>/cgi-bin/status.cgi?hostgroup=$HOSTGROUPNAME$&style=overview
  # This URL shows the hostgroup table listing for all individual hosts that belong to it
  if (defined($o_addurl)) {
    $html_msg .= "<a href=\"$nagios_cgiurl/status.cgi?hostgroup=" 
              . urlencode($o_hostgroup) ."&style=overview\">$o_hostgroup</a>";
  }
  else { $html_msg .= $o_hostgroup; }
  
  $html_msg .= "</td></tr>\n"
            .  "<tr><th class=odd>$language{$land}{'K'}:</th><td>$o_datetime</td></tr>\n";

  # If the author and comment data has been passed from nagios
  # and these variables have content, then we add two more columns
  if ( ( defined($o_notificationauth) && defined($o_notificationcmt) ) &&
       ( ($o_notificationauth ne "") && ($o_notificationcmt ne "") ) ) {
    $html_msg .= "<tr><th class=even>$language{$land}{'L'}:</th>\n"
              . "<td class=even>$o_notificationauth</td></tr>\n"
              . "<tr><th class=odd>$language{$land}{'M'}:</th>\n"
              . "<td>$o_notificationcmt</td></tr>\n";
  }

  $html_msg .= "</table><br>\n";

  # if we got the graph format and a image has been generated, we add it here
  if (defined($graph_img) && $o_format eq "graph") {
    $graph_id = create_content_id();
    $html_msg .= "<img src=\"cid:$graph_id\">\n";
  } 

  # add the Nagios footer tag line here
  $html_msg .= "<br><hr>\n$language{$land}{'O'}\n<hr>\n";

  # add the extra debugtables if verbose output had been requested,
  # or if the notification command contains the keyword "email-debug"
  if (defined($o_notificationcmt) && ($o_notificationcmt =~ m/email-debug/i)
  || defined($o_verb)) {
    &create_debugtable;
    $html_msg .= $debugtables;
  }

  # End HTML message definition
  $html_msg .= "</body></html>\n";
}

# #######################################################################
# urlencode() URL encode a string
# #######################################################################
sub urlencode {
  my $urldata = $_[0];
  my $MetaChars = quotemeta( ';,/?\|=+)(*&^%$#@!~`:');
  $urldata =~ s/([$MetaChars\"\'\x80-\xFF])/"%" . uc(sprintf("%2.2x",         ord($1)))/eg;
  $urldata =~ s/ /\+/g;
  return $urldata;
}

# ########################################################################
# b64encode_image(filename) converts a existing binary source image file
# into a base64-image string.
# ########################################################################
sub b64encode_img {
  my($inputfile) = @_;
  open (IMG, $inputfile) or verb("b64encode_img: Cannot read source image file: $inputfile - $!");
  binmode IMG; undef $/;
  my $b64encoded_img = encode_base64(<IMG>);
  close IMG;
  verb("b64encode_img: completed conversion of source image file: $inputfile - $!");
  return $b64encoded_img;
}

# ########################################################################
# Added by Robert Becht for request an PNP4Nagios graph via its web URL
# ########################################################################
sub import_pnp_graph { 
  use LWP;
  use FileHandle;
  $tstamp = time();

  # This sets the graph history
  $elapse = ($graph_history * 3600);
  $tstart = ($tstamp - $elapse);

  # generate temporary graph file
  my $fhandle = File::Temp->new(UNLINK =>1) or verb("import_pnp_graph: Cannot create temporary image file.");
  $fhandle->autoflush(1);
  $tmpfile = $fhandle->filename;

  # Download the image
  my $ua = LWP::UserAgent->new( );

  # Check if web authentication is required
  if (defined($pnp4nagios_auth)) {
    $ua->credentials("$server_port", "$auth_name", "$web_user" => "$web_pass");
  }

  $img_get = "$pnp4nagios_url/image?host=" . urlencode($o_hostname) . "&srv=" 
           . urlencode($o_servicedesc) . "&source=0&start=$tstart&end=$tstamp";

  my $res = $ua->get($img_get);
  if ($res->is_success) {
    verb("import_pnp_graph: Downloaded PNP4Nagios image file. Server response: ".$res->status_line."\n");
    # write the graph file to $tmpfile and set the graph format
    print $fhandle $res->content;
    $graph_type = "png";

    # Because our mail system being Lotus Notes, which is not supporting PNG
    # images, we must convert them from PNG to JPG before we can continue.
    # Set $jpg_workaround = true if your mail client has the same trouble.
    if (defined($jpg_workaround)) {
      my $tmpfile_new = $tmpfile.".jpg";
      `pngtopnm $tmpfile | pnmtojpeg >$tmpfile_new`;
      `mv $tmpfile_new $tmpfile`;
      $graph_type = "jpg";
    }

    $graph_img = b64encode_img($tmpfile);
    verb("import_pnp_graph: Encoded PNP4Nagios image file, format: ".$graph_type."\n");
  # Next is what we do if we cannot get a image from PNP4Nagios
  } else {
    verb("import_pnp_graph: Cannot download PNP4Nagios image file. Server response: ".$res->status_line);
    # In this case, we create a 1x1px empty image to be included
    $graph_type = "gif";
    $graph_img = $empty_img;
    verb("import_pnp_graph: Returning empty image file, format: ".$graph_type."\n");
  }
  return $graph_img;
}

# ########################################################################
# language translated email subject: $lang{$land}
# ########################################################################
sub set_subject {
  my $subject;
  my $jp_b64 = "";

  # special base64 encoding is required for subject parts send in Japanese
  if ($land eq "jp") {
    $jp_b64 = " =?utf-8?B?" . encode_base64("のサービス");
    chomp $jp_b64;
    $jp_b64 = $jp_b64 . "?= ";
  }

  my %lang =  ('en' => "Nagios: $o_notificationtype service $o_servicedesc on $o_hostname ($o_hostgroup) is $o_servicestate",
               'de' => "Nagios: $o_notificationtype $o_hostname($o_hostgroup) mit Dienst $o_servicedesc ist $o_servicestate",
               'jp' => "Nagios: $o_notificationtype $o_hostname($o_hostgroup)".$jp_b64."$o_servicedesc $o_servicestate",
	       'fr' => "Nagios: $o_notificationtype : le service $o_servicedesc sur $o_hostname ($o_hostgroup) est $o_servicestate" );

  if (!defined($lang{$land})) { $subject = $lang{'en'}; }
  else { $subject = $lang{$land}; }

  return $subject;
}

# #######################################################################
# main
# #######################################################################
check_options();
if (! defined ($o_notificationtype) && ! defined($o_test)) {
  p_version();
  print "\nError, no notification type available. Are you trying to send a test message?\n";
  print "For a manual test from the commandline, we need to give the -t option.\n";
  exit -1;
}

$mail{Cc}   = $o_cc_recipients if ($o_cc_recipients);
$mail{Bcc}  = $o_bcc_recipients if ($o_bcc_recipients);
$mail{smtp} = $o_smtphost;
$mail{subject} = set_subject();

# If the mail server requires authentication, try this line:
# $mail{auth} = {user => "<username>", password => "<mailpw>", method="">"LOGIN PLAIN", required=>1};

if ($o_format eq "graph") {
  verb("main: trying to create the PNP4Nagios graph image.");
  $graph_img = import_pnp_graph();
}

if ($o_format eq "multi" || $o_format eq "graph") {
  verb("main: Sending HTML email (language: $land) with inline logo.");

  # check if the logo file exists
  if (-e $logofile) {
    # In e-mails, images need to be base64 encoded, we encode the logo here
    $logo_img = b64encode_img($logofile);
    # extract the image format from the file extension
    $logo_type = ($logofile =~ m/([^.]+)$/)[0];
    verb("main: Converted inline logo to base64 and set type to $logo_type.");
    # create the second boundary marker for the logo
  } else {
    # If the logo file cannot be found, we send a 1x1px empty logo image instead
    $logo_img = $empty_img;
    $logo_type = "gif";
    verb("main: Could not find inline logo file at $logofile, setting empty logo image.");
  }

  create_boundary();
  create_message_html();
  $mail{'content-type'} = qq(multipart/related; boundary="$boundary");
  $boundary = '--' . $boundary;

  # Here we define the mail content to be send
  my $mail_content = "This is a multi-part message in MIME format.\n"
  # create the first boundary start marker for the main message
          . "$boundary\n"
          . "Content-Type: text/html; charset=utf-8\n"
          . "Content-Transfer-Encoding: 8bit\n\n"
          . "$html_msg\n";

  # create the second boundary marker for the logo image
  $mail_content = $mail_content . "$boundary\n"
          . "Content-Type: image/$logo_type; name=\"logo.$logo_type\"\n"
          . "Content-Transfer-Encoding: base64\n"
          . "Content-ID: <$logo_id>\n"
          . "Content-Disposition: inline; filename=\"logo.$logo_type\"\n\n"
          . "$logo_img\n";

  # if we got the graph format and a image has been generated, we add it here
  # create the third boundary marker for the graph
  if (defined($graph_img) && $o_format eq "graph") {
    $mail_content = $mail_content . "\n"
                  . "$boundary\n"
                  . "Content-Type: image/$graph_type; name=\"graph.$graph_type\"\n"
                  . "Content-Transfer-Encoding: base64\n"
                  . "Content-ID: <$graph_id>\n"
                  . "Content-Disposition: inline; filename=\"graph.$graph_type\"\n\n"
                  . "$graph_img\n";
   }
   # create the final end boundary marker
   $mail_content = $mail_content . $boundary . "--\n";
   # put the completed message body into the mail
   $mail{body} = $mail_content ;
}
elsif ($o_format eq "html") {
  create_message_html();
  $mail{'content-type'} = qq(text/html; charset="utf-8");
  $mail{body} = $html_msg ;
} else {
  create_message_text();
  $mail{'content-type'} = qq(text/plain; charset="utf-8");
  $mail{body} = $text_msg ;
} 

sendmail(%mail) or die $Mail::Sendmail::error;
verb("Sendmail Log says:\n$Mail::Sendmail::log\n");
exit 0;

# #######################################################################
# Create a debugging table to check on Nagios and script variables
# Added by Robert Becht to create a HTML table for debugging
# #######################################################################

sub create_debugtable() {
  my $varcount = 0;
  my $oddcheck = "odd";
  
  # Check if the following variables are defined
  my %param_vars = (
		'script'  => {	"title"			=>  'Script debug data',
				"o_verb"          	=>  \$o_verb,
				"o_version"       	=>  \$o_version,
				"o_help"          	=>  \$o_help,
				"o_smtphost"      	=>  \$o_smtphost,
				"o_customer"      	=>  \$o_customer,
				"o_to_recipients" 	=>  \$o_to_recipients,
				"o_to_group"      	=>  \$o_to_group,
				"o_cc_recipients" 	=>  \$o_cc_recipients,
				"o_bcc_recipients"	=>  \$o_bcc_recipients,
				"o_format"	 	=>  \$o_format,
				"o_addurl"	 	=>  \$o_addurl,
				"o_language"	 	=>  \$o_language,
				"o_test"		=>  \$o_test,
				"o_smtphost"	 	=>  \$o_smtphost,
				"domain"		=>  \$domain,
				"land"		 	=>  \$land, 
				"logo file"		=>  \$logofile,
				"logo format"		=>  \$logo_type,
				"temporary file"	=>  \$tmpfile,
				"boundary"		=>  \$boundary },
		'nagios'  => {	"title"		   	=>  'Nagios debug data',
				"o_notificationtype"	=>  \$o_notificationtype,
				"o_notificationauth"	=>  \$o_notificationauth,
				"o_notificationcmt" 	=>  \$o_notificationcmt,
				"o_servicedesc"     	=>  \$o_servicedesc,
				"o_servicestate"    	=>  \$o_servicestate,
				"o_servicegroup"    	=>  \$o_servicegroup,
				"o_hostname"        	=>  \$o_hostname,
				"o_hostalias"       	=>  \$o_hostalias,
				"o_hostgroup"       	=>  \$o_hostgroup,
				"o_hostaddress"     	=>  \$o_hostaddress,
				"o_serviceoutput"   	=>  \$o_serviceoutput,
				"o_datetime"        	=>  \$o_datetime,
				"o_to_recipients"   	=>  \$o_to_recipients,
				"o_hostfunction"   	=>  \$o_hostfunction,
				"o_to_group"        	=>  \$o_to_group },
	      'pnp4nagios' => {	"title"			=>  'PNP4Nagios debug data',
				"access URL"		=>  \$pnp4nagios_url,
				"img_get"		=>  \$img_get,
				"interval(s)"		=>  \$elapse,
				"time start"		=>  \$tstamp }  );
  
  # loop to display the script variable tables
  foreach $tbl (keys %param_vars) {
    $debugtables .= "<br>\n"
                 . "<table width=$table_size>\n"
                 . "<tr><th colspan=2 class=customer>$param_vars{$tbl}->{'title'}</th></tr>\n";

    $varcount = 0;
    # Data loop
    foreach $var (keys %{$param_vars{$tbl}}) {
      if ($var ne 'title') {
        if ($varcount%2) {$oddcheck = "odd";} else {$oddcheck = "even";} 
        $debugtables .= "<tr><th class=$oddcheck>$var</th>";

        if ((! defined(${$param_vars{$tbl}->{$var}})) || (${$param_vars{$tbl}->{$var}} eq '')) {     
          $debugtables .= "<td class=$oddcheck>&nbsp;</td></tr>\n";
        } else {
          $debugtables .= "<td class=$oddcheck>${$param_vars{$tbl}->{$var}}</td></tr>\n";
          # Debugging
#         print $var . "= " . ${$param_vars{$tbl}->{$var}} . "\n";
        }
        $varcount++;
      }
    }
    $debugtables .= "</table>"; 
    $debugtables .="<br>\n";
  }
}
# ##################### End of pnp4n_send_service_mail.pl ####################
