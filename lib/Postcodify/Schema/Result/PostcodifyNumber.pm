use utf8;
package Postcodify::Schema::Result::PostcodifyNumber;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Postcodify::Schema::Result::PostcodifyNumber

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Postcodify::Schema::Base>

=cut

use base 'Postcodify::Schema::Base';

=head1 TABLE: C<postcodify_numbers>

=cut

__PACKAGE__->table("postcodify_numbers");

=head1 ACCESSORS

=head2 seq

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 address_id

  data_type: 'integer'
  is_nullable: 0

=head2 num_major

  data_type: 'integer'
  is_nullable: 1
  size: 5

=head2 num_minor

  data_type: 'integer'
  is_nullable: 1
  size: 5

=cut

__PACKAGE__->add_columns(
  "seq",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "address_id",
  { data_type => "integer", is_nullable => 0 },
  "num_major",
  { data_type => "integer", is_nullable => 1, size => 5 },
  "num_minor",
  { data_type => "integer", is_nullable => 1, size => 5 },
);

=head1 PRIMARY KEY

=over 4

=item * L</seq>

=back

=cut

__PACKAGE__->set_primary_key("seq");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-11-20 04:57:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qtj02QMY6/jnO19CkO/H7g

__PACKAGE__->belongs_to(
  "address",
  "Postcodify::Schema::Result::PostcodifyAddress",
  { address_id => "id" },
  {
    is_deferrable => 0,
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

1;
