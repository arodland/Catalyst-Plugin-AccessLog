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
  return shift->request->hostname;
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
  my $format = $arg || '%d/%b/%Y:%H:%M:%S %z'; # Apache default
  return DateTime->now(time_zone => $config->{time_zone})
    ->strftime($format);
};

item ['datetime'] => sub {
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

item ['i', 'header'] => sub {
  my ($c, $arg) = @_;
  return $c->req->header($arg);
};

sub get_item {
  my ($self, $c, $key, $arg) = @_;

  return $key unless exists $items{$key};
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
