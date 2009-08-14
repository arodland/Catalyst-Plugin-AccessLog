package TestApp;

use strict;
use warnings;

use Moose;

use Catalyst qw(AccessLog);

__PACKAGE__->config(
  name => 'TestApp',
  'Plugin::AccessLog' => {
    formatter => {
      format => '%[size] %[path] "%[request_line]" %[status] %[request_count]',
    },
  },
);

__PACKAGE__->setup();

sub sessionid {
  return "abcdef123";
}

has 'user' => (
  is => 'rw',
  predicate => 'user_exists',
  clearer => 'clear_user',
);

no Moose;
1;
