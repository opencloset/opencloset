package Opencloset::Schema::Base;
use Moose;
use namespace::autoclean;

extends 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/
    InflateColumn::DateTime
/);

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
