#!/usr/bin/perl
# vim: se ts=4 et syn=perl:

# check_certificates.pl - Verify expiration dates of SSL certificates.
#
#     Copyright (C) 2017 Giacomo Montagner <giacomo@entirelyunlike.net>
#
#     This program is free software: you can redistribute it and/or modify
#     it under the same terms as Perl itself, either Perl version 5.8.4 or,
#     at your option, any later version of Perl 5 you may have available.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
#
#
#   CHANGELOG:
#
#       2017-02-18T22:52:37+01:00
#           v 0.1.0 released.
#               TODO: write manual.
#
#       2017-02-20T14:00:32+01:00
#           v 0.2.0     - Added support for STARTTLS (-T)
#
#       2017-02-24T09:23:21+01:00
#           v 0.3.0     - Option -P|--useEnvProxy is honored now.
#
#       2017-02-24T10:24:46+01:00
#           v 0.4.0     - Refactoring of the code.
#
#       2017-02-24T11:15:59+01:00
#           v 0.5.0     - Option -T renamed -S (--tls -> --starttls)
#
#       2017-02-27T18:15:03+01:00
#           v 0.5.1     - Fixes in proxy usage.
#
#       2017-02-28T17:41:02+01:00
#           v 0.5.2     - Fix to a debug message
#                       - Explicitly noted in the help that ranges in the form
#                           crit: / warn: must be used. 
#       2018-02-02T17:14:10+01:00
#           v 0.5.3     - Changed a construct which broke compatibility with
#                           Perl 5.10.1 ('r' flag to =~ operator).
#

use strict;
use warnings;
use version; our $VERSION = qv(0.5.3);
use v5.010.001;
use utf8;
use File::Basename qw(basename);
use POSIX qw(strftime);
use Monitoring::Plugin;

use constant                DEFAULT_PORT    =>       443;

use subs qw(
    debug
);





# ------------------------------------------------------------------------------
#  Globals
# ------------------------------------------------------------------------------
my $plugin_name = basename( $0 );
my $proxy_spec   = '[<scheme>://][<user>:<password>@]<proxy>[:<port>]';




# ------------------------------------------------------------------------------
#  Command line initialization
# ------------------------------------------------------------------------------

# This plugin's initialization - see https://metacpan.org/pod/Monitoring::Plugin
#   --verbose, --help, --usage, --timeout and --host are defined automatically.
my $np = Monitoring::Plugin::CheckCerts->new(
    usage => "Usage: %s [-v|--verbose] [-t <timeout>] [-d|--debug] "
            . "[-h|--help] [-M|--manual] "
            . "[-P|--useEnvProxy] [--proxy=$proxy_spec] [--proxyForScheme=<scheme>] "
            . "[--verify] [-S|--starttls] "
            . "[-c|--critical=INTEGER:INTEGER] [-w|--warning=INTEGER:INTEGER] "
            . "HOST[:PORT] [HOST[:PORT] [...]]",
    version => $VERSION,
    blurb   => "This plugin uses IO::Socket::SSL to check the validity of an SSL"
                . " certificate by connecting to the specified HOST[:PORT].",
);

# Command line options
$np->add_arg(
    spec => 'critical|c=s',
    help => qq{-c, --critical=INTEGER:INTEGER\n}
          . qq{   Critical threshold (in days) for certificate expiration.\n}
          . qq{   Don't forget the colon (see manual).\n}
          . qq{   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT }
          . qq{for the threshold format, or run $plugin_name -M (requires perldoc executable). },
);

$np->add_arg(
    spec => 'debug|d',
    help => qq{-d, --debug\n   Print debugging messages to STDERR. }
          . qq{Package Data::Dumper is required for debug.},
);

$np->add_arg(
    spec => 'manual|M',
    help => qq{-M, --manual\n   Show plugin manual (requires perldoc executable).},
);

$np->add_arg(
    spec => 'proxy=s',
    help => qq{--proxy=$proxy_spec\n   Use this proxy to connect to the final endpoint(s).},
);

$np->add_arg(
    spec => 'proxyForScheme=s@',
    help => qq{--proxyForScheme=<scheme>\n   Specify to which scheme(s) the }
          . qq{proxy applies. This option can be specified multiple times. }
          . qq{The default is to use proxy for https, as if 'https_proxy' }
          . qq{environment variable was set.},
);

$np->add_arg(
    spec => 'useEnvProxy|P',
    help => qq{-P, --useEnvProxy\n}
          . qq{   Get proxy configuration from environment variables.},
);

$np->add_arg(
    spec => 'starttls|S',
    help => qq{-S, --starttls\n}
          . qq{   Use STARTTLS to test the targets.},
);

$np->add_arg(
    spec => 'verify',
    help => qq{--verify\n}
          . qq{   Enable certificate validity verification.\n}
          . qq{   If certificate and certificate chain are not valid, a }
          . qq{critical event is issued. The default is to NOT validate }
          . qq{certificates automatically.},
);

$np->add_arg(
    spec => 'warning|w=s',
    help => qq{-w, --warning=INTEGER:INTEGER\n}
          . qq{   Warning threshold (in days) for certificate expiration.\n}
          . qq{   Don't forget the colon (see manual).\n}
          . qq{   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT }
          . qq{for the threshold format, or run $plugin_name -M (requires perldoc executable).},
);



# It would be easy to do this and then die() peacefully from everywhere it's
# required, but it would break any eval{} in the code from here to everywhere,
# so it cannot be done. I document it here so no one else is tempted to do
# this.
# $SIG{ __DIE__ } = sub {
#   $np->plugin_die(@_);
# };



# ------------------------------------------------------------------------------
#  Command line parsing
# ------------------------------------------------------------------------------

# Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts();
my $opts = $np->opts();

if ($opts->manual()) {
    exec(qq{\$(which perldoc) $0});
}

if ($opts->debug()) {
    require Data::Dumper;
    *debug = sub { say STDERR "DEBUG :: ", @_; };
    *ddump = sub { Data::Dumper->Dump( @_ ); };
} else {
    *debug = sub { return; };
    *ddump = *debug;
}

unless(@ARGV) {
    $np->plugin_die("No targets specified on command line");
}


# Create our object to make checks
my $cc = Local::EntirelyUnlike::CheckCerts->new(
    np   => $np,
    opts => $opts
);


# ------------------------------------------------------------------------------
#  Probe all targets
# ------------------------------------------------------------------------------

TARGET: for my $target (@ARGV) {

    # Get the target
    my ($host, $port) = split(':', $target);
    $port //= DEFAULT_PORT;

    # Get the Certificate
    my $cert = $cc->get_peer_certificate($host, $port)
        or next TARGET;

    my $days_to_expiration = int( ( $cert->{ not_after } - time() ) / 86400 );
    debug("target=$target, days_to_expiration=$days_to_expiration, warning=", $opts->warning(), ", critical=", $opts->critical());

    my $status = $np->check_threshold(
        check    => $days_to_expiration,
        warning  => $opts->warning(),
        critical => $opts->critical()
    );

    my $expiry_date = strftime("%a %d %b %Y %H:%M:%S %Z", localtime( $cert->{ not_after } ) );

    if ($status == OK) {
        $np->add_ok( "target=$target, expires=$expiry_date ($days_to_expiration days)" );
    } elsif ($status == WARNING) {
        $np->add_warning( "target=$target, expires=$expiry_date ($days_to_expiration days)" );
    } elsif ($status == CRITICAL) {
        $np->add_critical( "target=$target, expires=$expiry_date ($days_to_expiration days)" );
    }

}

# Finally, exit
$np->plugin_exit( $np->status(), $np->build_message() );




# ------------------------------------------------------------------------------
#  End of main
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------



###############################################################################
## Monitoring::Plugin extension
###############################################################################
package Monitoring::Plugin::CheckCerts;

use strict;
use warnings;
use Monitoring::Plugin;
use parent qw(
    Monitoring::Plugin
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{_checkcerts_status} = 0;
    $self->{_checkcerts_oks} = [];
    $self->{_checkcerts_warnings} = [];
    $self->{_checkcerts_criticals} = [];

    return $self;
}

sub raise_status {
    my ($self, $newStatus) = @_;
    $self->{_checkcerts_status} = $newStatus
        if $self->{_checkcerts_status} < $newStatus;
}

sub add_warning {
    my $self = shift;

    push @{ $self->{_checkcerts_warnings} }, @_;

    $self->raise_status( WARNING );
}

sub add_critical {
    my $self = shift;

    push @{ $self->{_checkcerts_criticals} }, @_;

    $self->raise_status( CRITICAL );
}

sub add_ok {
    my $self = shift;

    push @{ $self->{_checkcerts_oks} }, @_;
}

sub add_status {
    my ($self, $status, $reason) = @_;

    if ($status == OK) {
        $self->add_ok( $reason );
    } elsif ($status == WARNING) {
        $self->add_warning( $reason );
    } elsif ($status == CRITICAL) {
        $self->add_critical( $reason );
    }
}

sub status {
    return $_[0]->{_checkcerts_status};
}

sub oks {
    return wantarray                    ?
        @{ $_[0]->{_checkcerts_oks} } :
           $_[0]->{_checkcerts_oks}   ;
}

sub warnings {
    return wantarray                    ?
        @{ $_[0]->{_checkcerts_warnings} } :
           $_[0]->{_checkcerts_warnings}   ;
}

sub criticals {
    return wantarray                    ?
        @{ $_[0]->{_checkcerts_criticals} } :
           $_[0]->{_checkcerts_criticals}   ;
}

sub get_criticals {
    my ($self) = @_;
    
    my @crits = $self->criticals();
    return "CRITICAL: ". join("; ", @crits). "; "
        if @crits;
}

sub get_warnings {
    my ($self) = @_;

    my @warns = $self->warnings();
    return "WARNING: ". join("; ", @warns). "; "
        if @warns;
}

sub get_oks {
    my ($self) = @_;

    my @oks = $self->oks();
    return "OK: ". join("; ", @oks). "; "
        if @oks;
}

sub build_message {
    my ($self) = @_;

    my $msg;
    if (my $crit = $self->get_criticals()) {
        $msg .= $crit;
    }
        
    if (my $warn = $self->get_warnings()) {
        $msg .= $warn;
    }

    if (my $oks = $self->get_oks()) {
        $msg .= $oks;
    }

    return $msg;
}

###############################################################################
## LWP::UserAgent extension
###############################################################################
package LWP::UserAgent::CheckCerts;
use strict;
use warnings;
use v5.010.001;
use utf8;
use LWP::UserAgent;
use parent qw(LWP::UserAgent);

use constant                PROXY_PORT      =>      8080;
use constant                PROXY_SCHEMES   =>      [ qw( http https ) ];

sub new {
    my ($class, %args) = @_;

    my $proxy   = delete $args{ proxy };
    my $schemes = delete $args{ schemes };
    my $use_env = delete $args{ use_env };

    my $self = $class->SUPER::new(
        agent      => $plugin_name,
        keep_alive => 0,
        %args,
    );

    if ($use_env) {
        main::debug "Proxy setup: using environment variables for proxy.";
        $self->env_proxy();
    } else {
        {
            (my $debug_p = $proxy) =~ s{//.*?:.*?\@}{//XXXXXX:XXXXXX\@};
            main::debug "Proxy setup: ", $debug_p;
        }
        $self->proxy( ($schemes // PROXY_SCHEMES()), $proxy );
    }

    return $self;
}


sub proxy_connect {
    my ($self, $host, $port) = @_;

    # connect to the proxy
    my $req = HTTP::Request->new(
        CONNECT => "http://$host:$port/" );
    return $self->request($req);
}



###############################################################################
## Check Certificates
###############################################################################
package Local::EntirelyUnlike::CheckCerts;
use strict;
use warnings;
use v5.010.001;
use utf8;
use IO::Socket::SSL;
use IO::Socket::INET6;
use IO::Socket::SSL::Utils;

use constant                BUFFER_SIZE     =>      8192;

BEGIN {
    my @attrs = qw(
        np
        opts
        ua
        verification_method
    );
    
    # -----------------------
    # Generate getters
    # -----------------------
    for my $attr (@attrs) {
        my $method_name = $attr;
        my $getter = sub {
            return $_[0]->{ $attr };
        };
    
        no strict "refs";
        *$method_name = $getter;
    }
    
    my @proxy_methods = qw(
        status
        add_ok
        add_warning
        add_critical
        plugin_die
        plugin_exit
    );

    # -----------------------
    # Generate proxy methods
    # -----------------------
    for my $pm (@proxy_methods) {
        my $method = sub {
            my $self = shift;
            return $self->np()->$pm(@_);
        };
    
        no strict "refs";
        *$pm = $method;
    }
}

# ------------------------------------------------------------------------------
#  Static methods
# ------------------------------------------------------------------------------

sub _starttls {
    my ($socket) = @_;
    $socket->recv(my $buf, BUFFER_SIZE());
    debug( $buf );
    $socket->send("STARTTLS\n");
    $socket->recv($buf, BUFFER_SIZE());
    debug( $buf );
}

# ------------------------------------------------------------------------------
#  Methods
# ------------------------------------------------------------------------------

sub new {
    my ($class, %args)  = @_;
    my $self            = { %args };

    my $opts = $args{ opts };

    # --------------------------------------------------------------------------
    # Set the verification method to be used when getting the certificate
    # --------------------------------------------------------------------------
    $self->{verification_method} =
        $opts->verify()     ?
            SSL_VERIFY_PEER :
            SSL_VERIFY_NONE ;

    main::debug("Using verification method: ", $self->{ verification_method });

    # --------------------------------------------------------------------------
    #  If a proxy is configured, prepare user agent for the probe
    # --------------------------------------------------------------------------
    if ($opts->proxy() || $opts->useEnvProxy()) {
        $self->{ ua } = LWP::UserAgent::CheckCerts->new(
            proxy   => $opts->proxy(),
            schemes => $opts->proxyForScheme(),
            use_env => $opts->useEnvProxy(),
        );
    }

    main::ddump([$self]);
    return bless($self, $class);
}


sub get_peer_certificate {
    my ($self, $host, $port) = @_;

    my $client;
    if ($self->ua()) {
        $client = $self->get_peer_certificate_via_proxy($host, $port);

    } else {
        $client = $self->get_peer_certificate_without_proxy($host, $port);
    }

    if ($client) {
        my $cert = CERT_asHash( $client->peer_certificate() );
        $client->close();
        return $cert;
    } else {
        return undef;
    }
}

sub get_peer_certificate_via_proxy {
    my ($self, $host, $port) = @_;
    main::debug "Using proxy";

    my $ua   = $self->ua();
    my $opts = $self->opts();

    # connect to the proxy
    my $res = $ua->proxy_connect($host, $port);

    # CONNECT failed
    $res->is_success()
        or $self->plugin_die(
            "CONNECT failed through proxy for target $host:$port: ["
            . $res->code. "] ". $res->message());

    # Get the socket to talk through
    my $socket = $res->{client_socket};

    _starttls($socket) if $opts->starttls();

    my $client;
	unless (
        $client = IO::Socket::SSL->start_SSL(
            $socket,
            SSL_verify_mode => $self->verification_method(),
        )
    ) {
        $self->add_critical("target=$host:$port, error=$!, ssl_error=$SSL_ERROR");
    }
    
    return $client;
}


sub get_peer_certificate_without_proxy {
    my ($self, $host, $port) = @_;

    my $opts = $self->opts();

    my $client;
    if ($opts->starttls()) {
        unless (
            my $client = IO::Socket::INET6->new(
                PeerAddr        => $host,
                PeerPort        => $port,
            )
        ) {
            $self->add_critical("target=$host:$port, connect_error=$!");
            return undef;
        }

        _starttls($client);

        unless ($client = IO::Socket::SSL->start_SSL(
                $client,
                SSL_verify_mode => $self->verification_method(),
            )
        ) {
            $self->add_critical("target=$host:$port, error=$!, ssl_error=$SSL_ERROR");
        }

    } else {
        unless (
            $client = IO::Socket::SSL->new(
                PeerAddr        => $host,
                PeerPort        => $port,
                SSL_verify_mode => $self->verification_method(),
            )
        ) {
            $self->add_critical("target=$host:$port, error=$!, ssl_error=$SSL_ERROR");
            return undef;
        }
    }

    return $client;
}



###############################################################################
## MANUAL
###############################################################################

=pod

=head1 NAME

check_certificates.pl - Verify SSL certificate of one or more targets.


=head1 VERSION

This is the documentation for check_end2end.pl v0.5.2


=head1 SYNOPSYS

    # Check one or more target specifying how many days before certificate
    # expiration a warning or a critical must be issued; with --verify the 
    # certificates common name and chain are also checked for validity:

    check_certificates.pl [--verify] -c INTEGER:INTEGER -w INTEGER:INTEGER \
        HOST[:PORT] [HOST[:PORT] ... ]


    # If you have to check a service behind a proxy, you can use environment
    # variables or specify a proxy:

    check_certificates.pl --proxy http://[user:password@]proxy[:port]/ \
        HOST[:PORT] [HOST[:PORT] ... ]

    export http_proxy=http://[user:password@]proxy[:port]/
    check_certificates.pl --useEnvProxy HOST[:PORT] [HOST[:PORT] ... ]


=head1 DESCRITPION

C<check_certificates.pl> is a simple plugin to verify when SSL certificates
will expire. Optionally, the validity of the certificates can be verified. 
C<check_certificates.pl> supports checking through a proxy and using STARTTLS.


=head1 THRESHOLDS (don't forget the colon, see below)

See L<https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT>
for threshold formats. In the simplest case: 

    check_certificates.pl -c crit_days: -w warn_days: <targets>

will issue a warning if any one of the target certificates will expire less
than <warn_days> from now, or a critical if any one of the target certificates
will expire less than <crit_days> from now. 

B<DON'T FORGET THE TRAILING COLON (:)>: if 
you specify a threshold without the colon at the end, an error will be reported
if expiration days are above, and not below, the number of days you specified.
For the most general threshold syntax see the above link.


=head1 OPTIONS

=head2 B<--proxyForScheme>

Use the specified proxy for the named scheme (e.g. 'http', 'https'). 
The default scheme is 'http' (and it should be enough). This is equivalent to
setting environment variables C<http_proxy>, C<https_proxy> and so on. This 
option can be specified multiple times, e.g.: 

    ... --proxyForScheme http --proxyForScheme https ...


=head2 B<-P|--useEnfProxy>

Get proxy configuration from environmen variables:

    http_proxy
    https_proxy


=head2 B<--verify>

Perform a verification of the certificate using L<IO::Socket::SSL>'s 
SSL_VERIFY_PEER verify mode.


=head2 B<--proxy [scheme]://[user:password@]proxy[:port]/>

Perform checks by CONNECTing targets through this proxy (with optional
authentication).


=head2 <-S|--starttls>

Perform a STARTTLS onto the socket before doing SSL handshake.


=head1 PREREQUISITES

Reuired modules:

=over 4

=item * parent (pragma)

=item * IO::Socket::INET6

=item * IO::Socket::SSL

=item * IO::Socket::SSL::Utils

=item * LWP::UserAgent

=item * Monitoring::Plugin

=back

for debugging:

=over 4

=item * Data::Dumper

=back




=head1 AUTHOR

Giacomo Montagner, <kromg at entirelyunlike.net>,
<kromg.kromg at gmail.com> >

=head1 BUGS AND CONTRIBUTIONS

Please report any bug at L<https://github.com/kromg/nagios-plugins/issues>. If
you have any patch/contribution, feel free to fork git repository and submit a
pull request with your modifications.


=head2 Contributors:

* Matteo Guadrini



=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 Giacomo Montagner <giacomo@entirelyunlike.net>

This program is free software: you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See http://dev.perl.org/licenses/ for more information.


=head1 AVAILABILITY

Latest sources are available from L<https://github.com/kromg/nagios-plugins>

=cut
