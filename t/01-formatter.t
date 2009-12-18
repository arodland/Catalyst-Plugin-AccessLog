#!/usr/bin/perl
use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 38;
use TestApp;
use MockStats;
use MockUser;

## Set up the context ##
my $c = bless {}, 'TestApp';

# Request
$c->req(
  Catalyst::Request->new(
    base => URI->new("http://testapp/"),
    method => 'GET',
    protocol => 'HTTP/1.1',
    secure => 0,
    uri => URI->new("http://testapp/foo/bar?answer=42"),
    address => '127.0.0.1',
  )
);
$c->req->path('foo/bar');
$c->req->header("User-Agent" => "t/01-formatter.t");
$c->req->remote_user('scott');

# Action
$c->action( $c->controller('Root')->action_for('default') );

# Response
$c->res(Catalyst::Response->new());
$c->res->status(200);
$c->res->content_length(12);
$c->res->content_type("text/html");

# Stats
$c->stats(MockStats->new());

# User
$c->user(MockUser->new(id => 'joe'));

## Okay.

sub formatted($) {
  my $format = shift;
  my $formatter = Catalyst::Plugin::AccessLog::Formatter->new(format => $format, time_zone => 'UTC');
  return $formatter->format_line($c);
}

is formatted '%[remote_address]', '127.0.0.1', 'remote_address';
is formatted '%a', '127.0.0.1', 'remote_address short';

is formatted '%[clf_size]', 12, 'clf_size';
is formatted '%B', 12, 'clf_size short';

is formatted '%[size]', 12, 'size';
is formatted '%b', 12, 'size short';

# Let's not test the system's ability to reverse-resolve.
is formatted '%[remote_host]', '127.0.0.1', 'remote_host';
is formatted '%h', '127.0.0.1', 'remote_host short';

is formatted '%{User-Agent}[header]', 't/01-formatter.t', 'header user-agent';
is formatted '%{User-Agent}i', 't/01-formatter.t', 'header user-agent short';

is formatted '%l', '-', 'fake ident';

is formatted '%[method]', 'GET', 'method';
is formatted '%m', 'GET', 'method short';

is formatted '%[port]', 80, 'port';
is formatted '%p', 80, 'port short';

is formatted '%[query]', '?answer=42', 'query';
is formatted '%q', '?answer=42', 'query short';

is formatted '%[request_line]', 'GET /foo/bar?answer=42 HTTP/1.1', 'request_line';
is formatted '%r', 'GET /foo/bar?answer=42 HTTP/1.1', 'request_line short';

is formatted '%[status]', 200, 'status';
is formatted '%s', 200, 'status short';

is formatted '%[apache_time]', '[01/Jan/1970:01:02:03 +0000]', 'apache_time';
is formatted '%t', '[01/Jan/1970:01:02:03 +0000]', 'apache_time short';

is formatted '%[time]', '1970-01-01T01:02:03', 'time';

is formatted '%[remote_user]', 'scott', 'remote_user';
is formatted '%u', 'scott', 'remote_user short';

is formatted '%[host_port]', 'testapp:80', 'host_port';
is formatted '%v', 'testapp:80', 'host_port %v';
is formatted '%V', 'testapp:80', 'host_port %V';

is formatted '%[hostname]', 'testapp', 'hostname';

is formatted '%[path]', '/foo/bar', 'path';
is formatted '%U', '/foo/bar', 'path short';

cmp_ok formatted '%[handle_time]', '==', 1.234, 'handle_time';
cmp_ok formatted '%T', '==', 1.234, 'handle_time short';

is formatted '%[action]', 'default', 'action';

is formatted '%[sessionid]', 'abcdef123', 'sessionid';

is formatted '%[userid]', 'joe', 'userid';

cmp_ok formatted '%[pid]', '==', $$, 'pid';

done_testing;
