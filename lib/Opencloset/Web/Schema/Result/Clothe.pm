use utf8;
package Opencloset::Web::Schema::Result::Clothe;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Web::Schema::Result::Clothe

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Web::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Web::Schema::Base';

=head1 TABLE: C<clothes>

=cut

__PACKAGE__->table("clothes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

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

=head2 status

  data_type: 'integer'
  is_nullable: 1

=head2 category_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

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

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "chest",
  { data_type => "integer", is_nullable => 0 },
  "waist",
  { data_type => "integer", is_nullable => 0 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "pants_len",
  { data_type => "integer", is_nullable => 1 },
  "status",
  { data_type => "integer", is_nullable => 1 },
  "category_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
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
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 bottom

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Clothe>

=cut

__PACKAGE__->belongs_to(
  "bottom",
  "Opencloset::Web::Schema::Result::Clothe",
  { id => "bottom_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 category

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Category>

=cut

__PACKAGE__->belongs_to(
  "category",
  "Opencloset::Web::Schema::Result::Category",
  { id => "category_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 clothes_bottoms

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::Clothe>

=cut

__PACKAGE__->has_many(
  "clothes_bottoms",
  "Opencloset::Web::Schema::Result::Clothe",
  { "foreign.bottom_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 clothes_orders

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::ClothesOrder>

=cut

__PACKAGE__->has_many(
  "clothes_orders",
  "Opencloset::Web::Schema::Result::ClothesOrder",
  { "foreign.clothes_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 clothes_tops

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::Clothe>

=cut

__PACKAGE__->has_many(
  "clothes_tops",
  "Opencloset::Web::Schema::Result::Clothe",
  { "foreign.top_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 donor_clothes

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::DonorClothe>

=cut

__PACKAGE__->has_many(
  "donor_clothes",
  "Opencloset::Web::Schema::Result::DonorClothe",
  { "foreign.clothes_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "Opencloset::Web::Schema::Result::Satisfaction",
  { "foreign.clothes_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 top

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Clothe>

=cut

__PACKAGE__->belongs_to(
  "top",
  "Opencloset::Web::Schema::Result::Clothe",
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

Composing rels: L</clothes_orders> -> order

=cut

__PACKAGE__->many_to_many("orders", "clothes_orders", "order");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-23 04:06:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1QCE41Dur9NJfFc6lP84ZA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
