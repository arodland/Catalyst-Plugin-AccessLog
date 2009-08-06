package Catalyst::Plugin::AccessLog::Formatter;

use namespace::autoclean;
use Moose;
use DateTime;

my %items;

sub item {
  my ($names, $code) = @_;
  $names = [ $names ] unless ref $names;

  $items{$_} = $code for @$names;
}

my %whitespace_escapes = (
  "\r" => "\\r",
  "\n" => "\\n",
  "\t" => "\\t",
  "\x0b" => "\\v",
);

# Approximate the rules for safely escaping headers/etc given in the apache docs
sub escape_string {
  my $str = shift;
  return "" unless defined $str and length $str;

  $str =~ s/(["\\])/\\$1/g;
  $str =~ s/([\r\n\t\v])/$whitespace_escapes{$1}/eg;
  $str =~ s/([^[:print:]])/sprintf '\x%02x', ord $1/eg;

  return $str;
}

item ['a', 'remote_address'] => sub {
  return shift->request->address;
};

item ['b', 'clf_size'] => sub {
  return shift->response->content_length || "-";
};

item ['B', 'size'] => sub {
  return shift->response->content_length;
};

item ['h', 'remote_hostname'] => sub {
  my $c = shift;
  if ($c->config->{'Plugin::AccessLog'}{hostname_lookups}) {
    return $c->request->hostname;
  } else {
    return $c->request->address;
  }
};

item 'l' => sub { # for apache compat
  return "-";
};

item ['m', 'method'] => sub {
  return shift->request->method;
};

item ['p', 'port'] => sub {
  return shift->req->base->port;
};

item ['r', 'request_line'] => sub { # Mostly for apache's sake
  my $c = shift;
  return $c->req->method . " " . $c->req->path . " " . $c->req->protocol;
};

item ['s', 'status'] => sub {
  return shift->response->status;
};

item ['t', 'apache_time'] => sub {
  my ($c, $arg) = @_;
  my $config = $c->config->{'Plugin::AccessLog'};
  my $format = $arg || '[%d/%b/%Y:%H:%M:%S %z]'; # Apache default
  return DateTime->now(time_zone => $config->{time_zone})
    ->strftime($format);
};

item ['time', 'datetime'] => sub {
  my ($c, $arg) = @_;
  my $config = $c->config->{'Plugin::AccessLog'};
  my $format = $arg || $config->{time_format};

  return DateTime->now(time_zone => $config->{time_zone})
    ->strftime($format);
};

item ['u', 'remote_user'] => sub {
  return shift->request->remote_user || '-';
};

item ['V', 'v', 'host_port'] => sub {
  return shift->request->base->host_port;
};

item 'hostname' => sub {
  return shift->request->base->host;
};

# Possibly improvement: use uri_for to absolutize this with base, and then
# take the path component off of that...
item ['U', 'path'] => sub {
  return '/' . shift->request->path;
};

item ['T', 'handle_time'] => sub {
  my $c = shift;
  if ($c->use_stats) {
    return sprintf "%f", $c->stats->elapsed;
  } else {
    return "-";
  }
};

item ['i', 'header'] => sub {
  my ($c, $arg) = @_;
  return escape_string( $c->req->header($arg) );
};

sub get_item {
  my ($self, $c, $key, $arg) = @_;

  return "[unknown format key $key]" unless exists $items{$key};
  return $items{$key}->($c, $arg);
}

sub format_line {
  my ($self, $c) = @_;
  my $format = $c->config->{'Plugin::AccessLog'}{format};
  my $output = "";

  while (1) {
    my $argument = qr/\{ ( [^}]+ ) \}/x;
    my $longopt = qr/\[ ( [^]]+ ) \]/x;

    if ($format =~ /\G \Z/cgx) { # Found end of string.
      last;
    } elsif ($format =~ /\G ( [^%]+ )/cgx) { # Found non-percenty text.
      $output .= $1;
    } elsif ($format =~ /\G \%\% /cgx) { # Literal percent
      $output .= "%";
    } elsif ($format =~ /\G \% $argument (.)/cgx) { # Short opt with argument
      $output .= $self->get_item($c, $2, $1);
    } elsif ($format =~ /\G \% (.)/cgx) { # Short opt
      $output .= $self->get_item($c, $1);
    } elsif ($format =~ /\G \% $argument $longopt/cgx) { # Long opt with argument
      $output .= $self->get_item($c, $2, $1);
    } elsif ($format =~ /\G \% $longopt/cgx) { # Long opt
      $output .= $self->get_item($c, $1);
    } else {
      warn "Can't happen!";
    }
  }

  return $output;
}

no Moose;

1;
