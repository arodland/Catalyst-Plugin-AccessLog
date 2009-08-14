#!/usr/bin/perl
#
use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 4;
use Catalyst::Test 'TestApp';

my @log_lines;

TestApp->config->{'Plugin::AccessLog'}{target} = sub { push @log_lines, shift };

my $content = get('/foo/bar');
my $len = length($content);

cmp_ok(scalar @log_lines, '==', 1, "one line logged");
is $log_lines[0], qq{$len /foo/bar "GET /foo/bar HTTP/1.1" 200 1\n}, "line 1 looks okay";

$content = get('/foo/baz');
$len = length($content);

cmp_ok(scalar @log_lines, '==', 2, "two lines logged");
is $log_lines[1], qq{$len /foo/baz "GET /foo/baz HTTP/1.1" 200 2\n}, "line 2 looks okay";
