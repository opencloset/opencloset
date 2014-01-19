use utf8;
package Opencloset::Schema::Result::Clothes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Clothes

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<clothes>

=cut

__PACKAGE__->table("clothes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 code

  data_type: 'char'
  is_nullable: 0
  size: 5

=head2 bust

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 waist

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 hip

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 belly

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 arm

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 thigh

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 length

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 color

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 gender

  data_type: 'varchar'
  is_nullable: 1
  size: 6

male/female/unisex

=head2 category

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 donation_id

  data_type: 'integer'
  default_value: 1
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 status_id

  data_type: 'integer'
  default_value: 1
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 group_id

  data_type: 'integer'
  default_value: 1
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 compatible_code

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "code",
  { data_type => "char", is_nullable => 0, size => 5 },
  "bust",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "waist",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "hip",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "belly",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "arm",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "thigh",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "length",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "color",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "gender",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "donation_id",
  {
    data_type => "integer",
    default_value => 1,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "status_id",
  {
    data_type => "integer",
    default_value => 1,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "group_id",
  {
    data_type => "integer",
    default_value => 1,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "compatible_code",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<code>

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->add_unique_constraint("code", ["code"]);

=head1 RELATIONS

=head2 donation

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Donation>

=cut

__PACKAGE__->belongs_to(
  "donation",
  "Opencloset::Schema::Result::Donation",
  { id => "donation_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 group

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Group>

=cut

__PACKAGE__->belongs_to(
  "group",
  "Opencloset::Schema::Result::Group",
  { id => "group_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 order_details

Type: has_many

Related object: L<Opencloset::Schema::Result::OrderDetail>

=cut

__PACKAGE__->has_many(
  "order_details",
  "Opencloset::Schema::Result::OrderDetail",
  { "foreign.clothes_code" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<Opencloset::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "Opencloset::Schema::Result::Satisfaction",
  { "foreign.clothes_code" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 status

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Status>

=cut

__PACKAGE__->belongs_to(
  "status",
  "Opencloset::Schema::Result::Status",
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-01-17 19:23:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I2c0Vs180eHcEbUd5JMW+w


# You can replace this text with custom code or comments, and it will be preserved on regeneration

=head2 orders

Type: many_to_many

Composing rels: L</order_details> -> order

=cut

__PACKAGE__->many_to_many("orders", "order_details", "order");

1;
