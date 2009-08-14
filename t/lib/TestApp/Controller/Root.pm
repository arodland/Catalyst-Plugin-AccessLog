package TestApp::Controller::Root;

use strict;
use warnings;

use base 'Catalyst::Controller';

__PACKAGE__->config(namespace => '');

sub default :Path {
  my ($self, $c) = @_;

  $c->res->status(200);
  $c->res->body('okay ' . $c->req->path);
}

1;
