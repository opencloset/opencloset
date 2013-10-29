package Opencloset::Schema::Base;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/
    InflateColumn::DateTime
    TimeStamp
/);

1;
