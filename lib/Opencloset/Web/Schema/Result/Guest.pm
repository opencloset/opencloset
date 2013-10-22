use utf8;
package Opencloset::Web::Schema::Result::Guest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Web::Schema::Result::Guest

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Web::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Web::Schema::Base';

=head1 TABLE: C<guest>

=cut

__PACKAGE__->table("guest");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 16

regex: [0-9]{10,11}

=head2 gender

  data_type: 'integer'
  is_nullable: 1

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 birth_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=head2 purpose

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 d_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=head2 chest

  data_type: 'integer'
  is_nullable: 0

=head2 waist

  data_type: 'integer'
  is_nullable: 0

=head2 arm

  data_type: 'integer'
  is_nullable: 1

=head2 pants_len

  data_type: 'integer'
  is_nullable: 1

=head2 height

  data_type: 'integer'
  is_nullable: 1

=head2 weight

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "gender",
  { data_type => "integer", is_nullable => 1 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "birth_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
  "purpose",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "d_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
  "chest",
  { data_type => "integer", is_nullable => 0 },
  "waist",
  { data_type => "integer", is_nullable => 0 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "pants_len",
  { data_type => "integer", is_nullable => 1 },
  "height",
  { data_type => "integer", is_nullable => 1 },
  "weight",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 orders

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "orders",
  "Opencloset::Web::Schema::Result::Order",
  { "foreign.guest_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "Opencloset::Web::Schema::Result::Satisfaction",
  { "foreign.guest_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-23 04:06:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TBES4Rg6lUir+VRy9Cyw2A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
