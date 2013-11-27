use utf8;
package Opencloset::Schema::Result::Cloth;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Cloth

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<cloth>

=cut

__PACKAGE__->table("cloth");

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
  is_nullable: 1

=head2 waist

  data_type: 'integer'
  is_nullable: 1

=head2 hip

  data_type: 'integer'
  is_nullable: 1

=head2 arm

  data_type: 'integer'
  is_nullable: 1

=head2 thigh

  data_type: 'integer'
  is_nullable: 1

=head2 length

  data_type: 'integer'
  is_nullable: 1

=head2 color

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 gender

  data_type: 'integer'
  is_nullable: 1

=head2 category

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 top_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 bottom_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 donor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 status_id

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
  { data_type => "integer", is_nullable => 1 },
  "waist",
  { data_type => "integer", is_nullable => 1 },
  "hip",
  { data_type => "integer", is_nullable => 1 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "thigh",
  { data_type => "integer", is_nullable => 1 },
  "length",
  { data_type => "integer", is_nullable => 1 },
  "color",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "gender",
  { data_type => "integer", is_nullable => 1 },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "top_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "bottom_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "donor_id",
  {
    data_type => "integer",
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

=head2 bottom

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->belongs_to(
  "bottom",
  "Opencloset::Schema::Result::Cloth",
  { id => "bottom_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 cloth_bottoms

Type: has_many

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->has_many(
  "cloth_bottoms",
  "Opencloset::Schema::Result::Cloth",
  { "foreign.bottom_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cloth_orders

Type: has_many

Related object: L<Opencloset::Schema::Result::ClothOrder>

=cut

__PACKAGE__->has_many(
  "cloth_orders",
  "Opencloset::Schema::Result::ClothOrder",
  { "foreign.cloth_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cloth_tops

Type: has_many

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->has_many(
  "cloth_tops",
  "Opencloset::Schema::Result::Cloth",
  { "foreign.top_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 donor

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Donor>

=cut

__PACKAGE__->belongs_to(
  "donor",
  "Opencloset::Schema::Result::Donor",
  { id => "donor_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 donor_cloths

Type: has_many

Related object: L<Opencloset::Schema::Result::DonorCloth>

=cut

__PACKAGE__->has_many(
  "donor_cloths",
  "Opencloset::Schema::Result::DonorCloth",
  { "foreign.cloth_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<Opencloset::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "Opencloset::Schema::Result::Satisfaction",
  { "foreign.cloth_id" => "self.id" },
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

=head2 top

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->belongs_to(
  "top",
  "Opencloset::Schema::Result::Cloth",
  { id => "top_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 orders

Type: many_to_many

Composing rels: L</cloth_orders> -> order

=cut

__PACKAGE__->many_to_many("orders", "cloth_orders", "order");


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-27 21:08:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:djFd6PO5HRisTm2u26JQkg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
