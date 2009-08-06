package Catalyst::Plugin::AccessLog;

use namespace::autoclean;
use Moose::Role;
use Scalar::Util qw(reftype blessed);

after 'setup_finalize' => sub { # Init ourselves
  my $c = shift;
  my $config = $c->config->{'Plugin::AccessLog'} ||= {};
  %$config = (
    format => '%h %l %u %t "%r" %s %b "%{Referer}i" "%{User-Agent}i"',
    formatter_class => 'Catalyst::Plugin::AccessLog::Formatter',
    time_format => '%Y-%m-%dT%H:%M:%S', # ISO8601-compatible
    time_zone => 'local',
    hostname_lookups => 0,
    target => \*STDERR,
    %$config
  );

  if (!ref $config->{target}) {
    open my $output, '>>', $config->{target} or die qq[Error opening "$config->{target}" for log output];
    select((select($output), $|=1)[0]);
    $config->{target} = $output;
  }

  Catalyst::Utils::ensure_class_loaded( $config->{formatter_class} );
};

sub access_log_write {
  my $c = shift;
  my $output = join "", @_;
  $output .= "\n" unless $output =~ /\n\Z/;

  my $target = $c->config->{'Plugin::AccessLog'}{target};
  if (reftype($target) eq 'GLOB' or blessed($target) && $target->isa('IO::Handle')) {
    print $target $output;
  } elsif (reftype($target) eq 'CODE') {
    $target->($output, $c);
  } elsif ($target->can('info')) { # Logger object
    $target->info($output);
  } else {
    warn "Don't know how to log to config->{'Plugin::AccessLog'}{target}";
  }
}

after 'finalize' => sub {
  my $c = shift;
  my $config = $c->config->{'Plugin::AccessLog'};

  my $formatter = $config->{formatter_class}->new();
  my $line = $formatter->format_line($c);
  $c->access_log_write($line);
};

no Moose::Role;

1;

=head1 SYNOPSIS

Requires Catalyst 5.8 or above.

    # In lib/MyApp.pm context
    use Catalyst qw(
        ConfigLoader
        -Stats=1
        AccessLog
        ... other plugins here ...
    );

    __PACKAGE__->config(
        'Plugin::AccessLog' => {
            format => '%[time] %[remote_address] %[path] %[status] %[size]',
            time_format => '%c',
            time_zone => 'America/Chicago',
        }
    );

    __PACKAGE__->setup();

=head1 DESCRIPTION

This plugin isn't for "debug" logging. Instead it enables you to create
"access logs" from within a Catalyst application instead of requiring a
webserver to do it for you. It will work even with Catalyst debug logging
turned off (but see NOTES below).

=head1 CONFIGURATION

All configuration is optional; by default the plugin will log to STDERR in a
format compatible with the "Common Log Format"
(L<http://en.wikipedia.org/wiki/Common_Log_Format>).

=over 4

=item target

B<Default:> C<\*STDERR>

Where to log to. If C<target> is a filehandle or something that 
C<< isa("IO::Handle") >>, lines of logging information will be C<print>ed to
it. If C<target> is an object with an C<info> method it's assumed to be a
logging object (e.g. L<Log::Dispatch> or L<Log::Log4perl>) and lines will be
passed to the C<info> method. If it's a C<CODE> ref then it will be called
with each line of logging output. If it's an unblessed scalar it will be
interpreted as a filehandle and the plugin will try to open it for append
and write lines to it.

=item format

B<Default:> C<'%h %l %u %t "%r" %s %b "%{Referer}i" "%{User-Agent}i"'> (Apache
C<common> log format).

The format string for each line of output. You can use Apache C<LogFormat>
strings, with a reasonably good level of compatibility, or you can use a
slightly more readable format. The log format is documented in detail in
L<Catalyst::Plugin::AccessLog::Formatter>.

=item time_format

B<Default:> C<'%Y-%m-%dT%H:%M:%S'> (ISO 8601)

The default time format for the C<%t> / C<%[time]> escape. This is a
C<strftime> format string, which will be provided to L<DateTime>'s
C<strftime> method.

=item time_zone

B<Default:> local

The timezone to use when printing times in access logs. This will be passed
to L<DateTime::TimeZone>'s constructor. Olson timezone names, POSIX TZ
values, and the keywords C<"local"> and C<"UTC"> are reasonable choices.

=item formatter_class

B<Default:> C<Catalyst::Plugin::AccessLog::Formatter>

In case you want to do something completely different you may provide your
own formatter class that implements the C<format_line> method and provide
its name here.

=item hostname_lookups

B<Default:> B<false>

If this option is set to a true value, then the C<%h> /
C<%[remote_hostname]> escape will resolve the client IP address using
reverse DNS. This is generally not recommended for reasons of performance
and security. Equivalent to the Apache option C<HostnameLookups>.

=back

=head1 NOTES

=head2 Request time statstics

C<Catalyst::Plugin::AccessLog> works without regard to Catalyst's debug
logging option. However, the C<%T> / C<%[handle_time]> escape is only
available if Catalyst stats are enabled. By default, statistics are only
collected in Catalyst if debugging is active. If you want to use the C<%T>
escape you can enable stats by adding C<-Stats> to your C<use Catalyst>
line or by setting the C<MYAPP_STATS> environment variable to 1.

=head2 Logging to C<< $c->log >>

It is generally not recommended to write the access log to C<< $c->log >>,
especially if static file handling is enabled. However, there might be a
good reason to do it somewhere. If the logging target is a coderef, it will
receive C<$c> as its second argument. You can log to C<< $c->log >> with:

    target => sub { pop->log->info(shift) }

Don't store C<$c> anywhere that persists after the lifetime of the coderef
or bad things will happen to you and everyone you know.

=head1 SOURCE, BUGS, ETC.

L<http://github.com/arodland/Catalyst-Plugin-AccessLog>

=cut
