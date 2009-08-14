package MockStats;

use strict;
use warnings;

sub created {
  return (3723, 0); # 1970-01-01 01:02:03 UTC
}

sub elapsed {
  return 1.234;
}

sub new {
  return bless {}, shift;
}

1;
