use utf8;
package Opencloset::Schema::Result::Satisfaction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Satisfaction

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<satisfaction>

=cut

__PACKAGE__->table("satisfaction");

=head1 ACCESSORS

=head2 guest_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 cloth_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 chest

  data_type: 'integer'
  is_nullable: 1

=head2 waist

  data_type: 'integer'
  is_nullable: 1

=head2 arm

  data_type: 'integer'
  is_nullable: 1

=head2 top_fit

  data_type: 'integer'
  is_nullable: 1

=head2 bottom_fit

  data_type: 'integer'
  is_nullable: 1

=head2 create_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=cut

__PACKAGE__->add_columns(
  "guest_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "cloth_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "chest",
  { data_type => "integer", is_nullable => 1 },
  "waist",
  { data_type => "integer", is_nullable => 1 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "top_fit",
  { data_type => "integer", is_nullable => 1 },
  "bottom_fit",
  { data_type => "integer", is_nullable => 1 },
  "create_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
    set_on_create => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</guest_id>

=item * L</cloth_id>

=back

=cut

__PACKAGE__->set_primary_key("guest_id", "cloth_id");

=head1 RELATIONS

=head2 cloth

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->belongs_to(
  "cloth",
  "Opencloset::Schema::Result::Cloth",
  { id => "cloth_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 guest

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Guest>

=cut

__PACKAGE__->belongs_to(
  "guest",
  "Opencloset::Schema::Result::Guest",
  { id => "guest_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-05 11:48:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KkYZeM71RVkUoeIz4kVtiA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
